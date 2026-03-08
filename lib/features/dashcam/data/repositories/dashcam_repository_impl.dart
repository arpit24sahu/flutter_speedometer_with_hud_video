import 'dart:async';
import 'dart:io';
import '../datasources/camera_datasource_interface.dart';
import '../datasources/metadata_datasource_interface.dart';
import '../datasources/storage_datasource_interface.dart';
import '../dashcam_preferences.dart';
import '../../core/result.dart';
import '../../domain/entities/dashcam_failure.dart';
import '../../domain/entities/dashcam_settings.dart';
import '../../domain/entities/recording_metadata.dart';
import '../../domain/repositories/dashcam_repository.dart';
import '../../domain/services/video_export_service_interface.dart';
import '../../service/dashcam_platform_service.dart';
import 'package:camera/camera.dart';

/// Repository implementation that orchestrates data sources.
/// No direct Hive calls — all persistence via StorageDataSource.
// All methods return Result instead of throwing exceptions.
class DashcamRepositoryImpl implements DashcamRepository {
  final ICameraDataSource _cameraDataSource;
  final IMetadataDataSource _metadataDataSource;
  final IStorageDataSource _storageDataSource;
  final IVideoExportService _videoExportService;
  final DashcamPlatformService _platformService;
  final DashcamPreferences _preferences;

  final StreamController<bool> _recordingStateCtrl = StreamController<bool>.broadcast();
  int? _currentMetaTimestamp;
  bool _lockCurrentSegment = false;

  DashcamRepositoryImpl({
    required ICameraDataSource cameraDataSource,
    required IMetadataDataSource metadataDataSource,
    required IStorageDataSource storageDataSource,
    required IVideoExportService videoExportService,
    required DashcamPlatformService platformService,
    required DashcamPreferences preferences,
  })  : _cameraDataSource = cameraDataSource,
        _metadataDataSource = metadataDataSource,
        _storageDataSource = storageDataSource,
        _videoExportService = videoExportService,
        _platformService = platformService,
        _preferences = preferences;


  @override
  Stream<bool> get recordingStateStream => _recordingStateCtrl.stream;

  @override
  Future<Result<void, DashcamFailure>> initialize() async {
    try {
      ResolutionPreset preset;
      switch (_preferences.videoQuality) {
        case '4K':
        case '4k':
          preset = ResolutionPreset.ultraHigh;
          break;
        case '720p':
          preset = ResolutionPreset.high;
          break;
        case '1080p':
        default:
          preset = ResolutionPreset.veryHigh;
          break;
      }

      await _cameraDataSource.initialize(
        enableAudio: _preferences.enableMic, 
        resolutionPreset: preset,
        fps: _preferences.frameRate,
      );
      if (_preferences.enableGps) {
        await _metadataDataSource.startStreaming();
      }
      await _platformService.startService();
      return const Success(null);
    } catch (e) {
      return Failure(CameraFailure('Failed to initialize: $e'));
    }
  }

  @override
  Future<Result<void, DashcamFailure>> startRecording() async {
    try {
      await _cameraDataSource.startVideoRecording();

      // Start metadata writing alongside recording
      final dashcamDir = await _storageDataSource.getDashcamDirectory();
      // Use a temporary name, we will rename it when stopping to exactly match the chunk name
      _currentMetaTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _metadataDataSource.startWriting('$dashcamDir/meta_$_currentMetaTimestamp.json');

      if (!_recordingStateCtrl.isClosed) {
        _recordingStateCtrl.add(true);
      }
      return const Success(null);
    } catch (e) {
      return Failure(CameraFailure('Failed to start recording: $e'));
    }
  }

