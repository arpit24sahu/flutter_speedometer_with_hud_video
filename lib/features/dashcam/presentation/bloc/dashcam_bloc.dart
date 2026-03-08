import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/datasources/system_monitor_interface.dart';
import '../../domain/entities/dashcam_failure.dart';
import '../../domain/entities/dashcam_telemetry.dart';
import '../../domain/usecases/start_recording_usecase.dart';
import '../../domain/usecases/stop_recording_usecase.dart';
import '../../domain/usecases/rotate_segment_usecase.dart';
import '../../domain/usecases/manage_storage_usecase.dart';
import '../../domain/usecases/monitor_safety_usecase.dart';
import '../../data/datasources/camera_datasource_interface.dart';
import '../../data/datasources/metadata_datasource_interface.dart';
import '../../data/dashcam_preferences.dart';
import '../../domain/repositories/dashcam_repository.dart';
import '../../domain/services/audio_session_service_interface.dart';
import '../../service/dashcam_platform_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/analytics/analytics_tracker.dart';
import '../../../../core/analytics/analytics_events.dart';

// ═══════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════

sealed class DashcamEvent {}

class InitializeDashcam extends DashcamEvent {}

class LoadDashcamSettings extends DashcamEvent {}

class StartRecording extends DashcamEvent {}

class StopRecording extends DashcamEvent {}

class UpdateStorageLimit extends DashcamEvent {
  final int maxStorageGb;
  UpdateStorageLimit(this.maxStorageGb);
}
class UpdateSegmentDuration extends DashcamEvent {
  final int durationSeconds;
  UpdateSegmentDuration(this.durationSeconds);
}
class ToggleMic extends DashcamEvent {}
class ToggleGps extends DashcamEvent {}

class UpdateSpeedUnit extends DashcamEvent {
  final String speedUnit;
  UpdateSpeedUnit(this.speedUnit);
}

class UpdateSpeedLimit extends DashcamEvent {
  final int speedLimit;
  UpdateSpeedLimit(this.speedLimit);
}

class UpdateVideoQuality extends DashcamEvent {
  final String videoQuality;
  UpdateVideoQuality(this.videoQuality);
}

class UpdateFrameRate extends DashcamEvent {
  final int frameRate;
  UpdateFrameRate(this.frameRate);
}

class ToggleGShockSetting extends DashcamEvent {
  final bool enabled;
  ToggleGShockSetting(this.enabled);
}

class ToggleClipLock extends DashcamEvent {
  final String fileId;
  ToggleClipLock(this.fileId);
}

class SwitchCamera extends DashcamEvent {}

class SwitchLens extends DashcamEvent {
  final int lensIndex;
  SwitchLens(this.lensIndex);
}

class CycleLens extends DashcamEvent {}

// Private internal events
class _TelemetryUpdated extends DashcamEvent {
  final DashcamTelemetry telemetry;
  _TelemetryUpdated(this.telemetry);
}

class _AccelerometerUpdated extends DashcamEvent {
  final double magnitude;
  _AccelerometerUpdated(this.magnitude);
}

class _BatteryUpdated extends DashcamEvent {
  final int level;
  _BatteryUpdated(this.level);
}

class _ChargingUpdated extends DashcamEvent {
  final bool isCharging;
  _ChargingUpdated(this.isCharging);
}

class _ThermalUpdated extends DashcamEvent {
  final ThermalState thermalState;
  _ThermalUpdated(this.thermalState);
}

class _SegmentTimerTick extends DashcamEvent {}

class _RecordingTimerTick extends DashcamEvent {}

/// Fired when an audio interruption begins (phone call, Siri, alarm).
class _AudioInterruptionBegan extends DashcamEvent {}

/// Fired when the audio interruption ends and the mic is available again.
class _AudioInterruptionEnded extends DashcamEvent {}

/// Fired when the app returns from background (safety net for camera state).
class AppLifecycleResumed extends DashcamEvent {}

// ═══════════════════════════════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════════════════════════════

class DashcamState extends Equatable {
  final DashcamStatus status;
  final bool isRecording;
  final Duration recordingDuration;
  final DashcamTelemetry? telemetry;
  final int batteryLevel;
  final bool isCharging;
  final ThermalState thermalState;
  final double remainingStorageGb;
  final int maxStorageGb;
  final int segmentDurationSeconds;
  final bool enableMic;
  final bool enableGps;
  final String speedUnit;
  final int speedLimit;
  final String videoQuality;
  final int frameRate;
  final bool enableGShock;
  final DateTime? collisionAlertEndTime;
  final DashcamFailure? error;
  final CameraController? cameraController;
  final bool isFrontCamera;
  final int currentLensIndex;
  final List<String> availableLensLabels;
  final int cameraRevision; // Increments on every camera/lens change to force rebuild

