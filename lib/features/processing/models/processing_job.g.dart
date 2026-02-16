// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processing_job.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProcessingJobAdapter extends TypeAdapter<ProcessingJob> {
  @override
  final typeId = 0;

  @override
  ProcessingJob read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProcessingJob(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      videoFilePath: fields[2] as String,
      overlayFilePath: fields[3] as String,
      processedFilePath: fields[4] as String?,
      failureCount: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      processedAt: fields[6] as DateTime?,
      failedAt: fields[7] as DateTime?,
      lastError: fields[8] as String?,
      gaugePlacement: fields[9] as String,
      relativeSize: (fields[10] as num).toDouble(),
      ffmpegCommand: fields[11] as String,
      processedFileSizeInKb: (fields[12] as num?)?.toInt(),
      status: fields[13] as ProcessingJobStatus?,
      positionData: (fields[14] as Map?)?.cast<int, PositionData>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProcessingJob obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.videoFilePath)
      ..writeByte(3)
      ..write(obj.overlayFilePath)
      ..writeByte(4)
      ..write(obj.processedFilePath)
      ..writeByte(5)
      ..write(obj.failureCount)
      ..writeByte(6)
      ..write(obj.processedAt)
      ..writeByte(7)
      ..write(obj.failedAt)
      ..writeByte(8)
      ..write(obj.lastError)
      ..writeByte(9)
      ..write(obj.gaugePlacement)
      ..writeByte(10)
      ..write(obj.relativeSize)
      ..writeByte(11)
      ..write(obj.ffmpegCommand)
      ..writeByte(12)
      ..write(obj.processedFileSizeInKb)
      ..writeByte(13)
      ..write(obj.status)
      ..writeByte(14)
      ..write(obj.positionData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessingJobAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
