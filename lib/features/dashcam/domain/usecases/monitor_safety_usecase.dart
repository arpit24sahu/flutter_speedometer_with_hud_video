import '../../data/datasources/system_monitor_interface.dart';
import '../entities/dashcam_failure.dart';

/// Determines if recording should be force-stopped for safety reasons.
/// Returns a failure describing the reason, or null if safe to continue.
class MonitorSafetyUseCase {
  static const int criticalBatteryThreshold = 5;

  /// Checks current system state and returns a failure if unsafe.
  DashcamFailure? check({
    required int batteryLevel,
    required bool isCharging,
    required ThermalState thermalState,
  }) {
    if (batteryLevel <= criticalBatteryThreshold && !isCharging) {
      return BatteryFailure('Battery critically low ($batteryLevel%)');
    }

    if (thermalState == ThermalState.critical) {
      return const ThermalFailure('Device too hot. Recording stopped to prevent damage.');
    }

    return null; // Safe to continue
  }

  /// Returns true if thermal state warrants a warning (but not a stop).
  bool shouldWarn(ThermalState thermalState) {
    return thermalState == ThermalState.severe;
  }
}
