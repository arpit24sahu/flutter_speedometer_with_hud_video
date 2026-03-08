import 'dart:async';
import 'package:geolocator/geolocator.dart';

class DedicatedSpeedometerService {
  Future<bool> requestPermissionIfNotGranted() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Stream<double> getSpeedStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).map((Position position) {
      return position.speed; // meters per second
    });
  }
}
