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
        
        return SizedBox(
          width: size,
          height: size*65, 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple gauge widget
              if(configState.showGauge) Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: size*0.9,
                    height: size*0.45, 
                    padding: const EdgeInsets.only(top: 10),
                    child: CustomPaint(
                      size: Size(size * 0.9, size * 0.45),
                      painter: _SimpleGaugePainter(
                        speed: speed,
                        maxSpeed: effectiveMaxSpeed,
                        state: configState,
                        tickCount: tickCount,
                      ),
                    ),
                  ),
                  
                  // Airplane icon when speed > 180
                  if (speed > 180)
                    Positioned(
                      bottom: size * 0.15,
                      child: Icon(
                        Icons.airplanemode_active,
                        color: configState.gaugeColor,
                        size: size * 0.1,
                      ),
                    ),
                ],
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
  final int tickCount;

  _SimpleGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.state,
    this.tickCount = 7,
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