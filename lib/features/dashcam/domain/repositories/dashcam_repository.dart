import 'dart:io';
import '../entities/dashcam_failure.dart';
import '../entities/dashcam_settings.dart';
import '../entities/recording_metadata.dart';
import '../../core/result.dart';

/// Repository interface for dashcam feature.
/// All methods return typed Result instead of throwing exceptions.
abstract class DashcamRepository {
  Future<Result<void, DashcamFailure>> initialize();
  Future<Result<void, DashcamFailure>> startRecording();
  Future<Result<void, DashcamFailure>> stopRecording();
  Future<Result<void, DashcamFailure>> rotateSegment();

  /// Rotates the current segment while changing the audio capture setting.
  ///
  /// Used during phone call interruptions:
  ///   - [enableAudio] = false → finalize current segment, restart video-only
  ///   - [enableAudio] = true  → finalize video-only segment, restart with mic
  Future<Result<void, DashcamFailure>> rotateSegmentWithAudioChange({
    required bool enableAudio,
  });
  Future<Result<void, DashcamFailure>> checkStorageCapAndClean(int maxStorageGb);
  Future<Result<double, DashcamFailure>> getRemainingStorageGb(int maxStorageGb);
  Future<Result<double, DashcamFailure>> getGlobalFreeSpaceGb();
  Future<Result<String, DashcamFailure>> exportVideo(File videoFile, {void Function(double)? onProgress});
  void lockCurrentSegmentOnSave();
  Future<Result<void, DashcamFailure>> toggleClipLock(String fileId);
  Future<Result<List<RecordingMetadata>, DashcamFailure>> getRecordings();
  Future<DashcamSettings> getSettings();
  Future<void> updateSettings(DashcamSettings settings);
  Stream<bool> get recordingStateStream;
  Future<void> dispose();
}
