import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/analytics/events/analytics_events.dart';
import '../features/analytics/services/analytics_service.dart';

class AppInitPrefsKeys {
  static const firstActiveAt = 'app_first_active_at';
  static const lastInitAt = 'app_last_init_at';
  static const initCount = 'app_init_count';
  static const activeDays = 'app_active_days';
}

class AppInitAnalyticsKeys {
  static const firstActiveAt = 'app_first_active';
  static const lastInitAt = 'last_initialization_time';
  static const initCount = 'app_initialization_counter';
  static const activeDays = 'active_days_count';
  static const daysSinceFirst = 'days_since_first_app_active';
  static const isNewActiveDay = 'is_new_active_day';
  static const timeTakenInMs = 'time_taken_in_ms';
}

class AppInitializationTracker {
  AppInitializationTracker._();
  static final AppInitializationTracker _instance = AppInitializationTracker._();
  factory AppInitializationTracker() => _instance;

  Future<void> track(DateTime startTime) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final firstMs = prefs.getInt(AppInitPrefsKeys.firstActiveAt);
    final lastMs = prefs.getInt(AppInitPrefsKeys.lastInitAt);
    final initCount = (prefs.getInt(AppInitPrefsKeys.initCount) ?? 0) + 1;
    final activeDays = prefs.getInt(AppInitPrefsKeys.activeDays) ?? 0;
    final timeTaken = DateTime.now().difference(startTime);

    if (firstMs == null) {
      await prefs.setInt(AppInitPrefsKeys.firstActiveAt, nowMs);
    }

    final isNewActiveDay = lastMs == null ||
        !_isSameDay(
          DateTime.fromMillisecondsSinceEpoch(lastMs),
          now,
        );

    final updatedActiveDays =
    isNewActiveDay ? activeDays + 1 : activeDays;

    await prefs.setInt(AppInitPrefsKeys.initCount, initCount);
    await prefs.setInt(AppInitPrefsKeys.lastInitAt, nowMs);
    if (isNewActiveDay) {
      await prefs.setInt(
        AppInitPrefsKeys.activeDays,
        updatedActiveDays,
      );
    }

    final firstDate = DateTime.fromMillisecondsSinceEpoch(
      firstMs ?? nowMs,
    );

    AnalyticsService().trackEvent(
      AnalyticsEvents.appInitialized,
      properties: {
        AppInitAnalyticsKeys.firstActiveAt: firstDate.toIso8601String(),
        AppInitAnalyticsKeys.lastInitAt: now.toIso8601String(),
        AppInitAnalyticsKeys.initCount: initCount,
        AppInitAnalyticsKeys.activeDays: updatedActiveDays,
        AppInitAnalyticsKeys.daysSinceFirst: now.difference(firstDate).inDays,
        AppInitAnalyticsKeys.isNewActiveDay: isNewActiveDay,
        AppInitAnalyticsKeys.timeTakenInMs: timeTaken.inMilliseconds,
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}