import 'package:screen_recorder/screen_recorder.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

abstract class ScreenRecordService {
  Future<void> initialize();
  Future<void> startRecording();
  Future<String?> stopRecording(); // Returns file path
  Future<void> dispose();
}

class ScreenRecordServiceImpl implements ScreenRecordService {
  final ScreenRecorderController _controller = ScreenRecorderController();
  bool _isInitialized = false;
  bool _isRecording = false;

  @override
  Future<void> initialize() async {
    if (!_isInitialized) {
      // Initialize any required resources here
      _isInitialized = true;
    }
  }

  @override
  Future<void> startRecording() async {
    if (!_isInitialized) {
      debugPrint('ScreenRecordService not initialized');
      return;
    }

    if (_isRecording) {
      debugPrint('Recording already in progress');
      return;
    }

    try {
      _controller.start();
      _isRecording = true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      rethrow;
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('No recording in progress');
      return null;
    }

    try {
      _controller.stop();
      _isRecording = false;

      // Export the recording as GIF
      final gif = await _controller.exporter.exportGif();
      if (gif != null) {
        // Save the GIF to file
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputPath = '${directory.path}/recording_$timestamp.gif';

        final file = File(outputPath);
        await file.writeAsBytes(gif);
        return outputPath;
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    if (_isRecording) {
      _controller.stop();
    }
    // _controller.dispose();
    _isInitialized = false;
  }
}