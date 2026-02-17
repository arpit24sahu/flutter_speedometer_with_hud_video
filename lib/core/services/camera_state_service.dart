import 'package:flutter/foundation.dart';

/// Lightweight singleton service that tracks camera state.
///
/// Used by [HomeScreen] to disable tab switching while recording,
/// and by [CameraScreen] to gate UI actions.
class CameraStateService extends ChangeNotifier {
  CameraStateService._internal();
  static final CameraStateService _instance = CameraStateService._internal();
  factory CameraStateService() => _instance;

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isControllerReady = false;

  /// Whether the camera is actively recording video.
  bool get isRecording => _isRecording;

  /// Whether a recorded video is currently being processed.
  bool get isProcessing => _isProcessing;

  /// Whether the camera controller is initialized and ready.
  bool get isControllerReady => _isControllerReady;

  /// Whether the user should be prevented from switching tabs.
  /// True during recording or processing.
  bool get shouldBlockTabSwitch => _isRecording || _isProcessing;

  /// Whether camera actions (flip, settings) should be disabled.
  /// True during recording or processing.
  bool get shouldBlockCameraActions => _isRecording || _isProcessing;

  void setRecording(bool value) {
    if (_isRecording != value) {
      _isRecording = value;
      debugPrint('CameraStateService: isRecording = $value');
      notifyListeners();
    }
  }

  void setProcessing(bool value) {
    if (_isProcessing != value) {
      _isProcessing = value;
      debugPrint('CameraStateService: isProcessing = $value');
      notifyListeners();
    }
  }

  void setControllerReady(bool value) {
    if (_isControllerReady != value) {
      _isControllerReady = value;
      notifyListeners();
    }
  }

  /// Reset all state (e.g. when camera screen is disposed).
  void reset() {
    _isRecording = false;
    _isProcessing = false;
    _isControllerReady = false;
    notifyListeners();
  }
}