  const DashcamState({
    this.status = DashcamStatus.initial,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    this.telemetry,
    this.batteryLevel = 100,
    this.isCharging = false,
    this.thermalState = ThermalState.nominal,
    this.remainingStorageGb = 0.0,
    this.maxStorageGb = 20,
    this.segmentDurationSeconds = 120, // 2 mins
    this.enableMic = true,
    this.enableGps = true,
    this.speedUnit = 'km/h',
    this.speedLimit = 60, // 60 speed limit
    this.videoQuality = '1080p',
    this.frameRate = 60,
    this.enableGShock = true,
    this.collisionAlertEndTime,
    this.error,
    this.cameraController,
    this.isFrontCamera = false,
    this.currentLensIndex = 0,
    this.availableLensLabels = const ['1x'],
    this.cameraRevision = 0,
  });

  DashcamState copyWith({
    DashcamStatus? status,
    bool? isRecording,
    Duration? recordingDuration,
    DashcamTelemetry? telemetry,
    int? batteryLevel,
    bool? isCharging,
    ThermalState? thermalState,
    double? remainingStorageGb,
    int? maxStorageGb,
    int? segmentDurationSeconds,
    bool? enableMic,
    bool? enableGps,
    String? speedUnit,
    int? speedLimit,
    String? videoQuality,
    int? frameRate,
    bool? enableGShock,
    DateTime? collisionAlertEndTime,
    bool clearCollisionAlert = false,
    DashcamFailure? error,
    CameraController? cameraController,
    bool clearController = false,
    bool? isFrontCamera,
    int? currentLensIndex,
    List<String>? availableLensLabels,
    int? cameraRevision,
  }) {
    return DashcamState(
      status: status ?? this.status,
      isRecording: isRecording ?? this.isRecording,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      telemetry: telemetry ?? this.telemetry,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      thermalState: thermalState ?? this.thermalState,
      remainingStorageGb: remainingStorageGb ?? this.remainingStorageGb,
      maxStorageGb: maxStorageGb ?? this.maxStorageGb,
      segmentDurationSeconds: segmentDurationSeconds ?? this.segmentDurationSeconds,
      enableMic: enableMic ?? this.enableMic,
      enableGps: enableGps ?? this.enableGps,
      speedUnit: speedUnit ?? this.speedUnit,
      speedLimit: speedLimit ?? this.speedLimit,
      videoQuality: videoQuality ?? this.videoQuality,
      frameRate: frameRate ?? this.frameRate,
      enableGShock: enableGShock ?? this.enableGShock,
      collisionAlertEndTime: clearCollisionAlert ? null : (collisionAlertEndTime ?? this.collisionAlertEndTime),
      error: error,
      cameraController: clearController ? null : (cameraController ?? this.cameraController),
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      currentLensIndex: currentLensIndex ?? this.currentLensIndex,
      availableLensLabels: availableLensLabels ?? this.availableLensLabels,
      cameraRevision: cameraRevision ?? this.cameraRevision,
    );
  }

  @override
  List<Object?> get props => [
        status,
        isRecording,
        recordingDuration,
        telemetry,
        batteryLevel,
        isCharging,
        thermalState,
        remainingStorageGb,
        maxStorageGb,
        segmentDurationSeconds,
        enableMic,
        enableGps,
        speedUnit,
        speedLimit,
        videoQuality,
        frameRate,
        enableGShock,
        collisionAlertEndTime,
        error,
        cameraRevision, // Use revision instead of controller reference
        isFrontCamera,
        currentLensIndex,
        availableLensLabels,
      ];
}

enum DashcamStatus { initial, loading, ready, recording, error }

// ═══════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════