  @override
  Future<Result<void, DashcamFailure>> stopRecording() async {
    try {
      String? videoPath;
      try {
        videoPath = await _cameraDataSource.stopVideoRecording();
      } catch (e) {
        // Sometimes the native camera SDK throws if recording time was too short.
        print('[DashcamRepository] stopVideoRecording failed: $e');
      }
      
      await _metadataDataSource.stopWriting();

      final metaTimestamp = _currentMetaTimestamp;
      final lockSegment = _lockCurrentSegment;
      _currentMetaTimestamp = null;
      _lockCurrentSegment = false;

      // Finish saving current segment and its metadata
      await _processSavedSegment(
        videoPath: videoPath,
        metaTimestamp: metaTimestamp,
        lockSegment: lockSegment,
      );

      if (!_recordingStateCtrl.isClosed) {
        _recordingStateCtrl.add(false);
      }

      await _platformService.stopService();
      return const Success(null);
    } catch (e) {
      return Failure(CameraFailure('Failed to stop recording: $e'));
    }
  }

  @override
  Future<Result<void, DashcamFailure>> rotateSegment() async {
    try {
      // Stop current segment
      String? videoPath;
      try {
        videoPath = await _cameraDataSource.stopVideoRecording();
      } catch (e) {
        print('[DashcamRepository] stopVideoRecording failed during rotation: $e');
      }
      
      await _metadataDataSource.stopWriting();

      final metaTimestamp = _currentMetaTimestamp;
      final lockSegment = _lockCurrentSegment;
      _lockCurrentSegment = false; // reset for the new segment
      
      // Hardware stabilization delay between segments
      await Future.delayed(const Duration(milliseconds: 150));

      // Start new segment instantly to prevent dropping frames
      await _cameraDataSource.startVideoRecording();
      final dashcamDir = await _storageDataSource.getDashcamDirectory();
      _currentMetaTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _metadataDataSource.startWriting('$dashcamDir/meta_$_currentMetaTimestamp.json');

      // Process disk I/O in the background to avoid blocking the recording interval
      unawaited(_processSavedSegment(
        videoPath: videoPath,
        metaTimestamp: metaTimestamp,
        lockSegment: lockSegment,
      ).catchError((e) {
        print('[DashcamRepository] Background segment saving failed: $e');
      }));

      return const Success(null);
    } catch (e) {
      return Failure(CameraFailure('Failed to rotate segment: $e'));
    }
  }

  @override
  Future<Result<void, DashcamFailure>> rotateSegmentWithAudioChange({
    required bool enableAudio,
  }) async {
    try {
      // 1. Stop current segment — finalize the mp4 moov atom cleanly
      String? videoPath;
      try {
        videoPath = await _cameraDataSource.stopVideoRecording();
      } catch (e) {
        print('[DashcamRepo] stopVideoRecording failed during audio-change rotation: $e');
      }

      await _metadataDataSource.stopWriting();

      final metaTimestamp = _currentMetaTimestamp;
      final lockSegment = _lockCurrentSegment;
      _lockCurrentSegment = false;

      // 2. Reinitialize camera with changed audio setting
      //    (preserves lens, resolution, and frame rate)
      await _cameraDataSource.reinitializeWithAudio(enableAudio: enableAudio);

      // 3. Start new segment immediately to minimize gap
      await _cameraDataSource.startVideoRecording();
      final dashcamDir = await _storageDataSource.getDashcamDirectory();
      _currentMetaTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _metadataDataSource.startWriting(
        '$dashcamDir/meta_$_currentMetaTimestamp.json',
      );

      // 4. Save old segment in background
      unawaited(_processSavedSegment(
        videoPath: videoPath,
        metaTimestamp: metaTimestamp,
        lockSegment: lockSegment,
      ).catchError((e) {
        print('[DashcamRepo] Background segment save failed: $e');
      }));

      return const Success(null);
    } catch (e) {
      return Failure(CameraFailure('Audio-change rotation failed: $e'));
    }
  }

