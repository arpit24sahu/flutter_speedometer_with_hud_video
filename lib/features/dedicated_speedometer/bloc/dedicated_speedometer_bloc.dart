import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/dedicated_speedometer/services/dedicated_speedometer_service.dart';

abstract class DedicatedSpeedometerEvent {}

class StartDedicatedSpeedometer extends DedicatedSpeedometerEvent {}

class StopDedicatedSpeedometer extends DedicatedSpeedometerEvent {}

class UpdateDedicatedSpeed extends DedicatedSpeedometerEvent {
  final double speedMps;
  UpdateDedicatedSpeed(this.speedMps);
}

class ToggleUnitEvent extends DedicatedSpeedometerEvent {}

class ToggleAnalogDigitalEvent extends DedicatedSpeedometerEvent {}

enum SpeedUnit { kmh, mph }
enum DisplayMode { digital, analog }

class DedicatedSpeedometerState {
  final double currentSpeedMps;
  final SpeedUnit unit;
  final DisplayMode displayMode;
  final bool isTracking;

  DedicatedSpeedometerState({
    this.currentSpeedMps = 0.0,
    this.unit = SpeedUnit.kmh,
    this.displayMode = DisplayMode.digital,
    this.isTracking = false,
  });

  double get displaySpeed {
    if (unit == SpeedUnit.kmh) return currentSpeedMps * 3.6;
    return currentSpeedMps * 2.23694; // m/s to mph
  }

  DedicatedSpeedometerState copyWith({
    double? currentSpeedMps,
    SpeedUnit? unit,
    DisplayMode? displayMode,
    bool? isTracking,
  }) {
    return DedicatedSpeedometerState(
      currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
      unit: unit ?? this.unit,
      displayMode: displayMode ?? this.displayMode,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

class DedicatedSpeedometerBloc extends Bloc<DedicatedSpeedometerEvent, DedicatedSpeedometerState> {
  final DedicatedSpeedometerService _service;
  StreamSubscription<double>? _speedSub;

  DedicatedSpeedometerBloc(this._service) : super(DedicatedSpeedometerState()) {
    on<StartDedicatedSpeedometer>((event, emit) async {
      final hasPermission = await _service.requestPermissionIfNotGranted();
      if (!hasPermission) return;

      emit(state.copyWith(isTracking: true));
      _speedSub?.cancel();
      _speedSub = _service.getSpeedStream().listen((speed) {
        if (!isClosed) {
          add(UpdateDedicatedSpeed(speed));
        }
      });
    });

    on<StopDedicatedSpeedometer>((event, emit) {
      _speedSub?.cancel();
      emit(state.copyWith(isTracking: false, currentSpeedMps: 0));
    });

    on<UpdateDedicatedSpeed>((event, emit) {
      emit(state.copyWith(currentSpeedMps: event.speedMps));
    });

    on<ToggleUnitEvent>((event, emit) {
      final nextUnit = state.unit == SpeedUnit.kmh ? SpeedUnit.mph : SpeedUnit.kmh;
      emit(state.copyWith(unit: nextUnit));
    });

    on<ToggleAnalogDigitalEvent>((event, emit) {
      final nextMode = state.displayMode == DisplayMode.digital ? DisplayMode.analog : DisplayMode.digital;
      emit(state.copyWith(displayMode: nextMode));
    });
  }

  @override
  Future<void> close() {
    _speedSub?.cancel();
    return super.close();
  }
}
