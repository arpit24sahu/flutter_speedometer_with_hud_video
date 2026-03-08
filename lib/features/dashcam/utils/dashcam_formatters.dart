import 'package:intl/intl.dart';

/// Shared formatters for the dashcam feature.
/// Eliminates duplication across dashcam_page, playback_page, etc.
class DashcamFormatters {
  const DashcamFormatters._();

  /// Formats duration as MM:SS or HH:MM:SS.
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  /// Formats a DateTime as a human-readable timestamp for overlays.
  static String formatTimestamp(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  /// Formats speed in km/h with 1 decimal place.
  static String formatSpeed(double speedKmh) {
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }

  /// Formats GPS coordinates.
  static String formatCoordinates(double lat, double lng) {
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  /// Formats storage in GB with 1 decimal place.
  static String formatStorageGb(double gb) {
    return '${gb.toStringAsFixed(1)} GB';
  }
}
