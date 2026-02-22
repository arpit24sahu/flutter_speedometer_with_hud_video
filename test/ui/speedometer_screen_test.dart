import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_bloc.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_event.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_state.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_event.dart';
import 'package:speedometer/presentation/bloc/settings/settings_state.dart';
import 'package:speedometer/presentation/screens/speedometer_screen.dart';

// Mock Blocs
class MockSpeedometerBloc extends Mock implements SpeedometerBloc {}
class MockSettingsBloc extends Mock implements SettingsBloc {}

void main() {
  group('SpeedometerScreen', () {
    late MockSpeedometerBloc mockSpeedometerBloc;
    late MockSettingsBloc mockSettingsBloc;

    setUp(() {
      mockSpeedometerBloc = MockSpeedometerBloc();
      mockSettingsBloc = MockSettingsBloc();
      
      // Register fallback values if needed, e.g. for events
      registerFallbackValue(StartSpeedTracking());
      registerFallbackValue(LoadSettings());
    });
    
    // Helper to pump the widget
    Future<void> pumpSpeedometerScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SpeedometerBloc>.value(value: mockSpeedometerBloc),
            BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
          ],
          child: const MaterialApp(
            home: SpeedometerScreen(),
          ),
        ),
      );
    }

    testWidgets('renders SpeedometerScreen with initial state', (WidgetTester tester) async {
      // Stub SpeedometerBloc
      when(() => mockSpeedometerBloc.state).thenReturn(SpeedometerState.initial());
      when(() => mockSpeedometerBloc.stream).thenAnswer((_) => Stream.value(SpeedometerState.initial()));
      when(() => mockSpeedometerBloc.add(any())).thenAnswer((_) async {});
      when(() => mockSpeedometerBloc.close()).thenAnswer((_) async {});

      // Stub SettingsBloc
      when(() => mockSettingsBloc.state).thenReturn(SettingsState.initial());
      when(() => mockSettingsBloc.stream).thenAnswer((_) => Stream.value(SettingsState.initial()));
      when(() => mockSettingsBloc.add(any())).thenAnswer((_) async {});
      when(() => mockSettingsBloc.close()).thenAnswer((_) async {});

      await pumpSpeedometerScreen(tester);
      await tester.pump(); // allow init to run

      // Verify app bar title
      expect(find.text('Speedometer'), findsOneWidget);
      
      // Verify basic UI elements (Max Speed, Distance)
      // Note: Initial state has 0.0 values.
      // SettingsState.initial() has isMetric = true.
      // So checks for "0.0 km/h" and "0.00 km"
      
      expect(find.text('Max Speed'), findsOneWidget);
      expect(find.text('0.0 km/h'), findsOneWidget);
      
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('0.00 km'), findsOneWidget);
      
      // Verify buttons
      expect(find.text('Toggle Style'), findsOneWidget);
      expect(find.text('Reset Trip'), findsOneWidget);
      
      // Verify StartSpeedTracking event was added on init
      verify(() => mockSpeedometerBloc.add(any(that: isA<StartSpeedTracking>()))).called(1);
    });

    // Add more tests for interactions if needed...
  });
}
