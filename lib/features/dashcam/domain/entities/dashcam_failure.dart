import 'package:equatable/equatable.dart';

/// Typed failure hierarchy for the dashcam feature.
/// Replaces all generic `e.toString()` error handling.
sealed class DashcamFailure extends Equatable {
  final String message;
  const DashcamFailure(this.message);

  @override
  List<Object?> get props => [message];

  @override
  String toString() => message;
}

class PermissionFailure extends DashcamFailure {
  const PermissionFailure([super.message = 'Required permission not granted']);
}

class StorageFullFailure extends DashcamFailure {
  const StorageFullFailure([super.message = 'Storage is full. All clips are locked.']);
}

class CameraFailure extends DashcamFailure {
  const CameraFailure([super.message = 'Camera error']);
}

class ThermalFailure extends DashcamFailure {
  const ThermalFailure([super.message = 'Device overheating. Recording stopped.']);
}

class BatteryFailure extends DashcamFailure {
  const BatteryFailure([super.message = 'Battery critically low']);
}

class ExportFailure extends DashcamFailure {
  const ExportFailure([super.message = 'Failed to export video']);
}

class UnknownDashcamFailure extends DashcamFailure {
  const UnknownDashcamFailure([super.message = 'An unexpected error occurred']);
}
