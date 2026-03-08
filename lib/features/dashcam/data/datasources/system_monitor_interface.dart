/// Thermal state enum — decoupled from platform.
enum ThermalState { nominal, fair, serious, severe, critical }

/// Interface for system monitoring (battery, thermal).
abstract class ISystemMonitorDataSource {
  Stream<int> get batteryLevelStream;
  Stream<bool> get chargingStream;
  Stream<ThermalState> get thermalStream;
  Future<int> getBatteryLevel();
  Future<void> startMonitoring();
  Future<void> stopMonitoring();
  Future<void> dispose();
}
