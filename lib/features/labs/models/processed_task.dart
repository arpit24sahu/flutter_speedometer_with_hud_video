import 'package:hive_ce/hive.dart';
import 'package:equatable/equatable.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';

part 'processed_task_adapter.dart';

/// Represents an exported/processed video.
/// Stored in the 'processed_task' Hive box.
@HiveType(typeId: 3)
class ProcessedTask extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? savedVideoFilePath;

  @HiveField(3)
  final ProcessingTask? processingTask;

  @HiveField(4)
  final DateTime? createdAt;

  @HiveField(5)
  final DateTime? updatedAt;

  @HiveField(6)
  final double? sizeInKb;

  @HiveField(7)
  final double? lengthInSeconds;

  ProcessedTask({
    this.id,
    this.name,
    this.savedVideoFilePath,
    this.processingTask,
    this.createdAt,
    this.updatedAt,
    this.sizeInKb,
    this.lengthInSeconds,
  });

  ProcessedTask copyWith({
    String? id,
    String? name,
    String? savedVideoFilePath,
    ProcessingTask? processingTask,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? sizeInKb,
    double? lengthInSeconds,
  }) {
    return ProcessedTask(
      id: id ?? this.id,
      name: name ?? this.name,
      savedVideoFilePath: savedVideoFilePath ?? this.savedVideoFilePath,
      processingTask: processingTask ?? this.processingTask,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sizeInKb: sizeInKb ?? this.sizeInKb,
      lengthInSeconds: lengthInSeconds ?? this.lengthInSeconds,
    );
  }

  @override
  String toString() {
    return 'ProcessedTask(id: $id, name: $name, savedVideoFilePath: $savedVideoFilePath, '
        'processingTask: ${processingTask?.id}, createdAt: $createdAt, '
        'updatedAt: $updatedAt, sizeInKb: $sizeInKb, lengthInSeconds: $lengthInSeconds)';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        savedVideoFilePath,
        processingTask,
        createdAt,
        updatedAt,
        sizeInKb,
        lengthInSeconds,
      ];
}
