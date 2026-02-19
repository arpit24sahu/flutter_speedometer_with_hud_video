import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/core/services/sensors_service.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_bloc.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_event.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_state.dart';

class MockLocationService extends Mock implements LocationService {}

class MockSensorsService extends Mock implements SensorsService {}

class FakePosition extends Fake implements Position {
  @override
  final double speed;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final DateTime timestamp;

  FakePosition({
    required this.speed,
    this.latitude = 0,
    this.longitude = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

void main() {
  group('SpeedometerBloc', () {
    late SpeedometerBloc speedometerBloc;
    late MockLocationService mockLocationService;
    late MockSensorsService mockSensorsService;

    setUp(() {
      mockLocationService = MockLocationService();
      mockSensorsService = MockSensorsService();
      speedometerBloc = SpeedometerBloc(
        locationService: mockLocationService,
        sensorsService: mockSensorsService,
      );
    });

    tearDown(() {
      speedometerBloc.close();
    });

    test('initial state is SpeedometerState.initial()', () {
      expect(speedometerBloc.state, SpeedometerState.initial());
    });

    test('emits [isTracking: true] when StartSpeedTracking is added and permission granted',
        () async {
      when(() => mockLocationService.checkPermission())
          .thenAnswer((_) async => true);
      when(() => mockLocationService.getPositionStream())
          .thenAnswer((_) => Stream.empty());

      speedometerBloc.add(StartSpeedTracking());

      await expectLater(
        speedometerBloc.stream,
        emitsInOrder([
          predicate<SpeedometerState>((state) =>
              state.isTracking == true && state.error == null),
        ]),
      );

      verify(() => mockLocationService.checkPermission()).called(1);
      verify(() => mockLocationService.getPositionStream()).called(1);
    });

    test('emits error when StartSpeedTracking is added and permission denied',
        () async {
      when(() => mockLocationService.checkPermission())
          .thenAnswer((_) async => false);
      when(() => mockLocationService.requestPermission())
          .thenAnswer((_) async => false);

      speedometerBloc.add(StartSpeedTracking());

      await expectLater(
        speedometerBloc.stream,
        emitsInOrder([
          predicate<SpeedometerState>(
              (state) => state.error == 'Location permission denied'),
        ]),
      );

      verify(() => mockLocationService.checkPermission()).called(1);
      verify(() => mockLocationService.requestPermission()).called(1);
    });

    test('emits speed updates when position stream emits new position', () async {
      final positionController = StreamController<Position>();
      when(() => mockLocationService.checkPermission())
          .thenAnswer((_) async => true);
      when(() => mockLocationService.getPositionStream())
          .thenAnswer((_) => positionController.stream);

      speedometerBloc.add(StartSpeedTracking());
      
      // Wait for tracking to start
      await expectLater(
        speedometerBloc.stream,
        emits(predicate<SpeedometerState>((state) => state.isTracking == true)),
      );

      // Add position data
      // 10 m/s = 36 km/h
      positionController.add(FakePosition(speed: 10));

      await expectLater(
        speedometerBloc.stream,
        emits(predicate<SpeedometerState>((state) {
          return state.speedKmh == 36.0 && state.maxSpeedKmh == 36.0;
        })),
      );

      // 20 m/s = 72 km/h
      positionController.add(FakePosition(speed: 20));

      await expectLater(
        speedometerBloc.stream,
        emits(predicate<SpeedometerState>((state) {
          return state.speedKmh == 72.0 && state.maxSpeedKmh == 72.0;
        })),
      );

      positionController.close();
    });

    test('resets trip data when ResetTrip is added', () async {
       // Setup initial state with some data (indirectly via event or mocking state if possible, 
       // but BLoC standard is to emit new state based on event).
       // Here we just test that it emits cleared state.
       
       speedometerBloc.add(ResetTrip());
       
       await expectLater(
        speedometerBloc.stream,
        emits(predicate<SpeedometerState>((state) {
          return state.maxSpeedKmh == 0 && state.distanceKm == 0;
        })),
      );
    });
  });
}
