import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/core/services/sensors_service.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_event.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_state.dart';

class SpeedometerBloc extends Bloc<SpeedometerEvent, SpeedometerState> {
  final LocationService locationService;
  final SensorsService sensorsService;
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent?>? _compassSubscription;

  SpeedometerBloc({
    required this.locationService,
    required this.sensorsService,
  }) : super(SpeedometerState.initial()) {
    on<StartSpeedTracking>(_onStartSpeedTracking);
    on<StopSpeedTracking>(_onStopSpeedTracking);
    on<SpeedUpdated>(_onSpeedUpdated);
    on<HeadingUpdated>(_onHeadingUpdated);
    on<ResetTrip>(_onResetTrip);
    on<ToggleSpeedometerType>(_onToggleSpeedometerType);
  }

  void _onStartSpeedTracking(StartSpeedTracking event, Emitter<SpeedometerState> emit) async {
    final hasPermission = await locationService.checkPermission();
    
    if (!hasPermission) {
      final permissionGranted = await locationService.requestPermission();
      if (!permissionGranted) {
        emit(state.copyWith(error: 'Location permission denied'));
        return;
      }
    }

    emit(state.copyWith(isTracking: true, error: null));
    
    _positionSubscription?.cancel();
    _positionSubscription = locationService.getPositionStream().listen(
      (position) {
        print("Position Data: ${position.speed} ${position.latitude}");
        final speedMps = position.speed;
        final speedKmh = speedMps * 3.6; // Convert m/s to km/h
        final speedMph = speedMps * 2.23694; // Convert m/s to mph
        
        // Update max speed if current speed is higher
        final maxSpeedKmh = speedKmh > state.maxSpeedKmh ? speedKmh : state.maxSpeedKmh;
        final maxSpeedMph = speedMph > state.maxSpeedMph ? speedMph : state.maxSpeedMph;
        
        // Update distance
        final distance = state.distanceKm + (speedMps * 0.001); // Add distance in km
        
        add(SpeedUpdated(
          speedKmh: speedKmh,
          speedMph: speedMph,
          maxSpeedKmh: maxSpeedKmh,
          maxSpeedMph: maxSpeedMph,
          distanceKm: distance,
          distanceMiles: distance * 0.621371, // Convert km to miles
        ));
      },
      onError: (error) {
        emit(state.copyWith(error: error.toString()));
      },
    );
    
    _compassSubscription?.cancel();
    // _compassSubscription = sensorsService.getCompassStream()?.listen(
    //   (CompassEvent? event) {
    //     if(event==null) return;
    //     print("Accuracy: ${event.accuracy}");
    //     if(event.heading!=null){
    //       add(HeadingUpdated(heading: event.heading!, calibrationRequired: event.accuracy == null));
    //     }
    //   },
    // );
  }

  void _onStopSpeedTracking(StopSpeedTracking event, Emitter<SpeedometerState> emit) {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    emit(state.copyWith(isTracking: false));
  }

  void _onSpeedUpdated(SpeedUpdated event, Emitter<SpeedometerState> emit) {
    emit(state.copyWith(
      speedKmh: event.speedKmh,
      speedMph: event.speedMph,
      maxSpeedKmh: event.maxSpeedKmh,
      maxSpeedMph: event.maxSpeedMph,
      distanceKm: event.distanceKm,
      distanceMiles: event.distanceMiles,
    ));
  }

  void _onHeadingUpdated(HeadingUpdated event, Emitter<SpeedometerState> emit) {
    emit(state.copyWith(heading: event.heading, calibrationRequired: event.calibrationRequired));
  }

  void _onResetTrip(ResetTrip event, Emitter<SpeedometerState> emit) {
    emit(state.copyWith(
      maxSpeedKmh: 0,
      maxSpeedMph: 0,
      distanceKm: 0,
      distanceMiles: 0,
    ));
  }

  void _onToggleSpeedometerType(ToggleSpeedometerType event, Emitter<SpeedometerState> emit) {
    emit(state.copyWith(
      isDigital: !state.isDigital,
    ));
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    return super.close();
  }
}