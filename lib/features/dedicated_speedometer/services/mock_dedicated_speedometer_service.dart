import 'dart:async';
import 'dart:math';

class MockDedicatedSpeedometerService {
  Future<bool> requestPermissionIfNotGranted() async {
    return true; // Always return true for mock
  }

  Stream<double> getSpeedStream() async* {
    double currentSpeed = 0.0;
    bool accelerating = true;
    final random = Random();

    while (true) {
      await Future.delayed(const Duration(milliseconds: 1000));

      if (accelerating) {
        currentSpeed += random.nextDouble() * 5 + 2; // Accelerate by 2 to 7 m/s
        if (currentSpeed > 75) { // Up to ~270 km/h
          accelerating = false;
        }
      } else {
        currentSpeed -= random.nextDouble() * 4 + 1; // Decelerate by 1 to 5 m/s
        if (currentSpeed < 5) {
          accelerating = true;
        }
      }

      // Add a little noise
      double noise = (random.nextDouble() - 0.5) * 1.5;
      double finalSpeed = currentSpeed + noise;
      if (finalSpeed < 0) finalSpeed = 0;

      yield finalSpeed;
    }
  }
}
