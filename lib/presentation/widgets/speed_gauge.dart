import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_bloc.dart';

import '../bloc/speedometer/speedometer_state.dart';

class SpeedGauge extends StatelessWidget {
  final double maxSpeed, size;
  final bool isMetric;
  final OverlayGaugeConfigurationState configState;

  const SpeedGauge({
    super.key,
    required this.size,
    required this.isMetric,
    this.maxSpeed = 180.0,
    required this.configState,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpeedometerBloc, SpeedometerState>(
      builder: (context, state) {
        double speed = isMetric ? state.speedKmh : state.speedMph;
        return SizedBox(
          width: size,
          height: size*65, // Increased height a bit
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple gauge widget
              if(configState.showGauge) Container(
                width: size*0.9,
                height: size*0.45, // Increased height a bit
                // color: Colors.green,
                padding: const EdgeInsets.only(top: 10),
                child: CustomPaint(
                  size: Size(size * 0.9, size * 0.45),
                  painter: _SimpleGaugePainter(
                    speed: speed,
                    maxSpeed: maxSpeed,
                    state: configState,
                  ),
                ),
              ),
              SizedBox(height: size * 0.05),
              // Digital speed display
              if(configState.showText) Text(
                speed.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: size*0.12,
                  fontWeight: FontWeight.bold,
                  color: configState.textColor,
                ),
              ),
              if(configState.showText) Text(
                (isMetric ? 'km/h' : 'mph'),
                style: TextStyle(
                  fontSize: size*0.08,
                  fontWeight: FontWeight.bold,
                  color: configState.textColor,
                ),
              ),

            ],
          ),
        );
      }
    );
  }
}

class _SimpleGaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final OverlayGaugeConfigurationState state;

  _SimpleGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height*0.8);
    final radius = min(size.width / 2, size.height*0.9) ;
    
    // Extended beyond semicircle: 210 degrees total (105 degrees on each side)
    // const startAngle = pi + pi/6; // 210 degrees (bottom + 30 degrees)
    // const sweepAngle = -pi - pi/3; // -210 degrees (going clockwise, more than upside down)
    const startAngle = pi - pi/6; // 210 degrees (bottom + 30 degrees)
    const sweepAngle = pi + pi/3; // -210 degrees (going clockwise, more than upside down)

    // Draw gauge arc background
    final gaugeBgPaint = Paint()
      ..color = state.gaugeColor
      // ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height*0.1
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      gaugeBgPaint,
    );
    
    // Draw progress arc with speedometer color
    final speedAngle = (speed / maxSpeed) * sweepAngle;
    final gaugePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height*0.08
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      speedAngle,
      false,
      gaugePaint,
    );
    
    // Draw simple tick marks
    final tickPaint = Paint()
      ..color = state.tickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height*0.05;
    
    final tickCount = 7; // Adjusted for 210 degrees
    
    for (int i = 0; i <= tickCount; i++) {
      final angle = startAngle + (i / tickCount) * sweepAngle;
      final int num = 2;
      final outerPoint = Offset(
        center.dx + (radius - num) * cos(angle),
        center.dy + (radius - num) * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius - (num+(size.height*0.1))) * cos(angle),
        center.dy + (radius - (num+(size.height*0.1))) * sin(angle),
      );
      
      canvas.drawLine(outerPoint, innerPoint, tickPaint);
    }
    
    // Draw the needle
    final needleAngle = startAngle + (speed / maxSpeed) * sweepAngle;
    // final needleLinePaint = Paint()
    //   ..color = accentColor
    //   ..style = PaintingStyle.fill;
    
    // Draw a simple needle line
    final needleStart = Offset(
      center.dx + 6 * cos(needleAngle + pi/2),
      center.dy + 6 * sin(needleAngle + pi/2),
    );
    
    final needleEnd = Offset(
      center.dx + radius * cos(needleAngle),
      center.dy + radius * sin(needleAngle),
    );
    
    final needleLinePaint = Paint()
      ..color = state.needleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height*0.05
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(center, needleEnd, needleLinePaint);
    
    // Draw small circle at center with speedometer color
    final centerPaint = Paint()
      ..color = state.needleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.height*0.05, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}