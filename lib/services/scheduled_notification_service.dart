import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/services/notification_service.dart';

/// Well-known notification IDs for scheduled notifications.
///
/// Using fixed IDs allows us to cancel/replace specific notifications.
class NotificationIds {
  NotificationIds._();

  static const int premiumUpgradeReminder = 1001;
  static const int dailyEngagement = 1002;
  static const int weeklyRecap = 1003;
  static const int recordingReminder = 1004;
}

/// Singleton service for scheduling notifications.
///
/// Built on top of [NotificationService] — this service only orchestrates
/// WHEN to send notifications. The actual rendering is handled by
/// [NotificationService].
class ScheduledNotificationService {
  ScheduledNotificationService._internal();
  static final ScheduledNotificationService _instance =
      ScheduledNotificationService._internal();
  factory ScheduledNotificationService() => _instance;

  final NotificationService _notificationService = NotificationService();

  // ─────────────────────────────────────────────────────────────────────────
  // Premium Upgrade Reminder
  // ─────────────────────────────────────────────────────────────────────────

  /// Schedule a reminder 5 minutes after the user dismisses the premium
  /// upgrade dialog without purchasing.
  Future<void> schedulePremiumUpgradeReminder() async {
    final scheduledAt = DateTime.now().add(const Duration(minutes: 5));

    await _notificationService.scheduleNotification(
      id: NotificationIds.premiumUpgradeReminder,
      title: 'Changed your mind about upgrading to premium? 🚀',
      body: "It's cheaper than your morning coffee for a limited time only ☕",
      scheduledAt: scheduledAt,
      payload: 'turbogauge://premium_upgrade_page',
    );

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationScheduled,
      properties: {
        AnalyticsParams.notificationId:
            NotificationIds.premiumUpgradeReminder.toString(),
        AnalyticsParams.notificationType: 'premium_upgrade_reminder',
        'scheduled_at': scheduledAt.toIso8601String(),
        'delay_minutes': 5,
      },
    );

    debugPrint(
        'ScheduledNotificationService: Premium upgrade reminder scheduled for $scheduledAt');
  }

  /// Cancel the premium upgrade reminder (e.g., if the user purchases).
  Future<void> cancelPremiumUpgradeReminder() async {
    await _notificationService
        .cancelNotification(NotificationIds.premiumUpgradeReminder);
    debugPrint(
        'ScheduledNotificationService: Premium upgrade reminder cancelled');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Engagement Notifications
  // ─────────────────────────────────────────────────────────────────────────

  /// Schedule daily engagement notification reminding user to record.
  Future<void> scheduleDailyEngagementNotification() async {
    await _notificationService.scheduleRecurringNotification(
      id: NotificationIds.dailyEngagement,
      title: 'Ready to hit the road? 🏎️',
      body: 'Open TurboGauge and capture your drive with a stunning speedometer overlay.',
      interval: RepeatInterval.daily,
      payload: 'turbogauge://home',
    );

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationScheduled,
      properties: {
        AnalyticsParams.notificationId:
            NotificationIds.dailyEngagement.toString(),
        AnalyticsParams.notificationType: 'daily_engagement',
      },
    );

    debugPrint(
        'ScheduledNotificationService: Daily engagement notification scheduled');
  }

  /// Schedule weekly recap notification.
  Future<void> scheduleWeeklyRecapNotification() async {
    await _notificationService.scheduleRecurringNotification(
      id: NotificationIds.weeklyRecap,
      title: 'Your Weekly Speed Recap 📊',
      body: 'Check out your recorded drives and share your best moments!',
      interval: RepeatInterval.weekly,
      payload: 'turbogauge://home',
    );

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationScheduled,
      properties: {
        AnalyticsParams.notificationId: NotificationIds.weeklyRecap.toString(),
        AnalyticsParams.notificationType: 'weekly_recap',
      },
    );

    debugPrint(
        'ScheduledNotificationService: Weekly recap notification scheduled');
  }

  /// Schedule a one-time recording reminder notification.
  ///
  /// Useful for nudging the user to try recording if they haven't yet.
  Future<void> scheduleRecordingReminder({
    Duration delay = const Duration(hours: 24),
  }) async {
    final scheduledAt = DateTime.now().add(delay);

    await _notificationService.scheduleNotification(
      id: NotificationIds.recordingReminder,
      title: "Your speedometer overlay awaits! 🎬",
      body: "Record a drive and see your speed come alive on video.",
      scheduledAt: scheduledAt,
      payload: 'turbogauge://home',
    );

    debugPrint(
        'ScheduledNotificationService: Recording reminder scheduled for $scheduledAt');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Setup All Recurring Notifications
  // ─────────────────────────────────────────────────────────────────────────

  /// Call this during app initialization to set up all recurring notifications.
  Future<void> setupRecurringNotifications() async {
    await scheduleDailyEngagementNotification();
    await scheduleWeeklyRecapNotification();
    debugPrint(
        'ScheduledNotificationService: All recurring notifications set up');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cancel
  // ─────────────────────────────────────────────────────────────────────────

  /// Cancel a specific scheduled notification.
  Future<void> cancelScheduledNotification(int id) async {
    await _notificationService.cancelNotification(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAllScheduled() async {
    await _notificationService.cancelAllNotifications();
  }
}
