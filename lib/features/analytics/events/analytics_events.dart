/// Analytics event names and parameter keys used throughout the app.
/// 
/// Usage:
/// ```dart
/// AnalyticsService.trackEvent(AnalyticsEvents.buttonClicked, {
///   AnalyticsParams.buttonName: 'start_recording',
/// });
/// ```
class AnalyticsEvents {
  AnalyticsEvents._(); // Private constructor to prevent instantiation

  // ─────────────────────────────────────────────────────────────────────────
  // App Lifecycle Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String appOpened = 'app_opened';
  static const String appClosed = 'app_closed';
  static const String appBackgrounded = 'app_backgrounded';
  static const String appResumed = 'app_resumed';

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String pageViewed = 'page_viewed';
  static const String buttonClicked = 'button_clicked';
  static const String tabPress = 'tab_press';

  // ─────────────────────────────────────────────────────────────────────────
  // Feature Events
  // ─────────────────────────────────────────────────────────────────────────

  static const String onboardingCompleted = 'onboarding_completed';
  static const String recordingStarted = 'recording_started';
  static const String recordingStopped = 'recording_stopped';
  static const String speedometerViewed = 'speedometer_viewed';
  static const String settingsChanged = 'settings_changed';
  static const String permissionCheckAgainPress = 'permission_check_again_press';
  static const String flipCamera = 'flip_camera';
  static const String recordButtonPressedWhileProcessing = 'record_button_pressed_while_processing';
  static const String playRecordedVideo = 'play_recorded_video';
  static const String shareRecordedVideo = 'share_recorded_video';
  static const String filesLoaded = 'files_loaded';
  static const String gaugePlacementPicked = 'gauge_placement_picked';
  static const String toggleGaugeVisibility = 'toggle_gauge_visibility';
  static const String toggleTextVisibility = 'toggle_text_visibility';
  static const String toggleMaxSpeedVisibility = 'toggle_max_speed_visibility';
  static const String toggleLabelVisibility = 'toggle_label_visibility';
  static const String gaugePlacementPickupCancelled = 'gauge_placement_pickup_cancelled';


  // ─────────────────────────────────────────────────────────────────────────
  // Premium Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String premiumPurchased = 'premium_purchased';
  static const String premiumRestored = 'premium_restored';
  static const String premiumScreenViewed = 'premium_screen_viewed';

  // ─────────────────────────────────────────────────────────────────────────
  // Error Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String errorOccurred = 'error_occurred';
}

/// Common parameter keys for analytics events.
class AnalyticsParams {
  AnalyticsParams._(); // Private constructor to prevent instantiation

  // ─────────────────────────────────────────────────────────────────────────
  // Common Parameters (auto-added by AnalyticsService)
  // ─────────────────────────────────────────────────────────────────────────
  static const String userId = 'user_id';
  static const String deviceId = 'device_id';
  static const String platform = 'platform';
  static const String osVersion = 'os_version';
  static const String appVersion = 'app_version';
  static const String buildNumber = 'build_number';
  static const String timestamp = 'timestamp';
  static const String androidModel = 'android_model';
  static const String androidBrand = 'android_brand';
  static const String androidManufacturer = 'android_manufacturer';
  static const String androidVersion = 'android_version';

  // ─────────────────────────────────────────────────────────────────────────
  // Event-Specific Parameters
  // ─────────────────────────────────────────────────────────────────────────
  static const String pageName = 'page_name';
  static const String buttonName = 'button_name';
  static const String settingName = 'setting_name';
  static const String settingValue = 'setting_value';
  static const String errorMessage = 'error_message';
  static const String errorType = 'error_type';
  static const String duration = 'duration';
  static const String success = 'success';
}
