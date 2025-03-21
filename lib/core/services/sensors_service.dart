import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';

abstract class SensorsService {
  Stream<CompassEvent>? getCompassStream();
  Future<double?> getCurrentHeading();
}

class SensorsServiceImpl implements SensorsService {
  @override
  Stream<CompassEvent>? getCompassStream() {
    return FlutterCompass.events; //?? Stream.empty();
  }

  @override
  Future<double?> getCurrentHeading() async {
    final CompassEvent? compassEvent = await FlutterCompass.events?.first;
    return compassEvent?.heading;
  }
}