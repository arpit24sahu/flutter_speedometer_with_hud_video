import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/mixpanel_service.dart';

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
