import 'package:hive_ce/hive.dart';
import 'package:equatable/equatable.dart';

part 'processing_job.g.dart';

enum ProcessingJobStatus {
  pending, processing, success, failure
}

@HiveType(typeId: 0)
class ProcessingJob extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  final String videoFilePath;

  @HiveField(3)
  final String overlayFilePath;

  @HiveField(4)
  final String? processedFilePath;

  @HiveField(5)
  final int failureCount;

  @HiveField(6)
  final DateTime? processedAt;

  @HiveField(7)
  final DateTime? failedAt;

  @HiveField(8)
  final String? lastError;

  @HiveField(9)
  final String gaugePlacement;

  @HiveField(10)
  final double relativeSize;

  @HiveField(11)
  final String ffmpegCommand;

  @HiveField(12)
  final int? processedFileSizeInKb;

  @HiveField(13)
  final ProcessingJobStatus? status;

  ProcessingJob({
    required this.id,
    required this.createdAt,
    required this.videoFilePath,
    required this.overlayFilePath,
    this.processedFilePath,
    this.failureCount = 0,
    this.processedAt,
    this.failedAt,
    this.lastError,
    required this.gaugePlacement,
    required this.relativeSize,
    required this.ffmpegCommand,
    this.processedFileSizeInKb,
    this.status,
  });

  ProcessingJob copyWith({
    String? id,
    DateTime? createdAt,
    String? videoFilePath,
    String? overlayFilePath,
    String? processedFilePath,
    int? failureCount,
    DateTime? processedAt,
    DateTime? failedAt,
    String? lastError,
    String? gaugePlacement,
    double? relativeSize,
    String? ffmpegCommand,
    int? processedFileSizeInKb,
    ProcessingJobStatus? status,
  }) {
    return ProcessingJob(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      videoFilePath: videoFilePath ?? this.videoFilePath,
      overlayFilePath: overlayFilePath ?? this.overlayFilePath,
      processedFilePath: processedFilePath ?? this.processedFilePath,
      failureCount: failureCount ?? this.failureCount,
      processedAt: processedAt ?? this.processedAt,
      failedAt: failedAt ?? this.failedAt,
      lastError: lastError ?? this.lastError,
      gaugePlacement: gaugePlacement ?? this.gaugePlacement,
      relativeSize: relativeSize ?? this.relativeSize,
      ffmpegCommand: ffmpegCommand ?? this.ffmpegCommand,
      processedFileSizeInKb: processedFileSizeInKb ?? this.processedFileSizeInKb,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'ProcessingJob(id: $id, createdAt: $createdAt, videoFilePath: $videoFilePath, overlayFilePath: $overlayFilePath, processedFilePath: $processedFilePath, failureCount: $failureCount, processedAt: $processedAt, failedAt: $failedAt, lastError: $lastError, gaugePlacement: $gaugePlacement, relativeSize: $relativeSize, ffmpegCommand: $ffmpegCommand, processedFileSizeInKb: $processedFileSizeInKb, status: $status)';
  }

  @override
  List<Object?> get props => [
    id,
    createdAt,
    videoFilePath,
    overlayFilePath,
    processedFilePath,
    failureCount,
    processedAt,
    failedAt,
    lastError,
    gaugePlacement,
    relativeSize,
    ffmpegCommand,
    processedFileSizeInKb,
    status,
  ];
}
