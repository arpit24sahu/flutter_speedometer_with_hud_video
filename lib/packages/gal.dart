import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling gallery operations
class GalService {
  /// Save a video to the gallery
  ///
  /// [videoPath] is the path to the video file
  /// [albumName] is the optional album name where the video will be saved
  /// Returns the path where the video was saved, or null if it failed
  Future<void> saveVideoToGallery(String videoPath, {String albumName = 'TurboGauge'}) async {
    try {
      // Check if the file exists
      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('GalService: File does not exist at path: $videoPath');
        return null;
      }

      // Request necessary permissions first
      final bool hasPermission = await _requestGalleryPermissions();
      if (!hasPermission) {
        debugPrint('GalService: Permissions not granted');
        return null;
      }

      // Use the gal package to save the video
     await Gal.putVideo(videoPath, album: albumName);

      debugPrint('GalService: Video saved successfully to gallery.');
    } catch (e) {
      debugPrint('GalService: Error saving video to gallery: $e');
      return null;
    }
  }

  /// Request necessary permissions for saving to gallery
  Future<bool> _requestGalleryPermissions() async {
    // For Android 13+ (API 33+)
    if (Platform.isAndroid) {
      // For Android 13+ specifically request video permissions
      final status = await Permission.videos.request();
      if (status.isGranted) {
        return true;
      }

      // For devices running Android 12 or below
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    // For iOS, the gal package handles permissions internally
    return true;
  }

  /// Check if the app has permission to save to gallery
  Future<bool> hasGalleryPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+
      bool hasVideoPermission = await Permission.videos.isGranted;
      // For older Android versions
      bool hasStoragePermission = await Permission.storage.isGranted;

      return hasVideoPermission || hasStoragePermission;
    }
    // For iOS
    return true;
  }
}
