part of 'processed_task.dart';

class ProcessedTaskAdapter extends TypeAdapter<ProcessedTask> {
  @override
  final int typeId = 3;

  @override
  ProcessedTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProcessedTask(
      id: fields[0] as String?,
      name: fields[1] as String?,
      savedVideoFilePath: fields[2] as String?,
      processingTask: fields[3] as ProcessingTask?,
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
      sizeInKb: (fields[6] as num?)?.toDouble(),
      lengthInSeconds: (fields[7] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ProcessedTask obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.savedVideoFilePath)
      ..writeByte(3)
      ..write(obj.processingTask)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.sizeInKb)
      ..writeByte(7)
      ..write(obj.lengthInSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessedTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
