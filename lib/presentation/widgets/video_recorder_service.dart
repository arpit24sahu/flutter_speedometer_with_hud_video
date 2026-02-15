import 'dart:io';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'dart:typed_data';


class StopRecordingReturnObject {
  final String? cameraVideoPath;
  final Map<int, PositionData>? positionData;
  final String? error;

  const StopRecordingReturnObject({
   this.cameraVideoPath,
    this.positionData,
    this.error
  });
}

class WidgetRecorderService {
  // Key for the widget to record
  final GlobalKey widgetKey;

  // Camera controller
  final CameraController cameraController;

  // Recording state
  bool _isRecording = false;

  // Timer for capturing frames
  int _frameCount = 0;
  DateTime? _recordingStartTime;

  Map<int, PositionData> _positionData = {};

  // List of captured widget frames
  // final List<ui.Image> _capturedFrames = [];

  // Frame capture interval (milliseconds)
  final int frameCaptureInterval;

  WidgetRecorderService({
    required this.widgetKey,
    required this.cameraController,
    this.frameCaptureInterval = 50, // 10 fps by default
  });

  bool get isRecording => _isRecording;

  // Start recording both camera and widget
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    // Clear previous recording data
    _frameCount = 0;
    _recordingStartTime = DateTime.now();
    _positionData = {};

    // Start camera recording
    if (!cameraController.value.isRecordingVideo) {
      await cameraController.startVideoRecording();
    }

    // Start widget recording
    _isRecording = true;

    return true;
  }

  // Stop recording and save files
  Future<StopRecordingReturnObject> stopRecording(
      GaugePlacement placement,
      double relativeSize
      ) async {
    if (!_isRecording) {
      return StopRecordingReturnObject(error: 'Not currently recording'); // {'error': 'Not currently recording'};
    }
    DateTime startTime = DateTime.now();

    // Stop recording state
    _isRecording = false;

    // Stop camera recording and get video file
    late final XFile videoFile;
    if (cameraController.value.isRecordingVideo) {
      videoFile = await cameraController.stopVideoRecording();
    } else {
      return StopRecordingReturnObject(error: 'Camera was not recording');
    }

    print("Time Taken for stop recording: ${DateTime.now().difference(startTime).inMilliseconds}");

    // Save video file to app directory
    final videoPath = await _saveVideoToAppDirectory(videoFile);
    print("Time Taken for _saveVideoToAppDirectory: ${DateTime.now().difference(startTime).inMilliseconds}");

    return StopRecordingReturnObject(
      cameraVideoPath: videoPath,
    );
  }

  // Capture frames of the widget
  // Future<void> _captureWidgetFrames() async {
  //   if (!_isRecording) return;
  //
  //   try {
  //     // Capture the repaint boundary
  //     final boundary = widgetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  //     if (boundary != null) {
  //       final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  //       _frameCount++;
  //     }
  //   } catch (e) {
  //     debugPrint('Error capturing widget frame: $e');
  //   }
  //
  //   // Schedule next frame capture
  //   if (_isRecording) {
  //     Future.delayed(Duration(milliseconds: frameCaptureInterval), _captureWidgetFrames);
  //   }
  // }

  // Save video file to application directory
  Future<String> _saveVideoToAppDirectory(XFile videoFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = path.join(directory.path, 'CameraRecording_$timestamp.mp4');

    // Copy file to app directory
    final File newFile = File(newPath);
    await newFile.writeAsBytes(await videoFile.readAsBytes());

    return newPath;
  }

  // Add green background to widget image
  Uint8List _addGreenBackground(ByteData byteData) {
    // This is a simplified version - you would typically use a more sophisticated image processing approach
    // to add a proper green screen background while maintaining transparency

    final bytes = byteData.buffer.asUint8List();
    return bytes; // In a real implementation, you would modify these bytes to add green background
  }
}
