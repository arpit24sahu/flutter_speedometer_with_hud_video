import 'package:shared_preferences/shared_preferences.dart';

/// Instance-based preferences for dashcam settings.
/// Injected via DI for testability (no static methods).
class DashcamPreferences {
  final SharedPreferences _prefs;

  DashcamPreferences(this._prefs);

  // Keys
  static const _keyLoopInterval = 'dashcam_loop_interval';
  static const _keyEnableMic = 'dashcam_enable_mic';
  static const _keyEnableGps = 'dashcam_enable_gps';
  static const _keyStorageLimit = 'dashcam_storage_limit';
  static const _keyVideoQuality = 'dashcam_video_quality';
  static const _keyFrameRate = 'dashcam_frame_rate';
  static const _keySpeedLimit = 'dashcam_speed_limit';
  static const _keyEnableGShock = 'dashcam_enable_gshock';

  int get segmentDurationSeconds => _prefs.getInt(_keyLoopInterval) ?? 120; // 2 minutes
  set segmentDurationSeconds(int value) => _prefs.setInt(_keyLoopInterval, value);

  bool get enableMic => _prefs.getBool(_keyEnableMic) ?? true;
  set enableMic(bool value) => _prefs.setBool(_keyEnableMic, value);

  bool get enableGps => _prefs.getBool(_keyEnableGps) ?? true;
  set enableGps(bool value) => _prefs.setBool(_keyEnableGps, value);

  bool get enableGShock => _prefs.getBool(_keyEnableGShock) ?? true;
  set enableGShock(bool value) => _prefs.setBool(_keyEnableGShock, value);

  int get storageLimitGb => _prefs.getInt(_keyStorageLimit) ?? 20; // 20 GB
  set storageLimitGb(int value) => _prefs.setInt(_keyStorageLimit, value);

  String get speedUnit => _prefs.getString('dashcam_speed_unit') ?? 'km/h';
  set speedUnit(String value) => _prefs.setString('dashcam_speed_unit', value);

  String get videoQuality => _prefs.getString(_keyVideoQuality) ?? '1080p';
  set videoQuality(String value) => _prefs.setString(_keyVideoQuality, value);

  int get frameRate => _prefs.getInt(_keyFrameRate) ?? 60; // 60 fps default
  set frameRate(int value) => _prefs.setInt(_keyFrameRate, value);

  int get speedLimit => _prefs.getInt(_keySpeedLimit) ?? 60; // 60
  set speedLimit(int value) => _prefs.setInt(_keySpeedLimit, value);
}
