import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/services/deeplink_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Top-level background message handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService: Background message received: ${message.messageId}');
}

/// Singleton service responsible for both local and remote (FCM) notifications.
///
/// Handles:
/// - Initializing flutter_local_notifications with Android channel
/// - FCM setup: foreground, background, terminated-state handlers
/// - Showing/canceling local notifications
/// - Routing notification taps to [DeeplinkService]
/// - Tracking analytics events for all notification lifecycle events
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Android notification channel
  static const String _channelId = 'turbogauge_default';
  static const String _channelName = 'TurboGauge Notifications';
  static const String _channelDescription = 'Default notification channel for TurboGauge';

  /// Initialize the notification service.
  ///
  /// Sets up local notifications, FCM, and all message handlers.
  /// Should be called once during app startup after Firebase.initializeApp().
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone data for scheduled notifications
      tz.initializeTimeZones();

      // Setup local notifications
      await _initializeLocalNotifications();

      // Setup FCM
      await _initializeFCM();

      _initialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize - $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local Notification Setup
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM Setup
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initializeFCM() async {
    // Request permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationPermissionRequested,
      properties: {
        'status': settings.authorizationStatus.name,
      },
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      AnalyticsService().trackEvent(AnalyticsEvents.notificationPermissionGranted);
    } else {
      AnalyticsService().trackEvent(AnalyticsEvents.notificationPermissionDenied);
    }

    // Get FCM token
    _fcmToken = await _firebaseMessaging.getToken();
    debugPrint('NotificationService: FCM Token: $_fcmToken');

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('NotificationService: FCM Token refreshed: $newToken');
      AnalyticsService().trackEvent(
        AnalyticsEvents.fcmTokenRefreshed,
        properties: {'token_prefix': newToken.substring(0, 10)},
      );
    });

    // Register background handler (top-level function)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // User tapped notification while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('NotificationService: App opened from terminated via notification');
      _handleRemoteMessageTap(initialMessage);
    }

    // Show foreground notifications on iOS
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM Message Handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('NotificationService: Foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification != null) {
      // Show as local notification so user can see it
      showNotification(
        id: message.hashCode,
        title: notification.title ?? 'TurboGauge',
        body: notification.body ?? '',
        payload: message.data['deeplink'],
      );
    }

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationShown,
      properties: {
        AnalyticsParams.notificationType: 'fcm_foreground',
        AnalyticsParams.notificationTitle: notification?.title ?? '',
        AnalyticsParams.notificationBody: notification?.body ?? '',
        'message_id': message.messageId ?? '',
      },
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('NotificationService: Message opened app: ${message.messageId}');
    _handleRemoteMessageTap(message);
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    final deeplink = message.data['deeplink'] as String?;

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationOpened,
      properties: {
        AnalyticsParams.notificationType: 'fcm',
        AnalyticsParams.deeplinkUri: deeplink ?? '',
        'message_id': message.messageId ?? '',
      },
    );

    if (deeplink != null && deeplink.isNotEmpty) {
      DeeplinkService().handleDeeplink(deeplink);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local Notification Tap Handler
  // ─────────────────────────────────────────────────────────────────────────

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped: ${response.payload}');

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationOpened,
      properties: {
        AnalyticsParams.notificationType: 'local',
        AnalyticsParams.notificationId: response.id?.toString() ?? '',
        AnalyticsParams.deeplinkUri: response.payload ?? '',
      },
    );

    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      DeeplinkService().handleDeeplink(payload);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API — Show / Cancel Notifications
  // ─────────────────────────────────────────────────────────────────────────

  /// Show a local notification immediately.
  ///
  /// [id] Unique notification ID (used for cancellation).
  /// [title] Notification title.
  /// [body] Notification body text.
  /// [payload] Optional deeplink URI passed to tap handler.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationShown,
      properties: {
        AnalyticsParams.notificationId: id.toString(),
        AnalyticsParams.notificationTitle: title,
        AnalyticsParams.notificationBody: body,
        AnalyticsParams.notificationType: 'local',
      },
    );
  }

  /// Schedule a notification at a specific time.
  ///
  /// Uses `flutter_local_notifications` zonedSchedule for accuracy.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzScheduledAt = tz.TZDateTime.from(scheduledAt, tz.local);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledAt,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationScheduled,
      properties: {
        AnalyticsParams.notificationId: id.toString(),
        AnalyticsParams.notificationTitle: title,
        AnalyticsParams.notificationBody: body,
        AnalyticsParams.notificationType: 'scheduled',
        'scheduled_at': scheduledAt.toIso8601String(),
      },
    );

    debugPrint('NotificationService: Scheduled notification $id at $scheduledAt');
  }

  /// Schedule a recurring notification using a repeat interval.
  Future<void> scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required RepeatInterval interval,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.periodicallyShow(
      id,
      title,
      body,
      interval,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationScheduled,
      properties: {
        AnalyticsParams.notificationId: id.toString(),
        AnalyticsParams.notificationTitle: title,
        AnalyticsParams.notificationType: 'recurring',
        'interval': interval.name,
      },
    );

    debugPrint('NotificationService: Scheduled recurring notification $id with interval ${interval.name}');
  }

  /// Cancel a specific notification by ID.
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationCancelled,
      properties: {
        AnalyticsParams.notificationId: id.toString(),
      },
    );

    debugPrint('NotificationService: Cancelled notification $id');
  }

  /// Cancel all notifications.
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();

    AnalyticsService().trackEvent(
      AnalyticsEvents.notificationCancelled,
      properties: {
        AnalyticsParams.notificationId: 'all',
      },
    );

    debugPrint('NotificationService: Cancelled all notifications');
  }
}
