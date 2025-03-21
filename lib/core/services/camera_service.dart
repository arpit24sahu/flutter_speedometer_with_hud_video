import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

abstract class CameraService {
  Future<void> initialize();
  Future<void> startCamera(CameraController? controller);
  Future<void> stopCamera(CameraController? controller);
  Future<List<CameraDescription>> getAvailableCameras();
  Future<String?> startVideoRecording(CameraController controller);
  Future<void> stopVideoRecording(CameraController controller);
}

class CameraServiceImpl implements CameraService {
  @override
  Future<void> initialize() async {
    // Initialize camera service
  }

  @override
  Future<List<CameraDescription>> getAvailableCameras() async {
    try {
      return await availableCameras();
    } catch (e) {
      debugPrint('Error getting cameras: $e');
      return [];
    }
  }

  @override
  Future<void> startCamera(CameraController? controller) async {
    if (controller != null && !controller.value.isInitialized) {
      try {
        await controller.initialize();
      } catch (e) {
        debugPrint('Error initializing camera: $e');
      }
    }
  }

  @override
  Future<void> stopCamera(CameraController? controller) async {
    if (controller != null && controller.value.isInitialized) {
      await controller.dispose();
    }
  }

  @override
  Future<String?> startVideoRecording(CameraController controller) async {
    if (!controller.value.isInitialized) {
      return null;
    }

    try {
      await controller.startVideoRecording();
      return 'Recording started';
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      return null;
    }
  }

  @override
  Future<void> stopVideoRecording(CameraController controller) async {
    if (!controller.value.isRecordingVideo) {
      return;
    }

    try {
      await controller.stopVideoRecording();
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
    }
  }
}