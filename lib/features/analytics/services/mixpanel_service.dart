import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// Service responsible for communicating with Mixpanel analytics.
///
/// This service should not be used directly. Use [AnalyticsService] instead
/// which adds common parameters and orchestrates all analytics services.
class MixpanelService {
  MixpanelService._();

  static final MixpanelService _instance = MixpanelService._();
  static MixpanelService get instance => _instance;

  Mixpanel? _mixpanel;
  bool _isInitialized = false;

  /// Whether the service has been successfully initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes Mixpanel with the token from environment variables.
  ///
  /// Should only be called once during app initialization via [AnalyticsService].
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('MixpanelService: Already initialized');
      return;
    }

    try {
      final token = dotenv.maybeGet('MIXPANEL_TOKEN');

      if (token == null || token.isEmpty) {
        debugPrint('MixpanelService: No MIXPANEL_TOKEN found in .env');
        return;
      }

      _mixpanel = await Mixpanel.init(
        token,
        trackAutomaticEvents: true,
      );

      _isInitialized = true;
      debugPrint('MixpanelService: Initialized successfully');
    } catch (e) {
      debugPrint('MixpanelService: Failed to initialize - $e');
      _isInitialized = false;
    }
  }

  /// Tracks an event with the given name and properties.
  ///
  /// [eventName] The name of the event to track.
  /// [properties] Optional properties to attach to the event.
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    if (!_isInitialized || _mixpanel == null) {
      debugPrint('MixpanelService: Not initialized, skipping event: $eventName');
      return;
    }

    try {
      _mixpanel!.track(eventName, properties: properties);
      debugPrint('MixpanelService: Tracked event "$eventName"');
    } catch (e) {
      debugPrint('MixpanelService: Failed to track event - $e');
    }
  }

  /// Sets the user ID for user identification across events.
  ///
  /// [userId] The unique identifier for the user.
  void identify(String userId) {
    if (!_isInitialized || _mixpanel == null) {
      debugPrint('MixpanelService: Not initialized, skipping identify');
      return;
    }

    try {
      _mixpanel!.identify(userId);
      debugPrint('MixpanelService: Identified user "$userId"');
    } catch (e) {
      debugPrint('MixpanelService: Failed to identify user - $e');
    }
  }

  /// Sets a user profile property.
  ///
  /// [propertyName] The name of the property.
  /// [value] The value of the property.
  void setUserProperty(String propertyName, dynamic value) {
    if (!_isInitialized || _mixpanel == null) {
      debugPrint('MixpanelService: Not initialized, skipping setUserProperty');
      return;
    }

    try {
      _mixpanel!.getPeople().set(propertyName, value);
      debugPrint('MixpanelService: Set user property "$propertyName"');
    } catch (e) {
      debugPrint('MixpanelService: Failed to set user property - $e');
    }
  }

  /// Resets the current user identity.
  ///
  /// Should be called when a user logs out.
  void reset() {
    if (!_isInitialized || _mixpanel == null) {
      debugPrint('MixpanelService: Not initialized, skipping reset');
      return;
    }

    try {
      _mixpanel!.reset();
      debugPrint('MixpanelService: Reset user identity');
    } catch (e) {
      debugPrint('MixpanelService: Failed to reset - $e');
    }
  }

  /// Flushes any queued events to the Mixpanel server.
  void flush() {
    if (!_isInitialized || _mixpanel == null) {
      return;
    }

    try {
      _mixpanel!.flush();
    } catch (e) {
      debugPrint('MixpanelService: Failed to flush - $e');
    }
  }
}
