import 'dart:io';
import 'package:flutter/services.dart';

/// Platform service for dashcam foreground service management.
/// Handles Android foreground service and iOS background task.
class DashcamPlatformService {
  // final MethodChannel _channel = const MethodChannel('com.mycompany.indiandriveguide/dashcam_service');

  Future<void> startService() async {
    // try {
    //   if (Platform.isAndroid) {
    //     await _channel.invokeMethod('startService');
    //   } else if (Platform.isIOS) {
    //     await _channel.invokeMethod('beginBackgroundTask');
    //   }
    // } catch (_) {
    //   // Platform not supported or ignored
    // }
  }

  Future<void> stopService() async {
    // try {
    //   if (Platform.isAndroid) {
    //     await _channel.invokeMethod('stopService');
    //   } else if (Platform.isIOS) {
    //     await _channel.invokeMethod('endBackgroundTask');
    //   }
    // } catch (_) {
    //   // Platform not supported or ignored
    // }
  }

  Future<void> playAlertSound() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await const MethodChannel('com.mycompany.indiandriveguide/alert_sound').invokeMethod('playAlertSound');
      }
    } catch (e) {
      print('Failed to play alert sound: $e');
    }
  }
}
