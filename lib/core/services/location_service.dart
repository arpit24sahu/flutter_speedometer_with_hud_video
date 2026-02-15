import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../../features/speedometer/models/position_data.dart';

class LocationService {
  LocationService._internal();
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  // ─────────────────────────────────────────────
  // Existing functionality (UNCHANGED)
  // ─────────────────────────────────────────────

  bool enableMockSpeed = true;
  final _random = Random();

  Future<bool> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    );
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print("Error occured: ${e.toString()}");
      return null;
    }
  }

  double calculateSpeed(Position position) {
    return position.speed; // m/s
  }

  // ─────────────────────────────────────────────
  // Speed tracking (ADDED)
  // ─────────────────────────────────────────────

  bool isTrackingSpeed = false;

  /// key = elapsed ms since tracking started
  /// value = Position snapshot
  final Map<int, PositionData> trackedPositionData = {};

  StreamSubscription<Position>? _positionSubscription;
  Timer? _samplingTimer;
  Stopwatch? _stopwatch;
  Position? _latestPosition;

  Future<bool> startSpeedTracking() async {
    if (isTrackingSpeed) return true;

    final hasPermission =
        await checkPermission() || await requestPermission();
    if (!hasPermission) return false;

    trackedPositionData.clear();
    _stopwatch = Stopwatch()..start();
    isTrackingSpeed = true;

    _positionSubscription = getPositionStream().listen(
          (position) {
        _latestPosition = position;
      },
    );

    _samplingTimer = Timer.periodic(
      const Duration(milliseconds: 500),
          (_) {
        if (_latestPosition == null || _stopwatch == null) return;
        final elapsedMs = _stopwatch!.elapsedMilliseconds;

        // trackedPositionData[elapsedMs] = PositionData.fromGeolocator(_latestPosition!);
        final realData = PositionData.fromGeolocator(_latestPosition!);
        trackedPositionData[elapsedMs] = enableMockSpeed
            ? realData.copyWith(speed: 10 + _random.nextDouble() * 190)
            : realData;
      },
    );

    return true;
  }

  Map<int, PositionData> stopSpeedTracking() {
    if (!isTrackingSpeed) return trackedPositionData;

    _samplingTimer?.cancel();
    _samplingTimer = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;

    _stopwatch?.stop();
    _stopwatch = null;

    isTrackingSpeed = false;

    return trackedPositionData; // Map<int, Position>.from(trackedPositionData);
  }

  void disposeTracking() {
    _samplingTimer?.cancel();
    _positionSubscription?.cancel();
    _stopwatch = null;
    isTrackingSpeed = false;
  }
}