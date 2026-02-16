import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_bloc.dart';

import '../../features/speedometer/bloc/speedometer_state.dart';

/// Sizing constants as multipliers of the base size.
/// All child elements scale proportionally based on these ratios.
class SpeedGaugeSizing {
  /// Height of the gauge semicircle area relative to size
  static const double gaugeHeightRatio = 0.50;

  /// Width of the gauge semicircle relative to size
  static const double gaugeWidthRatio = 0.90;

  /// Speed value font size ratio
  static const double speedFontRatio = 0.12;

  /// Unit (km/h, mph) font size ratio
  static const double unitFontRatio = 0.06;

  /// Vertical spacing between gauge and text
  static const double gaugePaddingRatio = 0.02;

  /// Total height of the gauge section (semicircle + text + spacing)
  static const double totalGaugeHeightRatio = 0.80;
}

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

  // Calculate effective max speed based on current speed
  double _getEffectiveMaxSpeed(double speed) {
    if (speed > 1000) return 5000;
    if (speed > 180) return 1000;
    return 180.0;
  }
  
  // Get appropriate tick count based on max speed
  int _getTickCount(double maxSpeed) {
    if (maxSpeed >= 5000) return 10; // Every 500
    if (maxSpeed >= 1000) return 10; // Every 100
    return 7; // Original tick count for 180 range
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpeedometerBloc, SpeedometerState>(
      builder: (context, state) {
        double speed = isMetric ? state.speedKmh : state.speedMph;
        double effectiveMaxSpeed = _getEffectiveMaxSpeed(speed);
        int tickCount = _getTickCount(effectiveMaxSpeed);
        
        // Calculate all sizes based on multipliers
        final gaugeHeight = size * SpeedGaugeSizing.gaugeHeightRatio;
        final gaugeWidth = size * SpeedGaugeSizing.gaugeWidthRatio;
        final speedFontSize = size * SpeedGaugeSizing.speedFontRatio;
        final unitFontSize = size * SpeedGaugeSizing.unitFontRatio;
        final gaugePadding = size * SpeedGaugeSizing.gaugePaddingRatio;

        return SizedBox(
          width: size,
          height: size * SpeedGaugeSizing.totalGaugeHeightRatio,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Gauge semicircle
              if (configState.showGauge)
                SizedBox(
                  width: gaugeWidth,
                  height: gaugeHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(gaugeWidth, gaugeHeight),
                        painter: _SimpleGaugePainter(
                          speed: speed,
                          maxSpeed: effectiveMaxSpeed,
                          state: configState,
                          tickCount: tickCount,
                        ),
                      ),
                      // Airplane icon when speed > 180
                      if (speed > 180)
                        Positioned(
                          bottom: gaugeHeight * 0.25,
                          child: Icon(
                            Icons.airplanemode_active,
                            color: configState.gaugeColor,
                            size: size * 0.08,
                          ),
                        ),
                    ],
                  ),
                ),

              SizedBox(height: gaugePadding),
              
              // Digital speed display
              if (configState.showText)
                Text(
                  speed.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: speedFontSize,
                    fontWeight: FontWeight.bold,
                    color: configState.textColor,
                  ),
                ),
              if (configState.showText)
                Text(
                  isMetric ? 'km/h' : 'mph',
                  style: TextStyle(
                    fontSize: unitFontSize,
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
  final int tickCount;

  _SimpleGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.state,
    this.tickCount = 7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = min(size.width / 2, size.height * 0.8);
    
    // Extended beyond semicircle: 210 degrees total (105 degrees on each side)
    const startAngle = pi - pi / 6; // 150 degrees
    const sweepAngle = pi + pi / 3; // 240 degrees

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
    final speedAngle = (min(speed, maxSpeed) / maxSpeed) * sweepAngle;
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
    
    // Draw simple tick marks with dynamic tickCount
    final tickPaint = Paint()
      ..color = state.tickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height*0.05;
    
    for (int i = 0; i <= tickCount; i++) {
      final angle = startAngle + (i / tickCount) * sweepAngle;
      const int num = 2;
      final outerPoint = Offset(
        center.dx + (radius - num) * cos(angle),
        center.dy + (radius - num) * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius - (num+(size.height*0.1))) * cos(angle),
        center.dy + (radius - (num+(size.height*0.1))) * sin(angle),
      );
      
      canvas.drawLine(outerPoint, innerPoint, tickPaint);
      
      // Optional: Add speed labels at tick marks
      if (maxSpeed > 180) {
        final tickValue = (i * (maxSpeed / tickCount)).toInt();
        final textSpan = TextSpan(
          text: tickValue.toString(),
          style: TextStyle(
            color: state.textColor,
            fontSize: size.height * 0.08,
            fontWeight: FontWeight.bold,
          ),
        );
        
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        
        final textAngle = angle - pi/2; // Rotate 90 degrees to align with tick
        final textRadius = radius - size.height * 0.28;
        final textPosition = Offset(
          center.dx + textRadius * cos(angle),
          center.dy + textRadius * sin(angle),
        );
        
        canvas.save();
        canvas.translate(textPosition.dx, textPosition.dy);
        // Uncomment below to add labels (would need positioning adjustments)
        // textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
        canvas.restore();
      }
    }
    
    // Draw the needle
    final needleAngle = startAngle + (min(speed, maxSpeed) / maxSpeed) * sweepAngle;
    
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