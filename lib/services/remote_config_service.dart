import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:speedometer/services/misc_service.dart';

class RemoteConfigService {
  RemoteConfigService._internal();
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  // Remote Config keys
  static const String keyLatestVersion = 'latest_app_version';
  static const String keyLatestBuild = 'latest_build_number';
  static const String keyLastSupportedBuild = 'last_supported_build_number';
  static const String keyLastSupportedVersion = 'last_supported_app_version';
  static const String keyHomepageLayout = 'homepage_layout';

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 1)
            : const Duration(hours: 12),
      ));

      await _remoteConfig.setDefaults({
        keyLatestVersion: PackageInfoService().version,
        keyLatestBuild: int.tryParse(PackageInfoService().buildNumber) ?? 0,
        keyLastSupportedBuild: 0,
        keyLastSupportedVersion: '0.0.0',
        keyHomepageLayout: 'buttons'
      });

      await _remoteConfig.fetchAndActivate();
      _initialized = true;
      debugPrint('RemoteConfigService: Initialized successfully');
    } catch (e) {
      debugPrint('RemoteConfigService: Failed to initialize - $e');
    }
  }

  Future<void> forceFetch() async {
    await _remoteConfig.fetchAndActivate();
  }

  String getString(String key) => _remoteConfig.getString(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  bool get isInitialized => _initialized;
}