import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_state.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_bloc.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_event.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_state.dart';
import 'package:speedometer/presentation/widgets/compass_widget.dart';

class CompassScreen extends StatelessWidget {
  const CompassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return Scaffold(
          backgroundColor: settingsState.backgroundColor,
          appBar: AppBar(
            title: const Text('Compass'),
            backgroundColor: settingsState.backgroundColor.withOpacity(0.8),
          ),
          body: BlocBuilder<SpeedometerBloc, SpeedometerState>(
            builder: (context, state) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if(state.calibrationRequired)
                      SizedBox(
                        height: 200,
                        width: 200,
                        child: Image.asset("assets/images/calibrate.gif"),
                      )
                    else CompassWidget(
                      heading: state.heading,
                      color: settingsState.speedometerColor,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${state.heading.toStringAsFixed(1)}°',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: settingsState.speedometerColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getDirectionFromHeading(state.heading),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getDirectionFromHeading(double heading) {
    if (heading >= 337.5 || heading < 22.5) {
      return 'N';
    } else if (heading >= 22.5 && heading < 67.5) {
      return 'NE';
    } else if (heading >= 67.5 && heading < 112.5) {
      return 'E';
    } else if (heading >= 112.5 && heading < 157.5) {
      return 'SE';
    } else if (heading >= 157.5 && heading < 202.5) {
      return 'S';
    } else if (heading >= 202.5 && heading < 247.5) {
      return 'SW';
    } else if (heading >= 247.5 && heading < 292.5) {
      return 'W';
    } else {
      return 'NW';
    }
  }
}