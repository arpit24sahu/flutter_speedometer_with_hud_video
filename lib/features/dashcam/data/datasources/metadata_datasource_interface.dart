import '../../domain/entities/dashcam_telemetry.dart';

/// Interface for GPS/telemetry metadata operations.
abstract class IMetadataDataSource {
  Stream<DashcamTelemetry> get telemetryStream;
  Future<void> startStreaming();
  Future<void> stopStreaming();
  Future<void> startWriting(String filePath);
  Future<void> stopWriting();
  Future<void> dispose();
}
