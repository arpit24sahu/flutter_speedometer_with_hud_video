import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/widgets/speed_gauge.dart';

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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: (state.borderWidth>0 && (state.showGauge||state.showText)) ? Border.all(
              color: state.borderColor,
              width: state.borderWidth,
            ) : null
          ),
          child: SpeedGauge(
            configState: state,
            size: size,
            isMetric: isMetric,
          ),
        );
      }
    );
  }
}