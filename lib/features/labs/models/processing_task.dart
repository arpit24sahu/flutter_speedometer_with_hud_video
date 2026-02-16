import 'package:hive_ce/hive.dart';
import 'package:equatable/equatable.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';

part 'processing_task_adapter.dart';

/// Represents a recorded video that is ready for processing.
/// Stored in the 'processing_task' Hive box.
@HiveType(typeId: 2)
class ProcessingTask extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? videoFilePath;

  @HiveField(3)
  final Map<int, PositionData>? positionData;

  @HiveField(4)
  final double? sizeInKb;

  @HiveField(5)
  final double? lengthInSeconds;

  ProcessingTask({
    this.id,
    this.name,
    this.videoFilePath,
    this.positionData,
    this.sizeInKb,
    this.lengthInSeconds,
  });

  ProcessingTask copyWith({
    String? id,
    String? name,
    String? videoFilePath,
    Map<int, PositionData>? positionData,
    double? sizeInKb,
    double? lengthInSeconds,
  }) {
    return ProcessingTask(
      id: id ?? this.id,
      name: name ?? this.name,
      videoFilePath: videoFilePath ?? this.videoFilePath,
      positionData: positionData ?? this.positionData,
      sizeInKb: sizeInKb ?? this.sizeInKb,
      lengthInSeconds: lengthInSeconds ?? this.lengthInSeconds,
    );
  }

  @override
  String toString() {
    return 'ProcessingTask(id: $id, name: $name, videoFilePath: $videoFilePath, '
        'positionData: ${positionData?.length ?? 0} points, '
        'sizeInKb: $sizeInKb, lengthInSeconds: $lengthInSeconds)';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        videoFilePath,
        positionData,
        sizeInKb,
        lengthInSeconds,
      ];
}
