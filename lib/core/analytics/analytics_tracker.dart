/// Compatibility bridge for the dashcam feature's analytics calls.
///
/// The dashcam module was originally built with a different analytics API
/// (`AnalyticsTracker().log(...)` / `.trackScreen(...)`).
/// This thin wrapper delegates to the project's canonical [AnalyticsService]
/// so the dashcam code can work without mass-renaming its call sites.
import 'package:speedometer/features/analytics/services/analytics_service.dart';

class AnalyticsTracker {
  AnalyticsTracker._internal();
  static final AnalyticsTracker _instance = AnalyticsTracker._internal();
  factory AnalyticsTracker() => _instance;

  /// Logs a named event with optional parameters.
  void log(String eventName, {Map<String, dynamic>? params}) {
    AnalyticsService().trackEvent(eventName, properties: params);
  }

  /// Tracks a screen view.
  void trackScreen({required String screenName, String? screenClass}) {
    AnalyticsService().trackEvent('screen_view', properties: {
      'screen_name': screenName,
      if (screenClass != null) 'screen_class': screenClass,
    });
  }
}
