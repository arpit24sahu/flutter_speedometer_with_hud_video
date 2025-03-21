import 'dart:async';
import 'package:geolocator/geolocator.dart';

abstract class LocationService {
  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Stream<Position> getPositionStream();
  Future<Position?> getCurrentPosition();
  double calculateSpeed(Position position);
}

class LocationServiceImpl implements LocationService {
  @override
  Future<bool> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  @override
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
  }

  @override
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  double calculateSpeed(Position position) {
    // Speed is already provided in m/s by the Position object
    return position.speed;
  }
}