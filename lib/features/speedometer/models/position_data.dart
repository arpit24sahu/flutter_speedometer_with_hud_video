import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';

part 'position_data.g.dart';

@HiveType(typeId: 1)
class PositionData {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final double accuracy;

  @HiveField(3)
  final double altitude;

  @HiveField(4)
  final double altitudeAccuracy;

  @HiveField(5)
  final double speed;

  @HiveField(6)
  final double speedAccuracy;

  @HiveField(7)
  final double heading;

  @HiveField(8)
  final double headingAccuracy;

  @HiveField(9)
  final int timestamp; // ms since epoch

  @HiveField(10)
  final int? floor;

  @HiveField(11)
  final bool isMocked;

  const PositionData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.altitudeAccuracy,
    required this.speed,
    required this.speedAccuracy,
    required this.heading,
    required this.headingAccuracy,
    required this.timestamp,
    this.floor,
    required this.isMocked,
  });

  // ─────────────────────────────────────────────
  // FROM Geolocator Position → PositionData
  // ─────────────────────────────────────────────
  factory PositionData.fromGeolocator(Position p) {
    return PositionData(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      altitude: p.altitude,
      altitudeAccuracy: p.altitudeAccuracy,
      speed: p.speed,
      speedAccuracy: p.speedAccuracy,
      heading: p.heading,
      headingAccuracy: p.headingAccuracy,
      timestamp: p.timestamp.millisecondsSinceEpoch,
      floor: p.floor,
      isMocked: p.isMocked,
    );
  }

  // ─────────────────────────────────────────────
  // TO Geolocator Position
  // ─────────────────────────────────────────────
  Position toGeolocatorPosition() {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      accuracy: accuracy,
      altitude: altitude,
      altitudeAccuracy: altitudeAccuracy,
      heading: heading,
      headingAccuracy: headingAccuracy,
      speed: speed,
      speedAccuracy: speedAccuracy,
      floor: floor,
      isMocked: isMocked,
    );
  }

  // ─────────────────────────────────────────────
  // JSON (for API / export)
  // ─────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'altitude_accuracy': altitudeAccuracy,
      'speed': speed,
      'speed_accuracy': speedAccuracy,
      'heading': heading,
      'heading_accuracy': headingAccuracy,
      'timestamp': timestamp,
      'floor': floor,
      'is_mocked': isMocked,
    };
  }

  factory PositionData.fromJson(Map<String, dynamic> json) {
    return PositionData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
      altitudeAccuracy:
      (json['altitude_accuracy'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      speedAccuracy:
      (json['speed_accuracy'] as num).toDouble(),
      heading: (json['heading'] as num).toDouble(),
      headingAccuracy:
      (json['heading_accuracy'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      floor: json['floor'] as int?,
      isMocked: json['is_mocked'] as bool,
    );
  }

  PositionData copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? altitudeAccuracy,
    double? speed,
    double? speedAccuracy,
    double? heading,
    double? headingAccuracy,
    int? timestamp,
    int? floor,
    bool? isMocked,
  }) {
    return PositionData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      altitudeAccuracy: altitudeAccuracy ?? this.altitudeAccuracy,
      speed: speed ?? this.speed,
      speedAccuracy: speedAccuracy ?? this.speedAccuracy,
      heading: heading ?? this.heading,
      headingAccuracy: headingAccuracy ?? this.headingAccuracy,
      timestamp: timestamp ?? this.timestamp,
      floor: floor ?? this.floor,
      isMocked: isMocked ?? this.isMocked,
    );
  }
}