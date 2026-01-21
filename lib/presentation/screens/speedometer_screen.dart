import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_state.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_bloc.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_event.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_state.dart';
import 'package:speedometer/presentation/screens/settings_screen.dart';
import 'package:speedometer/presentation/widgets/analog_speedometer.dart';
import 'package:speedometer/presentation/widgets/digital_speedometer.dart';

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if(context.mounted) context.read<SpeedometerBloc>().add(StartSpeedTracking());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if(context.mounted) context.read<SpeedometerBloc>().add(StopSpeedTracking());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if(context.mounted) context.read<SpeedometerBloc>().add(StartSpeedTracking());
    } else if (state == AppLifecycleState.paused) {
      if(context.mounted) context.read<SpeedometerBloc>().add(StopSpeedTracking());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return Scaffold(
          backgroundColor: settingsState.backgroundColor,
          appBar: AppBar(
            centerTitle: false,
            title: const Text('Speedometer'),
            backgroundColor: settingsState.backgroundColor.withOpacity(0.9),
            actions: [
              IconButton(
                onPressed: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
                },
                icon: Icon(Icons.settings),
              )
            ],
          ),
          body: BlocBuilder<SpeedometerBloc, SpeedometerState>(
            builder: (context, state) {
              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child:
                        state.isDigital
                            ? DigitalSpeedometer(
                              speed:
                                  settingsState.isMetric
                                      ? state.speedKmh
                                      : state.speedMph,
                              isMetric: settingsState.isMetric,
                              speedometerColor: settingsState.speedometerColor,
                            )
                            : AnalogSpeedometer(
                              speed:
                                  settingsState.isMetric
                                      ? state.speedKmh
                                      : state.speedMph,
                              isMetric: settingsState.isMetric,
                              speedometerColor: settingsState.speedometerColor,
                            ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildInfoCard(
                                'Max Speed',
                                '${settingsState.isMetric ? state.maxSpeedKmh.toStringAsFixed(1) : state.maxSpeedMph.toStringAsFixed(1)} ${settingsState.isMetric ? 'km/h' : 'mph'}',
                                settingsState.speedometerColor,
                              ),
                              _buildInfoCard(
                                'Distance',
                                '${settingsState.isMetric ? state.distanceKm.toStringAsFixed(2) : state.distanceMiles.toStringAsFixed(2)} ${settingsState.isMetric ? 'km' : 'mi'}',
                                settingsState.speedometerColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                icon: Icons.speed,
                                label: 'Toggle Style',
                                onPressed: () {
                                  context.read<SpeedometerBloc>().add(
                                    ToggleSpeedometerType(),
                                  );
                                },
                                color: settingsState.speedometerColor,
                              ),
                              _buildActionButton(
                                icon: Icons.refresh,
                                label: 'Reset Trip',
                                onPressed: () async {
                                  // await processChromaKeyVideo();
                                  context.read<SpeedometerBloc>().add(
                                    ResetTrip(),
                                  );
                                },
                                color: settingsState.speedometerColor,
                              ),
                              // _buildActionButton(
                              //   icon: Icons.explore,
                              //   label: 'Compass',
                              //   onPressed: () {
                              //     Navigator.push(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder: (context) => const CompassScreen(),
                              //       ),
                              //     );
                              //   },
                              //   color: settingsState.speedometerColor,
                              // ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
            backgroundColor: color.withOpacity(0.2),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
