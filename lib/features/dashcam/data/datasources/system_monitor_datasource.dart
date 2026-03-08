import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'system_monitor_interface.dart';

/// SystemMonitorDataSource implementation using battery_plus and platform channel.
class SystemMonitorDataSource implements ISystemMonitorDataSource {
  static const _thermalChannel = MethodChannel('com.mycompany.indiandriveguide/system_monitor');

  final Battery _battery = Battery();
  final StreamController<int> _batteryCtrl = StreamController.broadcast();
  final StreamController<bool> _chargingCtrl = StreamController.broadcast();
  final StreamController<ThermalState> _thermalCtrl = StreamController.broadcast();

  StreamSubscription? _batteryStateSubscription;
  Timer? _monitorTimer;

  @override
  Stream<int> get batteryLevelStream => _batteryCtrl.stream;
  @override
  Stream<bool> get chargingStream => _chargingCtrl.stream;
  @override
  Stream<ThermalState> get thermalStream => _thermalCtrl.stream;

  @override
  Future<int> getBatteryLevel() => _battery.batteryLevel;

  @override
  Future<void> startMonitoring() async {
    // Initial values
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    if (!_batteryCtrl.isClosed) _batteryCtrl.add(level);
    if (!_chargingCtrl.isClosed) _chargingCtrl.add(state == BatteryState.charging);

    // Listen to battery state changes
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) async {
      if (!_chargingCtrl.isClosed) {
        _chargingCtrl.add(state == BatteryState.charging);
      }
      
      // Also fetch and update the latest battery level whenever state changes 
      // (like plugging in or unplugging) so the UI doesn't lag showing the right percentage.
      try {
        final currentLevel = await _battery.batteryLevel;
        if (!_batteryCtrl.isClosed) _batteryCtrl.add(currentLevel);
      } catch (_) {}
    });

    // Periodically check battery level and thermal state
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final level = await _battery.batteryLevel;
        if (!_batteryCtrl.isClosed) _batteryCtrl.add(level);

        final thermalInt = await _thermalChannel.invokeMethod<int>('getThermalState') ?? 0;
        final thermal = _mapThermalState(thermalInt);
        if (!_thermalCtrl.isClosed) _thermalCtrl.add(thermal);
      } catch (_) {}
    });
  }

  @override
  Future<void> stopMonitoring() async {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    await _batteryStateSubscription?.cancel();
    _batteryStateSubscription = null;
  }

  @override
  Future<void> dispose() async {
    await stopMonitoring();
    if (!_batteryCtrl.isClosed) await _batteryCtrl.close();
    if (!_chargingCtrl.isClosed) await _chargingCtrl.close();
    if (!_thermalCtrl.isClosed) await _thermalCtrl.close();
  }

  ThermalState _mapThermalState(int value) {
    return switch (value) {
      0 => ThermalState.nominal,
      1 => ThermalState.fair,
      2 => ThermalState.serious,
      3 => ThermalState.severe,
      _ => ThermalState.critical,
    };
  }
}
