import 'package:equatable/equatable.dart';

class SpeedometerState extends Equatable {
  final double speedKmh;
  final double speedMph;
  final double maxSpeedKmh;
  final double maxSpeedMph;
  final double distanceKm;
  final double distanceMiles;
  final double heading;
  final bool calibrationRequired;
  final bool isTracking;
  final bool isDigital;
  final String? error;

  const SpeedometerState({
    required this.speedKmh,
    required this.speedMph,
    required this.maxSpeedKmh,
    required this.maxSpeedMph,
    required this.distanceKm,
    required this.distanceMiles,
    required this.heading,
    required this.calibrationRequired,
    required this.isTracking,
    required this.isDigital,
    this.error,
  });

  factory SpeedometerState.initial() {
    return const SpeedometerState(
      speedKmh: 0,
      speedMph: 0,
      maxSpeedKmh: 0,
      maxSpeedMph: 0,
      distanceKm: 0,
      distanceMiles: 0,
      heading: 0,
      calibrationRequired: false,
      isTracking: false,
      isDigital: false,
      error: null,
    );
  }

  SpeedometerState copyWith({
    double? speedKmh,
    double? speedMph,
    double? maxSpeedKmh,
    double? maxSpeedMph,
    double? distanceKm,
    double? distanceMiles,
    double? heading,
    bool? calibrationRequired,
    bool? isTracking,
    bool? isDigital,
    String? error,
  }) {
    return SpeedometerState(
      speedKmh: speedKmh ?? this.speedKmh,
      speedMph: speedMph ?? this.speedMph,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      maxSpeedMph: maxSpeedMph ?? this.maxSpeedMph,
      distanceKm: distanceKm ?? this.distanceKm,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      heading: heading ?? this.heading,
      calibrationRequired: calibrationRequired ?? this.calibrationRequired,
      isTracking: isTracking ?? this.isTracking,
      isDigital: isDigital ?? this.isDigital,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    speedKmh,
    speedMph,
    maxSpeedKmh,
    maxSpeedMph,
    distanceKm,
    distanceMiles,
    heading,
    calibrationRequired,
    isTracking,
    isDigital,
    error,
  ];
}