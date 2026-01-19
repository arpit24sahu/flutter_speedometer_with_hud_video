import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class UserIdService {
  // Private constructor
  UserIdService._internal();

  // Singleton instance
  static final UserIdService _instance = UserIdService._internal();

  // Factory constructor
  factory UserIdService() => _instance;

  static const String _userIdKey = 'user_id';
  static const Uuid _uuid = Uuid();

  String? _cachedUserId;

  /// Returns a persistent userId.
  ///
  /// - Uses in-memory cache if available
  /// - Else loads from SharedPreferences
  /// - Else generates, saves, caches, and returns a new one
  Future<String> getUserId() async {
    // 1️⃣ In-memory cache
    if (_cachedUserId != null) {
      return _cachedUserId!;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 2️⃣ Persistent storage
    final String? storedUserId = prefs.getString(_userIdKey);
    if (storedUserId != null && storedUserId.isNotEmpty) {
      _cachedUserId = storedUserId;
      return storedUserId;
    }

    // 3️⃣ Generate new userId
    final String newUserId = _uuid.v4();
    await prefs.setString(_userIdKey, newUserId);

    _cachedUserId = newUserId;
    return newUserId;
  }

  /// Optional: Clear userId (useful for logout or reset)
  Future<void> resetUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    _cachedUserId = null;
  }
}

class PackageInfoService {
  PackageInfoService._internal();
  static final PackageInfoService _instance = PackageInfoService._internal();
  factory PackageInfoService() => _instance;

  late final PackageInfo _packageInfo;
  bool _initialized = false;

  /// Call once during app startup
  Future<void> init() async {
    if (_initialized) return;
    _packageInfo = await PackageInfo.fromPlatform();
    _initialized = true;
  }

  /// Synchronous getters (safe after init)
  String get appName => _packageInfo.appName;
  String get packageName => _packageInfo.packageName;
  String get version => _packageInfo.version;
  String get buildNumber => _packageInfo.buildNumber;
}

class DeviceInfoService {
  DeviceInfoService._internal();
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo? _androidInfo;
  IosDeviceInfo? _iosInfo;
  bool _initialized = false;

  /// Call once during app startup
  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      _androidInfo = await _deviceInfo.androidInfo;
    } else if (Platform.isIOS) {
      _iosInfo = await _deviceInfo.iosInfo;
    }

    _initialized = true;
  }

  /// Common getters
  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;

  /// Android getters
  String? get androidModel => _androidInfo?.model;
  String? get androidBrand => _androidInfo?.brand;
  String? get androidManufacturer => _androidInfo?.manufacturer;
  int? get androidSdkInt => _androidInfo?.version.sdkInt;
  String? get androidVersion => _androidInfo?.version.release;
  String? get androidDevice => _androidInfo?.device;
  String? get androidId => _androidInfo?.id;

  /// iOS getters
  String? get iosModel => _iosInfo?.model;
  String? get iosName => _iosInfo?.name;
  String? get iosSystemName => _iosInfo?.systemName;
  String? get iosSystemVersion => _iosInfo?.systemVersion;
  String? get iosIdentifierForVendor => _iosInfo?.identifierForVendor;
}