import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/firebase_analytics_service.dart';
import 'package:speedometer/features/analytics/services/mixpanel_service.dart';
import 'package:speedometer/presentation/screens/home_screen.dart';
import 'package:speedometer/services/misc_service.dart';

/// Central analytics service that orchestrates all analytics providers.
///
/// This is the main entry point for tracking events in the app.
/// All convenience methods (`trackPageView`, `trackButtonClick`, etc.)
/// delegate to [trackEvent] which adds common parameters and forwards
/// to all configured analytics services.
///
/// Usage:
/// ```dart
/// await AnalyticsService.instance.initialize();
/// AnalyticsService.instance.trackButtonClick('start_recording');
/// AnalyticsService.instance.trackPageView('settings_page');
/// ```
class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() => _instance;


  final MixpanelService _mixpanelService = MixpanelService.instance;

  final FirebaseAnalyticsService _firebaseAnalyticsService = FirebaseAnalyticsService();

  bool _isInitialized = false;
  bool printLogs = kDebugMode;

  // Common parameters that will be added to every event
  String? _userId;
  String? _deviceId;

  /// Whether the service has been successfully initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes all analytics services.
  ///
  /// Should be called once during app startup, typically in the
  /// dependency injection setup or main function.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('AnalyticsService: Already initialized');
      return;
    }

    try {
      // Initialize underlying services
      await _mixpanelService.initialize();
      String userId = await UserIdService().getUserId();
      setUserId(userId);

      _isInitialized = true;
      debugPrint('AnalyticsService: Initialized successfully');
    } catch (e) {
      debugPrint('AnalyticsService: Failed to initialize - $e');
    }
  }

  void kPrint(dynamic value){
    if(printLogs) return;
    print(value.toString());
  }

  /// Sets the user ID for identification across all analytics services.
  ///
  /// [userId] The unique identifier for the user.
  void setUserId(String userId) {
    _userId = userId;
    _mixpanelService.identify(userId);
  }

  /// Sets the device ID for identification across events.
  ///
  /// [deviceId] The unique device identifier.
  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  /// Sets a user profile property across all analytics services.
  ///
  /// [propertyName] The name of the property.
  /// [value] The value of the property.
  void setUserProperty(String propertyName, dynamic value) {
    _mixpanelService.setUserProperty(propertyName, value);
  }

  /// Tracks an event with the given name and optional properties.
  ///
  /// Common parameters (userId, deviceId, platform, timestamp) are
  /// automatically added to all events.
  ///
  /// [eventName] The name of the event (use constants from [AnalyticsEvents]).
  /// [properties] Optional additional properties for this event.
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    if (!_isInitialized) {
      debugPrint('AnalyticsService: Not initialized, skipping event: $eventName');
      return;
    }

    // Build event properties with common parameters
    final eventProperties = <String, dynamic>{
      AnalyticsParams.timestamp: DateTime.now().toIso8601String(),
      AnalyticsParams.platform: Platform.operatingSystem,
      AnalyticsParams.osVersion: Platform.operatingSystemVersion,
      AnalyticsParams.appVersion: PackageInfoService().version,
      AnalyticsParams.buildNumber: PackageInfoService().buildNumber,
      AnalyticsParams.androidModel: DeviceInfoService().androidModel,
      AnalyticsParams.androidBrand: DeviceInfoService().androidBrand,
      AnalyticsParams.androidManufacturer: DeviceInfoService().androidManufacturer,
      AnalyticsParams.androidVersion: DeviceInfoService().androidVersion,
      AnalyticsParams.currentTabIndex: AppTabState.currentTabIndex.value,
      AnalyticsParams.currentTabName: AppTabState.tabName(AppTabState.currentTabIndex.value),
      AnalyticsParams.previousTabIndex: AppTabState.previousTabIndex,
      AnalyticsParams.previousTabName: AppTabState.tabName(AppTabState.previousTabIndex),
    };

    // Add optional common parameters if set
    if (_userId != null) {
      eventProperties[AnalyticsParams.userId] = _userId;
    }
    if (_deviceId != null) {
      eventProperties[AnalyticsParams.deviceId] = _deviceId;
    }

    // Merge with provided properties (provided properties take precedence)
    if (properties != null) {
      eventProperties.addAll(properties);
    }

    kPrint("Event Tracked: ${eventName.toUpperCase()}");
    kPrint(eventProperties);

    // Send to all analytics services
    _mixpanelService.trackEvent(eventName, properties: eventProperties);
    _firebaseAnalyticsService.logEvent(eventName, eventProperties.map((k,v) => MapEntry(k,v.toString())));
  }

  /// Convenience method for tracking page view events.
  ///
  /// [pageName] The name/identifier of the page viewed.
  /// [properties] Optional additional properties for this event.
  void trackPageView(String pageName, {Map<String, dynamic>? properties}) {
    final eventProperties = <String, dynamic>{
      AnalyticsParams.pageName: pageName,
      ...?properties,
    };

    trackEvent(AnalyticsEvents.pageViewed, properties: eventProperties);
  }

  /// Convenience method for tracking button click events.
  ///
  /// [buttonName] The name/identifier of the button clicked.
  /// [properties] Optional additional properties for this event.
  void trackButtonClick(String buttonName, {Map<String, dynamic>? properties}) {
    final eventProperties = <String, dynamic>{
      AnalyticsParams.buttonName: buttonName,
      ...?properties,
    };

    trackEvent(AnalyticsEvents.buttonClicked, properties: eventProperties);
  }

  /// Convenience method for tracking error events.
  ///
  /// [errorMessage] Description of the error.
  /// [errorType] Optional classification of the error type.
  /// [properties] Optional additional properties for this event.
  void trackError(
    String errorMessage, {
    String? errorType,
    Map<String, dynamic>? properties,
  }) {
    final eventProperties = <String, dynamic>{
      AnalyticsParams.errorMessage: errorMessage,
      if (errorType != null) AnalyticsParams.errorType: errorType,
      ...?properties,
    };

    trackEvent(AnalyticsEvents.errorOccurred, properties: eventProperties);
  }


  void trackAppLifeCycle(AppLifecycleState state) {
    final eventProperties = <String, dynamic>{
      AnalyticsParams.lifecycleState: state.name,
    };

    trackEvent(AnalyticsEvents.lifecycleState, properties: eventProperties);

    if(state == AppLifecycleState.resumed) {
      trackEvent(AnalyticsEvents.appResumed, properties: eventProperties);
    } else if(state == AppLifecycleState.paused) {
      trackEvent(AnalyticsEvents.appBackgrounded, properties: eventProperties);
    }
  }


  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  /// Pass all uncaught "fatal" errors from the Flutter framework
  void recordFlutterFatalError(FlutterErrorDetails errorDetails) {
    final eventProperties = <String, dynamic>{
      AnalyticsParams.errorMessage: errorDetails.exceptionAsString(),
      AnalyticsParams.errorType: errorDetails.exception.runtimeType.toString(),
      'stackTrace': errorDetails.stack?.toString(),
      'library': errorDetails.library,
      'context': errorDetails.context?.toDescription(),
      'isFatal': true,
    };

    trackEvent(
      AnalyticsEvents.flutterFatalError,
      properties: eventProperties,
    );
  }

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  /// Pass all uncaught async / platform errors
  void recordError(dynamic exception, StackTrace? stack, {
        dynamic reason,
        Iterable<Object> information = const [],
        bool? printDetails,
        bool fatal = false,
      }) {
    final eventProperties = <String, dynamic>{
      AnalyticsParams.errorMessage: exception.toString(),
      AnalyticsParams.errorType: exception.runtimeType.toString(),
      if (stack != null) 'stackTrace': stack.toString(),
      if (reason != null) AnalyticsParams.reason: reason.toString(),
      if (information.isNotEmpty) 'information': information.map((e) => e.toString()).toList(),
      'isFatal': fatal,
      AnalyticsParams.timestamp: DateTime.now().toIso8601String(),
    };

    trackEvent(
      fatal
          ? AnalyticsEvents.fatalErrorOccurred
          : AnalyticsEvents.errorOccurred,
      properties: eventProperties,
    );
  }

  /// Resets user identity across all analytics services.
  ///
  /// Should be called when a user logs out.
  void reset() {
    _userId = null;
    _mixpanelService.reset();
  }

  /// Flushes any queued events to analytics servers.
  void flush() {
    _mixpanelService.flush();
  }
}