  /// Helper to dry up repetition of storage and metadata saving
  Future<void> _processSavedSegment({
    required String? videoPath,
    required int? metaTimestamp,
    required bool lockSegment,
  }) async {
    if (videoPath != null && videoPath.isNotEmpty) {
      final destPath = await _storageDataSource.saveVideoChunk(File(videoPath));

      if (lockSegment) {
        final fileId = destPath.split('/').last.replaceAll('.mp4', '');
        await _storageDataSource.toggleClipLock(fileId);
      }

      if (metaTimestamp != null) {
        final dashcamDir = await _storageDataSource.getDashcamDirectory();
        final oldMetaFile = File('$dashcamDir/meta_$metaTimestamp.json');
        if (await oldMetaFile.exists()) {
          final newMetaPath = destPath.replaceAll('.mp4', '.json');
          await oldMetaFile.rename(newMetaPath);
        }
      }
    } else {
      if (metaTimestamp != null) {
        final dashcamDir = await _storageDataSource.getDashcamDirectory();
        final oldMetaFile = File('$dashcamDir/meta_$metaTimestamp.json');
        if (await oldMetaFile.exists()) {
          await oldMetaFile.delete();
        }
      }
    }
  }

  @override
  Future<Result<void, DashcamFailure>> checkStorageCapAndClean(int maxStorageGb) async {
    try {
      await _storageDataSource.checkCapAndClean(maxStorageGb);
      return const Success(null);
    } on StorageFullException {
      return const Failure(StorageFullFailure());
    } catch (e) {
      return Failure(UnknownDashcamFailure('Storage check failed: $e'));
    }
  }

  @override
  Future<Result<double, DashcamFailure>> getRemainingStorageGb(int maxStorageGb) async {
    try {
      final remaining = await _storageDataSource.getRemainingStorageGb(maxStorageGb);
      return Success(remaining);
    } catch (e) {
      return Failure(UnknownDashcamFailure('Failed to check storage: $e'));
    }
  }

  @override
  Future<Result<double, DashcamFailure>> getGlobalFreeSpaceGb() async {
    try {
      final freeSpace = await _storageDataSource.getGlobalFreeSpaceGb();
      return Success(freeSpace);
    } catch (e) {
      return Failure(UnknownDashcamFailure('Failed to check global storage: $e'));
    }
  }

  @override
  Future<Result<String, DashcamFailure>> exportVideo(File videoFile, {void Function(double)? onProgress}) async {
    try {
      final outputPath = await _videoExportService.exportVideoWithOverlays(videoFile, onProgress: onProgress);
      if (outputPath != null) {
        return Success(outputPath);
      }
      return const Failure(ExportFailure('FFmpeg export returned null'));
    } catch (e) {
      return Failure(ExportFailure('Export failed: $e'));
    }
  }

  @override
  void lockCurrentSegmentOnSave() {
    _lockCurrentSegment = true;
  }

  @override
  Future<Result<void, DashcamFailure>> toggleClipLock(String fileId) async {
    try {
      await _storageDataSource.toggleClipLock(fileId);
      return const Success(null);
    } catch (e) {
      return Failure(UnknownDashcamFailure('Failed to toggle lock: $e'));
    }
  }

  @override
  Future<Result<List<RecordingMetadata>, DashcamFailure>> getRecordings() async {
    try {
      final recordings = await _storageDataSource.getRecordings();
      return Success(recordings);
    } catch (e) {
      return Failure(UnknownDashcamFailure('Failed to get recordings: $e'));
    }
  }

  @override
  Future<DashcamSettings> getSettings() async {
    return DashcamSettings(maxStorageGb: _preferences.storageLimitGb);
  }

  @override
  Future<void> updateSettings(DashcamSettings settings) async {
    _preferences.storageLimitGb = settings.maxStorageGb;
  }

  @override
  Future<void> dispose() async {
    if (!_recordingStateCtrl.isClosed) {
      await _recordingStateCtrl.close();
    }
    await _cameraDataSource.dispose();
    await _metadataDataSource.dispose();
  }
}

