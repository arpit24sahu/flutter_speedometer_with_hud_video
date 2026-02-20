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
  static const String appInitialized = 'app_initialized';

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String pageViewed = 'page_viewed';
  static const String buttonClicked = 'button_clicked';
  static const String lifecycleState = 'lifecycle_state';
  static const String tabPress = 'tab_press';

  // ─────────────────────────────────────────────────────────────────────────
  // Feature Events
  // ─────────────────────────────────────────────────────────────────────────

  static const String onboardingCompleted = 'onboarding_completed';
  static const String recordingStarted = 'recording_started';
  static const String recordingStopped = 'recording_stopped';
  static const String recordingError = 'recording_error';
  static const String recordingSaved = 'recording_saved';
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
  static const String ffmpegProcessingStarted = 'ffmpeg_processing_started';
  static const String ffmpegCommandResult = 'ffmpeg_command_result';
  static const String ffmpegProcessingFinished = 'ffmpeg_processing_finished';
  static const String ffmpegProcessingFailed = 'ffmpeg_processing_failed';

  // ─────────────────────────────────────────────────────────────────────────
  // Premium Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String premiumPurchased = 'premium_purchased';
  static const String premiumRestored = 'premium_restored';
  static const String premiumScreenViewed = 'premium_screen_viewed';
  static const String premiumDialogViewed = 'premium_dialog_viewed';
  static const String premiumDialogDismissed = 'premium_dialog_dismissed';
  static const String premiumUpgradeButtonClicked =
      'premium_upgrade_button_clicked';
  static const String premiumRestoreClicked = 'premium_restore_clicked';
  static const String premiumUpgradePageViewed = 'premium_upgrade_page_viewed';
  static const String premiumUpgradePageClosed = 'premium_upgrade_page_closed';

  // ─────────────────────────────────────────────────────────────────────────
  // Notification Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String notificationShown = 'notification_shown';
  static const String notificationOpened = 'notification_opened';
  static const String notificationDismissed = 'notification_dismissed';
  static const String notificationScheduled = 'notification_scheduled';
  static const String notificationCancelled = 'notification_cancelled';
  static const String notificationPermissionRequested = 'notification_permission_requested';
  static const String notificationPermissionGranted = 'notification_permission_granted';
  static const String notificationPermissionDenied = 'notification_permission_denied';
  static const String fcmTokenRefreshed = 'fcm_token_refreshed';

  // ─────────────────────────────────────────────────────────────────────────
  // Deeplink Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String deeplinkReceived = 'deeplink_received';
  static const String deeplinkHandled = 'deeplink_handled';

  // ─────────────────────────────────────────────────────────────────────────
  // App Update Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String appUpdateCheckPerformed = 'app_update_check_performed';
  static const String appUpdatePromptShown = 'app_update_prompt_shown';
  static const String appUpdateAccepted = 'app_update_accepted';
  static const String appUpdateDismissed = 'app_update_dismissed';

  // ─────────────────────────────────────────────────────────────────────────
  // Error Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String errorOccurred = 'error_occurred';
  static const String flutterFatalError = 'FLUTTER_FATAL_ERROR';
  static const String fatalErrorOccurred = 'FATAL_ERROR_OCCURRED';

  // ─────────────────────────────────────────────────────────────────────────
  // App Exit Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String closeAppDialogOpened = 'close_app_dialog_opened';
  static const String closeAppYesSelected = 'close_app_yes_selected';
  static const String closeAppNoSelected = 'close_app_no_selected';
  static const String closeAppDialogDismissed = 'close_app_dialog_dismissed';
  // ─────────────────────────────────────────────────────────────────────────
  // Badge Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String badgeUnlocked = 'badge_unlocked';
  static const String badgeDetailsScreenView = 'badge_details_screen_view';
  static const String badgeDetailsScreenDismissed =
      'badge_details_screen_dismissed';
  static const String badgeUnlockedDialogDismissed =
      'badge_unlocked_dialog_dismissed';

  // ─────────────────────────────────────────────────────────────────────────
  // Tutorial Events
  // ─────────────────────────────────────────────────────────────────────────
  static const String homeTutorialStarted = 'home_tutorial_started';
  static const String recordedTutorialStarted =
      'recorded_tutorial_started'; // Camera/Record tab
  static const String labsTutorialStarted = 'labs_tutorial_started';
  static const String tutorialNextPressed = 'tutorial_next_pressed';
  static const String tutorialSkipPressed = 'tutorial_skip_pressed';
  static const String welcomeTutorialShown = 'welcome_tutorial_shown';
  static const String welcomeTutorialDismissed = 'welcome_tutorial_dismissed';
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
  static const String debugMode = 'debug_mode';
  static const String androidModel = 'android_model';
  static const String androidBrand = 'android_brand';
  static const String androidManufacturer = 'android_manufacturer';
  static const String androidVersion = 'android_version';
  static const String currentTabIndex = 'current_tab_index';
  static const String currentTabName = 'current_tab_name';
  static const String previousTabIndex = 'previous_tab_index';
  static const String previousTabName = 'previous_tab_name';
  static const String reason = 'reason';

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
  static const String lifecycleState = 'lifecycle_state';

  // ─────────────────────────────────────────────────────────────────────────
  // Notification Parameters
  // ─────────────────────────────────────────────────────────────────────────
  static const String notificationId = 'notification_id';
  static const String notificationTitle = 'notification_title';
  static const String notificationBody = 'notification_body';
  static const String notificationType = 'notification_type';

  // ─────────────────────────────────────────────────────────────────────────
  // Deeplink Parameters
  // ─────────────────────────────────────────────────────────────────────────
  static const String deeplinkUri = 'deeplink_uri';
  static const String deeplinkRoute = 'deeplink_route';

  // ─────────────────────────────────────────────────────────────────────────
  // Misc Parameters
  // ─────────────────────────────────────────────────────────────────────────
  static const String source = 'source';

  // ─────────────────────────────────────────────────────────────────────────
  // Badge Parameters
  // ─────────────────────────────────────────────────────────────────────────
  static const String badgeId = 'badge_id';
  static const String badgeName = 'badge_name';
  static const String badgeDescription = 'badge_description';
  static const String badgeTier = 'badge_tier';
  static const String badgeLevel = 'badge_level';
  static const String badgeIsUnlocked = 'badge_is_unlocked';
  static const String durationSeconds = 'duration_seconds';
}

