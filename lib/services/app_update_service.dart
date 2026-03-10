import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/services/deeplink_service.dart';
import 'package:speedometer/services/misc_service.dart';
import 'remote_config_service.dart'; // Import the new service

class AppUpdateService {
  AppUpdateService._internal();
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;

  final RemoteConfigService _remoteConfigService = RemoteConfigService();

  Future<void> checkForUpdate() async {
    if (!_remoteConfigService.isInitialized) {
      await _remoteConfigService.initialize();
    }

    try {
      // Refresh remote config
      await _remoteConfigService.forceFetch();

      final int localBuild = int.tryParse(PackageInfoService().buildNumber) ?? 0;
      final int latestBuild = _remoteConfigService.getInt(RemoteConfigService.keyLatestBuild);
      final int lastSupportedBuild = _remoteConfigService.getInt(RemoteConfigService.keyLastSupportedBuild);
      final String latestVersion = _remoteConfigService.getString(RemoteConfigService.keyLatestVersion);

      AnalyticsService().trackEvent(
        AnalyticsEvents.appUpdateCheckPerformed,
        properties: {
          'local_build': localBuild,
          'latest_build': latestBuild,
          'last_supported_build': lastSupportedBuild,
          'latest_version': latestVersion,
        },
      );

      debugPrint(
          'AppUpdateService: local=$localBuild, latest=$latestBuild, minSupported=$lastSupportedBuild');

      if (localBuild < lastSupportedBuild) {
        // Force update — app version is no longer supported
        _showUpdateDialog(
          isForceUpdate: true,
          latestVersion: latestVersion,
        );
      } else if (localBuild < latestBuild) {
        // Optional update — newer version available
        _showUpdateDialog(
          isForceUpdate: false,
          latestVersion: latestVersion,
        );
      }
    } catch (e) {
      debugPrint('AppUpdateService: Error checking for update - $e');
    }
  }

  void _showUpdateDialog({
    required bool isForceUpdate,
    required String latestVersion,
  }) {
    final navigator = DeeplinkService.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('AppUpdateService: Navigator not available for update dialog');
      return;
    }

    final context = navigator.context;

    AnalyticsService().trackEvent(
      AnalyticsEvents.appUpdatePromptShown,
      properties: {
        'is_force_update': isForceUpdate,
        'latest_version': latestVersion,
      },
    );

    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Icon(
                isForceUpdate ? Icons.warning_amber_rounded : Icons.system_update,
                color: isForceUpdate ? Colors.orange : Colors.amber,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                isForceUpdate ? 'Update Required' : 'Update Available',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isForceUpdate
                    ? 'Your version of TurboGauge is no longer supported. Please update to version $latestVersion to continue using the app.'
                    : 'A new version ($latestVersion) of TurboGauge is available with exciting new features and improvements!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (isForceUpdate)
                Text(
                  'This update is required for security and stability.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.9),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  AnalyticsService().trackEvent(
                    AnalyticsEvents.appUpdateDismissed,
                    properties: {'latest_version': latestVersion},
                  );
                },
                child: Text(
                  'Later',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () => _openStore(),
              icon: const Icon(Icons.download, color: Colors.black),
              label: const Text(
                'Update Now',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    AnalyticsService().trackEvent(AnalyticsEvents.appUpdateAccepted);

    final String packageName = PackageInfoService().packageName;
    Uri storeUri;

    if (Platform.isAndroid) {
      storeUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    } else if (Platform.isIOS) {
      // Replace with your actual App Store ID
      storeUri = Uri.parse('https://apps.apple.com/app/id$packageName');
    } else {
      return;
    }

    if (await canLaunchUrl(storeUri)) {
      await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    }
  }
}