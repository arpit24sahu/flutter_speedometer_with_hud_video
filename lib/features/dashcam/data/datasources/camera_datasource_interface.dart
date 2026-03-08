import 'package:camera/camera.dart';

/// Interface for camera operations, enabling testability.
abstract class ICameraDataSource {
  CameraController? get controller;
  List<CameraDescription> get cameras;
  CameraLensDirection get currentDirection;
  Future<void> initialize({bool enableAudio = true, ResolutionPreset resolutionPreset = ResolutionPreset.veryHigh, int fps = 60});
  Future<void> setResolutionPreset(ResolutionPreset preset);
  Future<void> setFrameRate(int fps);
  Future<String> startVideoRecording();
  Future<String> stopVideoRecording();
  Future<void> switchCamera(CameraLensDirection direction);
  Future<void> switchLens(int lensIndex);
  List<String> get availableLensLabels;
  int get currentLensIndex;
  /// Reinitializes the camera controller with a changed audio setting,
  /// preserving the current lens, resolution, and frame rate configuration.
  ///
  /// Used during phone call interruptions: disable audio to keep recording
  /// video-only, then re-enable when the call ends.
  Future<void> reinitializeWithAudio({required bool enableAudio});

  Future<void> dispose();
}
