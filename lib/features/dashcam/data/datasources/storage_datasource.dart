import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/recording_metadata.dart';
import 'storage_datasource_interface.dart';

/// StorageDataSource — manages dashcam video storage with loop-aware cap.\n/// The storage limit only applies to loop (recyclable) videos.\n/// Starred and exported videos are excluded from the budget entirely.
class StorageDataSource implements IStorageDataSource {
  static const String _hiveBoxName = 'dashcam_metadata';

  @override
  Future<String> getDashcamDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final dashcamDir = Directory('${dir.path}/dashcam');
    if (!await dashcamDir.exists()) {
      await dashcamDir.create(recursive: true);
    }
    return dashcamDir.path;
  }

  @override
  Future<double> getRemainingStorageGb(int maxStorageGb) async {
    // Only count loop videos (not starred, not exported) toward the cap
    final loopInfo = await _getLoopVideoInfo();
    final maxBytes = maxStorageGb * 1024 * 1024 * 1024;
    final remaining = (maxBytes - loopInfo.totalBytes) / (1024 * 1024 * 1024);
    return remaining.clamp(0.0, maxStorageGb.toDouble());
  }

  @override
  Future<double> getGlobalFreeSpaceGb() async {
    try {
      const channel = MethodChannel('com.mycompany.indiandriveguide/system_monitor');
      final freeSpace = await channel.invokeMethod<double>('getFreeDiskSpace');
      return (freeSpace ?? 0.0).clamp(0.0, double.infinity);
    } catch (e) {
      debugPrint('[StorageDataSource] getGlobalFreeSpaceGb ERROR: $e');
      // Return 0.0 on plugin failure so it fails safely
      return 0.0;
    }
  }

  @override
  Future<void> checkCapAndClean(int maxStorageGb) async {
    final maxBytes = maxStorageGb * 1024 * 1024 * 1024;

    // Only count loop videos (not starred, not exported) toward the cap.
    // Starred and exported videos live outside this budget entirely.
    final loopInfo = await _getLoopVideoInfo();

    if (loopInfo.totalBytes <= maxBytes) return;

    // Sort oldest first so we delete the least-recent loop footage
    loopInfo.files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    final box = await Hive.openBox<Map>(_hiveBoxName);
    var currentSize = loopInfo.totalBytes;
    for (final file in loopInfo.files) {
      if (currentSize <= maxBytes) break;

      final fileId = file.uri.pathSegments.last.replaceAll('.mp4', '');
      final fileSize = file.lengthSync();
      await file.delete();
      await box.delete(fileId);

      // Also delete the GPS/telemetry JSON sidecar if present
      final jsonFile = File(file.path.replaceAll('.mp4', '.json'));
      if (jsonFile.existsSync()) {
        await jsonFile.delete();
      }

      currentSize -= fileSize;
    }

    if (currentSize > maxBytes) {
      throw StorageFullException();
    }
  }

  @override
  Future<String> saveVideoChunk(File tempFile) async {
    final dashcamDir = await getDashcamDirectory();
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    // Format: yyyyMMdd HHmmss
    final formattedDate = DateFormat('yyyyMMdd HHmmss').format(now);
    final fileName = 'TurboGauge_cam_$formattedDate.mp4';
    final destPath = '$dashcamDir/$fileName';

    await tempFile.copy(destPath);

    final box = await Hive.openBox<Map>(_hiveBoxName);
    await box.put(fileName.replaceAll('.mp4', ''), {
      'id': fileName.replaceAll('.mp4', ''),
      'path': destPath,
      'timestamp': timestamp,
      'isLocked': false,
    });

    return destPath;
  }

  @override
  Future<void> toggleClipLock(String fileId) async {
    debugPrint('[StorageDataSource] toggleClipLock requesting open for: $_hiveBoxName');
    final box = await Hive.openBox<Map>(_hiveBoxName);
    final meta = box.get(fileId);
    debugPrint('[StorageDataSource] toggleClipLock read meta for $fileId: $meta');
    if (meta != null) {
      final updated = <dynamic, dynamic>{...meta};
      final oldLock = meta['isLocked'] as bool? ?? false;
      updated['isLocked'] = !oldLock;
      debugPrint('[StorageDataSource] toggleClipLock updating $fileId from $oldLock to ${updated['isLocked']}');
      await box.put(fileId, updated);
      await box.flush();
    } else {
      debugPrint('[StorageDataSource] toggleClipLock failed: FileId $fileId not found in Hive $_hiveBoxName box');
    }
  }

  @override
  Future<List<RecordingMetadata>> getRecordings() async {
    final box = await Hive.openBox<Map>(_hiveBoxName);
    final recordings = <RecordingMetadata>[];
    for (final key in box.keys) {
      final meta = box.get(key);
      if (meta != null) {
        recordings.add(RecordingMetadata.fromMap(Map<String, dynamic>.from(meta)));
      }
    }
    recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return recordings;
  }

  /// Returns only loop video files (not starred, not exported) with their
  /// combined size. This is the set of videos governed by the storage cap.
  Future<_LoopVideoInfo> _getLoopVideoInfo() async {
    final dashcamDir = await getDashcamDirectory();
    final dir = Directory(dashcamDir);
    if (!await dir.exists()) return _LoopVideoInfo([], 0);

    final box = await Hive.openBox<Map>(_hiveBoxName);
    final allMp4 = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.mp4')).toList();

    final loopFiles = <File>[];
    int loopBytes = 0;

    for (final file in allMp4) {
      // Exported videos are out of the budget
      if (file.path.endsWith('_exported.mp4')) continue;

      // Starred (locked) videos are out of the budget
      final fileId = file.uri.pathSegments.last.replaceAll('.mp4', '');
      final meta = box.get(fileId);
      if (meta != null && meta['isLocked'] == true) continue;

      try {
        loopBytes += file.lengthSync();
        loopFiles.add(file);
      } catch (_) {
        // File may have been deleted between list and read — skip safely
      }
    }

    return _LoopVideoInfo(loopFiles, loopBytes);
  }
}

/// Internal helper holding loop video files and their total size.
class _LoopVideoInfo {
  final List<File> files;
  final int totalBytes;
  const _LoopVideoInfo(this.files, this.totalBytes);
}
