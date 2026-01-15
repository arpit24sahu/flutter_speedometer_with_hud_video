import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._internal();
  static final FirebaseAnalyticsService _instance = FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  void logEvent(String eventName, Map<String, Object>? properties) {
    _analytics.logEvent(name: eventName, parameters: properties);
  }
}