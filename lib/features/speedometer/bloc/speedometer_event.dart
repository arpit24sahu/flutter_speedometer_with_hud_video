import 'package:flutter_compass/flutter_compass.dart';

abstract class SpeedometerEvent {}

class StartSpeedTracking extends SpeedometerEvent {}

class StopSpeedTracking extends SpeedometerEvent {}

class SpeedUpdated extends SpeedometerEvent {
  final double speedKmh;
  final double speedMph;
  final double maxSpeedKmh;
  final double maxSpeedMph;
  final double distanceKm;
  final double distanceMiles;

  SpeedUpdated({
    required this.speedKmh,
    required this.speedMph,
    required this.maxSpeedKmh,
    required this.maxSpeedMph,
    required this.distanceKm,
    required this.distanceMiles,
  });
}

class HeadingUpdated extends SpeedometerEvent {
  final double heading;
  final bool calibrationRequired;

  HeadingUpdated({required this.heading, required this.calibrationRequired});
}

class ResetTrip extends SpeedometerEvent {}

class ToggleSpeedometerType extends SpeedometerEvent {}