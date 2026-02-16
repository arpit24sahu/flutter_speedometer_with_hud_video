part of 'processing_task.dart';

class ProcessingTaskAdapter extends TypeAdapter<ProcessingTask> {
  @override
  final int typeId = 2;

  @override
  ProcessingTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProcessingTask(
      id: fields[0] as String?,
      name: fields[1] as String?,
      videoFilePath: fields[2] as String?,
      positionData: (fields[3] as Map?)?.cast<int, PositionData>(),
      sizeInKb: (fields[4] as num?)?.toDouble(),
      lengthInSeconds: (fields[5] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ProcessingTask obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.videoFilePath)
      ..writeByte(3)
      ..write(obj.positionData)
      ..writeByte(4)
      ..write(obj.sizeInKb)
      ..writeByte(5)
      ..write(obj.lengthInSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessingTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
