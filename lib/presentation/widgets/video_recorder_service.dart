import 'dart:io';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/utils.dart';
import 'package:typed_data/typed_data.dart';
import 'dart:typed_data';

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

  // List of captured widget frames
  final List<ui.Image> _capturedFrames = [];

  // Frame capture interval (milliseconds)
  final int frameCaptureInterval;

  WidgetRecorderService({
    required this.widgetKey,
    required this.cameraController,
    this.frameCaptureInterval = 50, // 10 fps by default
  });

  bool get isRecording => _isRecording;

  // Start recording both camera and widget
  Future<void> startRecording() async {
    if (_isRecording) return;

    // Clear previous recording data
    _capturedFrames.clear();
    _frameCount = 0;
    _recordingStartTime = DateTime.now();

    // Start camera recording
    if (!cameraController.value.isRecordingVideo) {
      await cameraController.startVideoRecording();
    }

    // Start widget recording
    _isRecording = true;
    _captureWidgetFrames();
  }

  // Stop recording and save files
  Future<Map<String, String>> stopRecording(
      GaugePlacement placement,
      double relativeSize
      ) async {
    if (!_isRecording) {
      return {'error': 'Not currently recording'};
    }

    // Stop recording state
    _isRecording = false;

    // Stop camera recording and get video file
    late final XFile videoFile;
    if (cameraController.value.isRecordingVideo) {
      videoFile = await cameraController.stopVideoRecording();
    } else {
      return {'error': 'Camera was not recording'};
    }

    // Save video file to app directory
    final videoPath = await _saveVideoToAppDirectory(videoFile);

    // Generate and save widget recording with green background
    final widgetVideoPath = await _saveWidgetRecording();

    // final finalVideoPath = await processChromaKeyVideo(
    //     backgroundPath: videoPath,
    //     foregroundPath: widgetVideoPath,
    //   placement: placement,
    //   relativeSize: relativeSize
    // );

    return {
      'cameraVideoPath': videoPath,
      'widgetVideoPath': widgetVideoPath,
      // 'finalVideoPath': finalVideoPath??""
    };
  }

  // Capture frames of the widget
  Future<void> _captureWidgetFrames() async {
    if (!_isRecording) return;

    try {
      // Capture the repaint boundary
      final boundary = widgetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        _capturedFrames.add(image);
        _frameCount++;
      }
    } catch (e) {
      debugPrint('Error capturing widget frame: $e');
    }

    // Schedule next frame capture
    if (_isRecording) {
      Future.delayed(Duration(milliseconds: frameCaptureInterval), _captureWidgetFrames);
    }
  }

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

  // Save widget recording with green screen background
  Future<String> _saveWidgetRecording() async {
    if (_capturedFrames.isEmpty) {
      return 'No frames captured';
    }
    print("Creating widget recording from ${_capturedFrames.length} frames");

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDirPath = path.join(directory.path, 'temp_frames_$timestamp');
    final outputPath = path.join(directory.path, 'WidgetRecording_$timestamp.mp4');

    print("Temp frames directory: $tempDirPath");
    print("Output video path: $outputPath");
    final tempDir = Directory(tempDirPath);
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    print("Saving frames to disk...");
    for (int i = 0; i < _capturedFrames.length; i++) {
      final image = _capturedFrames[i];
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final frameFile = File(path.join(tempDirPath, 'frame_${i.toString().padLeft(6, '0')}.png'));
        await frameFile.writeAsBytes(byteData.buffer.asUint8List());
      }
    }

    // Set up conversion parameters
    final fps = (1000 / frameCaptureInterval)
            .round(); // Calculate FPS based on capture interval
    print("Converting frames to video at $fps FPS...");

    try {
      final command = [
        '-framerate', '$fps',
        '-i', '${tempDirPath}/frame_%06d.png',
        '-c:v', 'mpeg4', // Use `mpeg4` instead of `libx264`
        '-q:v', '5', // Adjust quality (lower = better)
        '-preset', 'ultrafast',
        outputPath,
      ].join(' ');

      // final command = '-framerate $fps -i ${tempDirPath}/frame_%06d.png -c:v libx264 -pix_fmt yuv420p -b:v 2M ${outputPath}';
      print("Executing FFmpeg command: $command");
      final session = await FFmpegKit.execute(command);
      final rc = await session.getReturnCode();
      print("FFmpeg execution return code: $rc");

      if (ReturnCode.isSuccess(rc)) {
        print("Success");
      } else if (ReturnCode.isCancel(rc)) {
        print("Cancelled");
      } else {
        print("Failed");
      }

      // Convert frames to video
      // final result = await ffmpeg.executeFFmpeg(
      //   inputPath: tempDirPath,
      //   inputPattern: 'frame_%06d.png',
      //   outputPath: outputPath,
      //   frameRate: fps,
      //   videoBitrate: "2M",  // 2 Mbps - adjust as needed
      // );
    } catch (e) {
      print("Error converting frames to video: $e");
    }

    // Create final output path for the video/gif
    // final outputPath = path.join(directory.path, 'widget_recording_$timestamp.gif');

    // Here you would use a library like FFmpeg to convert the frames into a video with green background
    // For simplicity in this example, we'll just return the directory path
    // You would need to implement the actual conversion using a platform-specific solution

    return outputPath;
  }

  // Add green background to widget image
  Uint8List _addGreenBackground(ByteData byteData) {
    // This is a simplified version - you would typically use a more sophisticated image processing approach
    // to add a proper green screen background while maintaining transparency

    final bytes = byteData.buffer.asUint8List();
    return bytes; // In a real implementation, you would modify these bytes to add green background
  }
}