class DashcamBloc extends Bloc<DashcamEvent, DashcamState> {
  final DashcamRepository _repository;
  final StartRecordingUseCase _startRecording;
  final StopRecordingUseCase _stopRecording;
  final RotateSegmentUseCase _rotateSegment;
  final ManageStorageUseCase _manageStorage;
  final MonitorSafetyUseCase _monitorSafety;
  final ICameraDataSource _cameraDataSource;
  final IMetadataDataSource _metadataDataSource;
  final ISystemMonitorDataSource _systemMonitor;
  final IAudioSessionService _audioSessionService;
  final DashcamPreferences _preferences;

  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _chargingSubscription;
  StreamSubscription? _thermalSubscription;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _audioInterruptionSubscription;
  Timer? _segmentTimer;
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;
  DateTime? _lastTelemetryEmitTime;
  bool _isAudioInterrupted = false;

  DashcamBloc({
    required DashcamRepository repository,
    required StartRecordingUseCase startRecording,
    required StopRecordingUseCase stopRecording,
    required RotateSegmentUseCase rotateSegment,
    required ManageStorageUseCase manageStorage,
    required MonitorSafetyUseCase monitorSafety,
    required ICameraDataSource cameraDataSource,
    required IMetadataDataSource metadataDataSource,
    required ISystemMonitorDataSource systemMonitor,
    required IAudioSessionService audioSessionService,
    required DashcamPreferences preferences,
  })  : _repository = repository,
        _startRecording = startRecording,
        _stopRecording = stopRecording,
        _rotateSegment = rotateSegment,
        _manageStorage = manageStorage,
        _monitorSafety = monitorSafety,
        _cameraDataSource = cameraDataSource,
        _metadataDataSource = metadataDataSource,
        _systemMonitor = systemMonitor,
        _audioSessionService = audioSessionService,
        _preferences = preferences,
        super(const DashcamState()) {
    on<InitializeDashcam>(_onInitialize);
    on<LoadDashcamSettings>(_onLoadDashcamSettings);
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<UpdateStorageLimit>(_onUpdateStorageLimit);
    on<UpdateSegmentDuration>(_onUpdateSegmentDuration);
    on<ToggleMic>(_onToggleMic);
    on<ToggleGps>(_onToggleGps);
    on<UpdateSpeedUnit>(_onUpdateSpeedUnit);
    on<UpdateSpeedLimit>(_onUpdateSpeedLimit);
    on<UpdateVideoQuality>(_onUpdateVideoQuality);
    on<UpdateFrameRate>(_onUpdateFrameRate);
    on<ToggleGShockSetting>(_onToggleGShockSetting);
    on<ToggleClipLock>(_onToggleClipLock);
    on<SwitchCamera>(_onSwitchCamera);
    on<SwitchLens>(_onSwitchLens);
    on<CycleLens>(_onCycleLens);
    on<_TelemetryUpdated>(_onTelemetryUpdated);
    on<_AccelerometerUpdated>(_onAccelerometerUpdated);
    on<_BatteryUpdated>(_onBatteryUpdated);
    on<_ChargingUpdated>(_onChargingUpdated);
    on<_ThermalUpdated>(_onThermalUpdated);
    on<_SegmentTimerTick>(_onSegmentTimerTick);
    on<_RecordingTimerTick>(_onRecordingTimerTick);
    on<_AudioInterruptionBegan>(_onAudioInterruptionBegan);
    on<_AudioInterruptionEnded>(_onAudioInterruptionEnded);
    on<AppLifecycleResumed>(_onAppLifecycleResumed);
  }

  // ─── Event Handlers ──────────────────────────────────────────

  Future<void> _onInitialize(InitializeDashcam event, Emitter<DashcamState> emit) async {
    emit(state.copyWith(status: DashcamStatus.loading));

    final result = await _repository.initialize();
    if (result.isFailure) {
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_camera_error,
        params: {'error': result.failure.message, 'action': 'initialize'},
      );
      emit(state.copyWith(status: DashcamStatus.error, error: result.failure));
      return;
    }

    // Configure ambient audio mixing for background music
    // and subscribe to OS-level audio interruption events (phone calls)
    await _audioSessionService.configureForDashcam();
    _audioInterruptionSubscription?.cancel();
    _audioInterruptionSubscription = _audioSessionService.interruptionStream.listen((type) {
      if (type == DashcamAudioInterruption.began) {
        add(_AudioInterruptionBegan());
      } else {
        add(_AudioInterruptionEnded());
      }
    });

    // Sync initial interruption state — handles the edge case where the user
    // is already on a phone call when opening the dashcam.
    _isAudioInterrupted = _audioSessionService.isCurrentlyInterrupted;
    if (_isAudioInterrupted) {
      debugPrint('[DashcamBloc] ⚠️ Audio is already interrupted on init (user on call)');
    }

