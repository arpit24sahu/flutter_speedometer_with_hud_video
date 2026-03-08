import 'dart:io';
import '../../domain/entities/recording_metadata.dart';

/// Interface for storage operations.
abstract class IStorageDataSource {
  Future<String> getDashcamDirectory();
  Future<double> getRemainingStorageGb(int maxStorageGb);
  Future<double> getGlobalFreeSpaceGb();
  Future<void> checkCapAndClean(int maxStorageGb);
  Future<String> saveVideoChunk(File tempFile);
  Future<void> toggleClipLock(String fileId);
  Future<List<RecordingMetadata>> getRecordings();
}

/// Exception for storage full when all clips are locked.
class StorageFullException implements Exception {}
