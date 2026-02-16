// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PositionDataAdapter extends TypeAdapter<PositionData> {
  @override
  final typeId = 1;

  @override
  PositionData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PositionData(
      latitude: (fields[0] as num).toDouble(),
      longitude: (fields[1] as num).toDouble(),
      accuracy: (fields[2] as num).toDouble(),
      altitude: (fields[3] as num).toDouble(),
      altitudeAccuracy: (fields[4] as num).toDouble(),
      speed: (fields[5] as num).toDouble(),
      speedAccuracy: (fields[6] as num).toDouble(),
      heading: (fields[7] as num).toDouble(),
      headingAccuracy: (fields[8] as num).toDouble(),
      timestamp: (fields[9] as num).toInt(),
      floor: (fields[10] as num?)?.toInt(),
      isMocked: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PositionData obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.accuracy)
      ..writeByte(3)
      ..write(obj.altitude)
      ..writeByte(4)
      ..write(obj.altitudeAccuracy)
      ..writeByte(5)
      ..write(obj.speed)
      ..writeByte(6)
      ..write(obj.speedAccuracy)
      ..writeByte(7)
      ..write(obj.heading)
      ..writeByte(8)
      ..write(obj.headingAccuracy)
      ..writeByte(9)
      ..write(obj.timestamp)
      ..writeByte(10)
      ..write(obj.floor)
      ..writeByte(11)
      ..write(obj.isMocked);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