    // Subscribe to system monitors
    await _systemMonitor.startMonitoring();
    final initialBatteryLevel = await _systemMonitor.getBatteryLevel();
    
    _telemetrySubscription = _metadataDataSource.telemetryStream.listen(
      (t) => add(_TelemetryUpdated(t)),
    );
    _batterySubscription = _systemMonitor.batteryLevelStream.listen(
      (l) => add(_BatteryUpdated(l)),
    );
    _chargingSubscription = _systemMonitor.chargingStream.listen(
      (c) => add(_ChargingUpdated(c)),
    );
    _thermalSubscription = _systemMonitor.thermalStream.listen(
      (t) => add(_ThermalUpdated(t)),
    );

    // Get initial storage info
    final storageResult = await _manageStorage.getGlobalFreeSpaceGb();
    final remainingGb = storageResult.isSuccess ? storageResult.value : 0.0;

    emit(state.copyWith(
      status: DashcamStatus.ready,
      batteryLevel: initialBatteryLevel,
      cameraController: _cameraDataSource.controller,
      maxStorageGb: _preferences.storageLimitGb,
      segmentDurationSeconds: _preferences.segmentDurationSeconds,
      enableMic: _preferences.enableMic,
      enableGps: _preferences.enableGps,
      speedUnit: _preferences.speedUnit,
      speedLimit: _preferences.speedLimit,
      videoQuality: _preferences.videoQuality,
      frameRate: _preferences.frameRate,
      enableGShock: _preferences.enableGShock,
      remainingStorageGb: remainingGb,
      availableLensLabels: _cameraDataSource.availableLensLabels,
      currentLensIndex: _cameraDataSource.currentLensIndex,
    ));
  }

  Future<void> _onLoadDashcamSettings(LoadDashcamSettings event, Emitter<DashcamState> emit) async {
    // Force a state change so UI rebuilds with the new fetched settings
    emit(state.copyWith(status: DashcamStatus.loading));

    final storageResult = await _manageStorage.getGlobalFreeSpaceGb();
    final remainingGb = storageResult.isSuccess ? storageResult.value : 0.0;

    emit(state.copyWith(
      status: DashcamStatus.ready,
      maxStorageGb: _preferences.storageLimitGb,
      segmentDurationSeconds: _preferences.segmentDurationSeconds,
      enableMic: _preferences.enableMic,
      enableGps: _preferences.enableGps,
      speedUnit: _preferences.speedUnit,
      speedLimit: _preferences.speedLimit,
      videoQuality: _preferences.videoQuality,
      frameRate: _preferences.frameRate,
      enableGShock: _preferences.enableGShock,
      remainingStorageGb: remainingGb.clamp(0.0, double.infinity),
    ));
  }

  Future<void> _onStartRecording(StartRecording event, Emitter<DashcamState> emit) async {
    // If the user is already on a phone call, reinitialize the camera without
    // audio BEFORE starting recording. This prevents the AVAssetWriter from
    // opening a dead audio track that would corrupt the mp4.
    if (_isAudioInterrupted && _preferences.enableMic) {
      debugPrint('[DashcamBloc] 📞 User on call — starting recording without mic');
      await _cameraDataSource.reinitializeWithAudio(enableAudio: false);
      emit(state.copyWith(
        enableMic: false,
        cameraController: _cameraDataSource.controller,
        cameraRevision: state.cameraRevision + 1,
      ));
    }

    final result = await _startRecording.call();
    if (result.isFailure) {
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_recording_error,
        params: {'error': result.failure.message},
      );
      emit(state.copyWith(status: DashcamStatus.error, error: result.failure));
      return;
    }

    _recordingStartTime = DateTime.now();

    // Start segment rotation timer (reads from preferences, not hardcoded)
    final segmentDuration = _preferences.segmentDurationSeconds;
    _segmentTimer = Timer.periodic(Duration(seconds: segmentDuration), (_) {
      add(_SegmentTimerTick());
    });

    // Start recording duration timer (updates every second)
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(_RecordingTimerTick());
    });
    
    // Log recording started
    AnalyticsTracker().log(AnalyticsEvents.dashcam_recording_started, params: {
      'segment_duration': segmentDuration,
      'resolution': state.videoQuality,
      'is_front_camera': state.isFrontCamera,
        AnalyticsParams.freeDiskSpaceGb: state.remainingStorageGb
            .toStringAsFixed(2),
    });
    
    // Keep screen ON while recording
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    if (state.enableGShock) {
      _startAccelerometer();
    }

    emit(state.copyWith(
      status: DashcamStatus.recording,
      isRecording: true,
      recordingDuration: Duration.zero,
    ));
  }

  Future<void> _onStopRecording(StopRecording event, Emitter<DashcamState> emit) async {
    if (_recordingStartTime != null) {
      final elapsed = DateTime.now().difference(_recordingStartTime!);
      final minDuration = const Duration(seconds: 3);
      if (elapsed < minDuration) {
        // Enforce a minimum recording duration to prevent native MediaRecorder crash (early stop)
        await Future.delayed(minDuration - elapsed);
      }
    }

    _segmentTimer?.cancel();
    _segmentTimer = null;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStartTime = null;
    
    _stopAccelerometer();

    // Reset audio interruption state for the next recording session.
    // Without this, stopping during a call leaves _isAudioInterrupted=true,
    // causing the next session to silently ignore phone call interruptions.
    _isAudioInterrupted = false;

    // Stop keeping the screen ON
    try {
      await WakelockPlus.disable();
    } catch (_) {}

    final result = await _stopRecording.call();
    if (result.isFailure) {
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_recording_error,
        params: {'error': result.failure.message, 'action': 'stop_recording'},
      );
      emit(state.copyWith(status: DashcamStatus.error, error: result.failure));
      return;
    }

    // Refresh storage info
    final storageResult = await _manageStorage.getGlobalFreeSpaceGb();
    final remainingGb = storageResult.isSuccess ? storageResult.value : state.remainingStorageGb;

    // Log recording stopped
    AnalyticsTracker().log(AnalyticsEvents.dashcam_recording_stopped, params: {
      'recording_duration_seconds': state.recordingDuration.inSeconds,
      'battery_level': state.batteryLevel,
      'thermal_state': state.thermalState.name,
        AnalyticsParams.freeDiskSpaceGb: remainingGb.toStringAsFixed(2),
    });

    emit(state.copyWith(
      status: DashcamStatus.ready,
      isRecording: false,
      recordingDuration: Duration.zero,
      remainingStorageGb: remainingGb,
    ));
  }

  Future<void> _onUpdateStorageLimit(UpdateStorageLimit event, Emitter<DashcamState> emit) async {
    _preferences.storageLimitGb = event.maxStorageGb;
    final storageResult = await _manageStorage.getGlobalFreeSpaceGb();
    final remainingGb = storageResult.isSuccess ? storageResult.value : state.remainingStorageGb;

    emit(state.copyWith(
      maxStorageGb: event.maxStorageGb,
      remainingStorageGb: remainingGb,
    ));
  }

  Future<void> _onUpdateSegmentDuration(UpdateSegmentDuration event, Emitter<DashcamState> emit) async {
    _preferences.segmentDurationSeconds = event.durationSeconds;
    emit(state.copyWith(segmentDurationSeconds: event.durationSeconds));
  }

  Future<void> _onToggleMic(ToggleMic event, Emitter<DashcamState> emit) async {
    final newValue = !state.enableMic;
    _preferences.enableMic = newValue;
    emit(state.copyWith(enableMic: newValue));
  }


  Future<void> _onToggleGps(ToggleGps event, Emitter<DashcamState> emit) async {
    final newValue = !state.enableGps;
    _preferences.enableGps = newValue;
    emit(state.copyWith(enableGps: newValue));
  }

  Future<void> _onUpdateSpeedUnit(UpdateSpeedUnit event, Emitter<DashcamState> emit) async {
    _preferences.speedUnit = event.speedUnit;
    emit(state.copyWith(speedUnit: event.speedUnit));
  }

  Future<void> _onUpdateSpeedLimit(UpdateSpeedLimit event, Emitter<DashcamState> emit) async {
    _preferences.speedLimit = event.speedLimit;
    emit(state.copyWith(speedLimit: event.speedLimit));
  }

  Future<void> _onUpdateVideoQuality(UpdateVideoQuality event, Emitter<DashcamState> emit) async {
    _preferences.videoQuality = event.videoQuality;
    
    ResolutionPreset preset;
    switch (event.videoQuality) {
      case '4K':
      case '4k':
        preset = ResolutionPreset.ultraHigh;
        break;
      case '720p':
        preset = ResolutionPreset.high;
        break;
      case '1080p':
      default:
        preset = ResolutionPreset.veryHigh;
        break;
    }

    try {
      emit(state.copyWith(status: DashcamStatus.loading, videoQuality: event.videoQuality));
      await _cameraDataSource.setResolutionPreset(preset);
      emit(state.copyWith(
        status: DashcamStatus.ready,
        cameraController: _cameraDataSource.controller,
        cameraRevision: state.cameraRevision + 1,
      ));
    } catch (e) {
      debugPrint('[DashcamBloc] UpdateVideoQuality ERROR: $e');
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_camera_error,
        params: {'error': e.toString(), 'action': 'update_video_quality'},
      );
      // Emit error state on failure
      emit(state.copyWith(
        status: DashcamStatus.error, 
        error: CameraFailure('Failed to update video quality: $e')
      ));
    }
  }

  Future<void> _onUpdateFrameRate(UpdateFrameRate event, Emitter<DashcamState> emit) async {
    _preferences.frameRate = event.frameRate;

    try {
      emit(state.copyWith(status: DashcamStatus.loading, frameRate: event.frameRate));
      await _cameraDataSource.setFrameRate(event.frameRate);
      emit(state.copyWith(
        status: DashcamStatus.ready,
        cameraController: _cameraDataSource.controller,
        cameraRevision: state.cameraRevision + 1,
      ));
    } catch (e) {
      debugPrint('[DashcamBloc] UpdateFrameRate ERROR: $e');
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_camera_error,
        params: {'error': e.toString(), 'action': 'update_frame_rate'},
      );
      emit(state.copyWith(
        status: DashcamStatus.error, 
        error: CameraFailure('Failed to update frame rate: $e')
      ));
    }
  }

  Future<void> _onToggleClipLock(ToggleClipLock event, Emitter<DashcamState> emit) async {
    debugPrint('[DashcamBloc] _onToggleClipLock called for fileId: ${event.fileId}');
    await _manageStorage.toggleLock(event.fileId);
  }

  Future<void> _onSwitchCamera(SwitchCamera event, Emitter<DashcamState> emit) async {
    if (state.isRecording) return;

    // Emit loading state and clear controller so UI drops the old preview immediately
    emit(state.copyWith(status: DashcamStatus.loading, clearController: true));

    try {
      debugPrint('[DashcamBloc] SwitchCamera: isFront=${state.isFrontCamera}');
      final newDirection = state.isFrontCamera
          ? CameraLensDirection.back
          : CameraLensDirection.front;
          
      await _cameraDataSource.switchCamera(newDirection);
      debugPrint('[DashcamBloc] SwitchCamera success, lensLabels=${_cameraDataSource.availableLensLabels}');
      
      // Fix Bug 4: If front camera, reset UI index to 0. If back, pull from data source
      final newLensIndex = newDirection == CameraLensDirection.front 
          ? 0 
          : _cameraDataSource.currentLensIndex;

      emit(state.copyWith(
        status: DashcamStatus.ready,
        cameraController: _cameraDataSource.controller,
        isFrontCamera: !state.isFrontCamera,
        availableLensLabels: _cameraDataSource.availableLensLabels,
        currentLensIndex: newLensIndex,
        cameraRevision: state.cameraRevision + 1,
      ));
    } catch (e) {
      debugPrint('[DashcamBloc] SwitchCamera ERROR: $e');
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_camera_error,
        params: {'error': e.toString(), 'action': 'switch_camera'},
      );
      // Emit error state on failure (Fix Issue 6)
      emit(state.copyWith(
        status: DashcamStatus.error, 
        error: CameraFailure('Failed to switch camera: $e')
      ));
    }
  }

  Future<void> _onSwitchLens(SwitchLens event, Emitter<DashcamState> emit) async {
    debugPrint('[DashcamBloc] SwitchLens: index=${event.lensIndex}, isRecording=${state.isRecording}, isFront=${state.isFrontCamera}');
    if (state.isRecording || state.isFrontCamera) return;

    // Emit loading state and clear controller so UI drops the old preview immediately
    emit(state.copyWith(status: DashcamStatus.loading, clearController: true));

    try {
      await _cameraDataSource.switchLens(event.lensIndex);
      debugPrint('[DashcamBloc] SwitchLens success, new controller=${_cameraDataSource.controller}');
      emit(state.copyWith(
        status: DashcamStatus.ready,
        cameraController: _cameraDataSource.controller,
        currentLensIndex: event.lensIndex,
        cameraRevision: state.cameraRevision + 1,
      ));
    } catch (e) {
      debugPrint('[DashcamBloc] SwitchLens ERROR: $e');
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_camera_error,
        params: {'error': e.toString(), 'action': 'switch_lens'},
      );
      // Emit error state on failure (Fix Issue 6)
      emit(state.copyWith(
        status: DashcamStatus.error, 
        error: CameraFailure('Failed to switch lens: $e')
      ));
    }
  }

  Future<void> _onCycleLens(CycleLens event, Emitter<DashcamState> emit) async {
    if (state.isRecording || state.isFrontCamera || state.availableLensLabels.isEmpty) return;

    final nextIndex = (state.currentLensIndex + 1) % state.availableLensLabels.length;
    add(SwitchLens(nextIndex));
  }

  Future<void> _onToggleGShockSetting(ToggleGShockSetting event, Emitter<DashcamState> emit) async {
    _preferences.enableGShock = event.enabled;
    emit(state.copyWith(enableGShock: event.enabled));
    
    if (state.isRecording) {
      if (event.enabled) {
        _startAccelerometer();
      } else {
        _stopAccelerometer();
      }
    }
  }

  void _startAccelerometer() {
    _stopAccelerometer();
    try {
      _accelerometerSubscription = userAccelerometerEventStream().listen(
        (event) {
          final magnitude = sqrt(
            pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2),
          );
          add(_AccelerometerUpdated(magnitude));
        },
        onError: (error) {
          debugPrint('[DashcamBloc] Accelerometer stream error: $error');
        },
      );
    } catch (e) {
      debugPrint(
        '[DashcamBloc] Failed to start accelerometer (device might not have one): $e',
      );
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_accelerometer_error,
        params: {'error': e.toString()},
      );
    }
  }

  void _stopAccelerometer() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  void _onAccelerometerUpdated(_AccelerometerUpdated event, Emitter<DashcamState> emit) {
    if (!state.isRecording || !state.enableGShock) return;

    // 2.5G threshold
    const collisionThreshold = 2.5 * 9.81;

    final now = DateTime.now();
    final isAlerting = state.collisionAlertEndTime != null && 
        now.isBefore(state.collisionAlertEndTime!);

    if (event.magnitude > collisionThreshold && !isAlerting) {
      debugPrint('[DashcamBloc] Collision detected! Magnitude: ${event.magnitude}');
      
      DashcamPlatformService().playAlertSound();
      _repository.lockCurrentSegmentOnSave();

      emit(state.copyWith(collisionAlertEndTime: now.add(const Duration(seconds: 5))));
    }
  }

  void _onTelemetryUpdated(_TelemetryUpdated event, Emitter<DashcamState> emit) {
    if (_lastTelemetryEmitTime == null) {
      _lastTelemetryEmitTime = DateTime.now();
      emit(state.copyWith(telemetry: event.telemetry));
      return;
    }

    final now = DateTime.now();
    final currentSpeed = state.telemetry?.speedKmh ?? 0.0;
    final newSpeed = event.telemetry.speedKmh;
    final speedDiff = (newSpeed - currentSpeed).abs();

    // Throttle UI updates to 2Hz (500ms) to prevent 30Hz rapid flickering
    // unless there is a sudden speed change (> 3 km/h diff) for instant responsiveness.
    if (now.difference(_lastTelemetryEmitTime!).inMilliseconds >= 500 || speedDiff >= 3.0) {
      _lastTelemetryEmitTime = now;
      emit(state.copyWith(telemetry: event.telemetry));
    }
  }

  void _onBatteryUpdated(_BatteryUpdated event, Emitter<DashcamState> emit) {
    emit(state.copyWith(batteryLevel: event.level));
    _checkSafetyLimits(emit);
  }

  void _onChargingUpdated(_ChargingUpdated event, Emitter<DashcamState> emit) {
    emit(state.copyWith(isCharging: event.isCharging));
  }

  void _onThermalUpdated(_ThermalUpdated event, Emitter<DashcamState> emit) {
    emit(state.copyWith(thermalState: event.thermalState));
    _checkSafetyLimits(emit);
  }

  Future<void> _onSegmentTimerTick(_SegmentTimerTick event, Emitter<DashcamState> emit) async {
    if (!state.isRecording) return;
    final result = await _rotateSegment.call();
    if (result.isFailure) {
      // If rotation fails, try to stop gracefully
      add(StopRecording());
    }
  }

  void _onRecordingTimerTick(_RecordingTimerTick event, Emitter<DashcamState> emit) {
    if (_recordingStartTime == null) return;
    final elapsed = DateTime.now().difference(_recordingStartTime!);
    emit(state.copyWith(recordingDuration: elapsed));
  }

  // ─── Safety ───────────────────────────────────────────────────

  void _checkSafetyLimits(Emitter<DashcamState> emit) {
    if (!state.isRecording) return;

    final failure = _monitorSafety.check(
      batteryLevel: state.batteryLevel,
      isCharging: state.isCharging,
      thermalState: state.thermalState,
    );

    if (failure != null) {
      add(StopRecording());
      emit(state.copyWith(status: DashcamStatus.error, error: failure));
    }
  }

  // ─── Audio Interruption (Phone Calls) ──────────────────────────

  Future<void> _onAudioInterruptionBegan(
    _AudioInterruptionBegan event,
    Emitter<DashcamState> emit,
  ) async {
    if (!state.isRecording || _isAudioInterrupted) return;

    _isAudioInterrupted = true;
    debugPrint('[DashcamBloc] 📞 Audio interrupted — rotating to video-only segment');

    // Rotate segment: finalize current file (clean mp4), restart without mic
    final result = await _repository.rotateSegmentWithAudioChange(enableAudio: false);
    if (result.isFailure) {
      debugPrint('[DashcamBloc] Audio-change rotation failed, force stopping: ${result.failure}');
      // Fallback: stop entirely rather than risk corruption
      add(StopRecording());
      return;
    }

    emit(state.copyWith(
      enableMic: false,
      cameraController: _cameraDataSource.controller,
      cameraRevision: state.cameraRevision + 1,
    ));
  }

  Future<void> _onAudioInterruptionEnded(
    _AudioInterruptionEnded event,
    Emitter<DashcamState> emit,
  ) async {
    if (!state.isRecording || !_isAudioInterrupted) return;

    _isAudioInterrupted = false;
    debugPrint('[DashcamBloc] 📞 Audio restored — rotating to audio+video segment');

    // Reconfigure audio session (iOS requires this after interruption)
    await _audioSessionService.configureForDashcam();

    // Respect user's original mic preference
    final enableMic = _preferences.enableMic;
    final result = await _repository.rotateSegmentWithAudioChange(enableAudio: enableMic);
    if (result.isFailure) {
      debugPrint('[DashcamBloc] Failed to restore audio segment: ${result.failure}');
      // Continue recording video-only rather than stopping
    }

    emit(state.copyWith(
      enableMic: enableMic,
      cameraController: _cameraDataSource.controller,
      cameraRevision: state.cameraRevision + 1,
    ));
  }

  Future<void> _onAppLifecycleResumed(
    AppLifecycleResumed event,
    Emitter<DashcamState> emit,
  ) async {
    // Safety net: when the app returns from background, verify the camera
    // controller is still active. If not, emit the fresh controller reference.
    final ctrl = _cameraDataSource.controller;
    if (ctrl != null && ctrl != state.cameraController) {
      emit(state.copyWith(
        cameraController: ctrl,
        cameraRevision: state.cameraRevision + 1,
      ));
    }
  }

  // ─── Cleanup ──────────────────────────────────────────────────

  @override
  Future<void> close() async {
    _segmentTimer?.cancel();
    _recordingTimer?.cancel();
    await _telemetrySubscription?.cancel();
    await _batterySubscription?.cancel();
    await _chargingSubscription?.cancel();
    await _thermalSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    await _audioInterruptionSubscription?.cancel();
    
    // Ensure wakelock is disabled
    try {
      await WakelockPlus.disable();
    } catch (e) {
      // Ignore errors when Wakelock is disabled on unsupported platforms or tests
    }

    // Stop streams without permanently closing the controllers
    await _metadataDataSource.stopStreaming();
    await _systemMonitor.stopMonitoring();

    // Dispose camera hardware securely
    await _cameraDataSource.dispose();

    // Do NOT dispose _systemMonitor or _repository here because they are global
    // singletons injected via GetIt. Disposing them here breaks DashcamPage on re-entry.
    return super.close();
  }
}
