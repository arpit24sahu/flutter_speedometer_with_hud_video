import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/widgets/speed_gauge.dart';

import '../bloc/speedometer/speedometer_bloc.dart';
import '../bloc/speedometer/speedometer_state.dart';

/// Sizing constants for the speedometer overlay container.
/// All sizes are multipliers of the base size passed to the widget.
class SpeedometerOverlaySizing {
  /// Padding ratio for the container
  static const double paddingRatio = 0.03;

  /// Border radius ratio
  static const double borderRadiusRatio = 0.08;

  /// Height ratio for extra widgets area (max speed, label, etc.)
  static const double extraWidgetsHeightRatio = 0.25;

  /// Font size ratio for extra widgets
  static const double extraWidgetsFontRatio = 0.08;

  /// Total height of the overlay (gauge + extra widgets)
  /// This is the sum of: gauge height (0.75) + extra widgets (0.25)
  static const double totalHeightRatio = 1.2; // useless
}

class DigitalSpeedometerOverlay2 extends StatelessWidget {
  final double size;
  final bool isMetric;

  const DigitalSpeedometerOverlay2({
    super.key,
    required this.isMetric,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverlayGaugeConfigurationBloc, OverlayGaugeConfigurationState>(
      builder: (context, state) {
        final padding = size * SpeedometerOverlaySizing.paddingRatio;
        final borderRadius = size * SpeedometerOverlaySizing.borderRadiusRatio;

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: size,
            height: size * SpeedometerOverlaySizing.totalHeightRatio,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  (state.borderWidth > 0 && (state.showGauge || state.showText))
                      ? Border.all(
                        color: state.borderColor,
                        width: state.borderWidth,
                      )
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // The speedometer gauge takes the main space
                Flexible(
                  flex: 3,
                  child: Container(
                    // color: Colors.green,
                    child: SpeedGauge(
                      configState: state,
                      size: size - (padding * 2), // Account for container padding
                      isMetric: isMetric,
                    ),
                  ),
                ),
                Container(color:Colors.transparent, child: _buildExtraWidgets(state, size))
                // Extra widgets area (max speed, label)
                // Flexible(flex: 1, child: _buildExtraWidgets(state, size)),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Builds the extra widgets below the speedometer (max speed, TURBOGAUGE label)
  Widget _buildExtraWidgets(
    OverlayGaugeConfigurationState state,
    double baseSize,
  ) {
    final fontSize = baseSize * SpeedometerOverlaySizing.extraWidgetsFontRatio;
    double currentMaxSpeedKmh = 0;
    double currentMaxSpeedMph = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Max speed widget - can be enabled via config if needed
        if(state.showMaxSpeed) BlocBuilder<SpeedometerBloc, SpeedometerState>(
            builder: (context, SpeedometerState speedometerState) {
              if(speedometerState.speedKmh > currentMaxSpeedKmh) currentMaxSpeedKmh = speedometerState.speedKmh;
              if(speedometerState.speedMph > currentMaxSpeedMph) currentMaxSpeedMph = speedometerState.speedMph;
              // double speed = isMetric ? speedometerState.speedKmh : speedometerState.speedMph;
              String speedText = (isMetric) ? "${currentMaxSpeedKmh.toStringAsFixed(1)} km/h" : "${currentMaxSpeedMph
                  .toStringAsFixed(1)} m/h";
              return Text(
                "Max: $speedText",
                style: TextStyle(
                  // fontFamily: 'RacingSansOne',
                  fontSize: fontSize*0.8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: state.textColor,
                ),
              );
            }
        ),
        SizedBox(
          height: fontSize*0.5,
        ),
        // For now, keeping it simple with just the label
        if (state.showLabel)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "TURBOGAUGE",
                style: TextStyle(
                  fontFamily: 'RacingSansOne',
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: state.textColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}