import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';

/// Singleton service for handling app-level deeplinks.
///
/// Routes `turbogauge://` scheme URIs to the appropriate screens/dialogs.
/// Used primarily by [NotificationService] when a notification is tapped.
///
/// Navigation uses a global [navigatorKey] that must be assigned to the
/// app's MaterialApp/GetMaterialApp `navigatorKey` property.
class DeeplinkService {
  DeeplinkService._internal();
  static final DeeplinkService _instance = DeeplinkService._internal();
  factory DeeplinkService() => _instance;

  /// Global navigator key — assign this to your MaterialApp.navigatorKey.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Queue deeplinks received before the navigator is ready.
  String? _pendingDeeplink;

  /// Process any pending deeplinks (call after navigator is available).
  void processPendingDeeplinks() {
    if (_pendingDeeplink != null) {
      handleDeeplink(_pendingDeeplink!);
      _pendingDeeplink = null;
    }
  }

  /// Handle a deeplink URI string.
  ///
  /// Supported routes:
  /// - `turbogauge://premium_upgrade_page` — Opens premium upgrade bottom sheet
  /// - `turbogauge://home` — Pops to home
  void handleDeeplink(String uri) {
    debugPrint('DeeplinkService: Handling deeplink: $uri');

    AnalyticsService().trackEvent(
      AnalyticsEvents.deeplinkReceived,
      properties: {
        AnalyticsParams.deeplinkUri: uri,
      },
    );

    final parsedUri = Uri.tryParse(uri);
    if (parsedUri == null || parsedUri.scheme != 'turbogauge') {
      debugPrint('DeeplinkService: Invalid or unsupported deeplink: $uri');
      return;
    }

    final route = parsedUri.host;

    // Check if navigator is available
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('DeeplinkService: Navigator not available, queuing deeplink');
      _pendingDeeplink = uri;
      return;
    }

    switch (route) {
      case 'premium_upgrade_page':
        _openPremiumUpgrade(navigator);
        break;

      case 'home':
        navigator.popUntil((route) => route.isFirst);
        break;

      default:
        debugPrint('DeeplinkService: Unknown route: $route');
        break;
    }

    AnalyticsService().trackEvent(
      AnalyticsEvents.deeplinkHandled,
      properties: {
        AnalyticsParams.deeplinkUri: uri,
        AnalyticsParams.deeplinkRoute: route,
      },
    );
  }

  void _openPremiumUpgrade(NavigatorState navigator) {
    // Use the navigator's context to show the premium dialog
    final context = navigator.context;
    PremiumUpgradeDialog.show(context, source: 'deeplink');
  }
}
