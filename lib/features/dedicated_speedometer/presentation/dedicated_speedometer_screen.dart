import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dedicated_speedometer_bloc.dart';
import '../services/dedicated_speedometer_service.dart';
import 'dart:math';
import 'package:speedometer/presentation/screens/home_screen.dart'; // For TabVisibilityAware interface

class DedicatedSpeedometerTab extends StatefulWidget {
  const DedicatedSpeedometerTab({super.key});

  @override
  State<DedicatedSpeedometerTab> createState() => _DedicatedSpeedometerTabState();
}

class _DedicatedSpeedometerTabState extends State<DedicatedSpeedometerTab> implements TabVisibilityAware {
  late DedicatedSpeedometerBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = DedicatedSpeedometerBloc(DedicatedSpeedometerService());
    _bloc.add(StartDedicatedSpeedometer());
  }

  @override
  void onTabVisible() {
    _bloc.add(StartDedicatedSpeedometer());
  }

  @override
  void onTabInvisible() {
    _bloc.add(StopDedicatedSpeedometer());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  double _getDynamicMaxSpeed(double currentMps, SpeedUnit unit) {
    // Dynamic max speed calculation
    double maxKmh;
    if (currentMps < 30) {
      maxKmh = 140;
    } else if (currentMps < 65) {
      maxKmh = 300;
    } else {
      maxKmh = 1000;
    }

    if (unit == SpeedUnit.kmh) {
      return maxKmh;
    } else {
      // Equivalent for mph based on requested kmh breakpoints
      if (maxKmh == 140) return 90;
      if (maxKmh == 300) return 200;
      return 650;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Dark slate premium color
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            'Speedometer',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          actions: [
            BlocBuilder<DedicatedSpeedometerBloc, DedicatedSpeedometerState>(
              builder: (context, state) {
                return IconButton(
                  icon: Icon(
                    state.displayMode == DisplayMode.digital ? Icons.speed : Icons.numbers,
                    color: Colors.cyanAccent,
                  ),
                  onPressed: () => _bloc.add(ToggleAnalogDigitalEvent()),
                  tooltip: 'Toggle View',
                );
              },
            ),
            BlocBuilder<DedicatedSpeedometerBloc, DedicatedSpeedometerState>(
              builder: (context, state) {
                return TextButton(
                  onPressed: () => _bloc.add(ToggleUnitEvent()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                    ),
                    child: Text(
                      state.unit == SpeedUnit.kmh ? 'KM/H' : 'MPH',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            // Background Effects - Glowing Orbs
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            // Glassmorphism effect via BackdropFilter
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: BlocBuilder<DedicatedSpeedometerBloc, DedicatedSpeedometerState>(
                builder: (context, state) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: state.displayMode == DisplayMode.digital
                        ? _buildDigital(state)
                        : _buildAnalog(state),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigital(DedicatedSpeedometerState state) {
    return Container(
      key: const ValueKey('digital'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: state.displaySpeed),
            duration: const Duration(milliseconds: 300),
            builder: (context, speed, child) {
              return Text(
                speed.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 110,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent,
                      blurRadius: 20,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              state.unit == SpeedUnit.kmh ? 'KM/H' : 'MPH',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.cyanAccent,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalog(DedicatedSpeedometerState state) {
    final maxSpeed = _getDynamicMaxSpeed(state.currentSpeedMps, state.unit);
    
    return Container(
      key: const ValueKey('analog'),
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: state.displaySpeed),
            duration: const Duration(milliseconds: 300),
            builder: (context, animSpeed, child) {
              return CustomPaint(
                size: const Size(340, 340),
                painter: _PremiumSpeedometerPainter(
                  speed: animSpeed,
                  maxSpeed: maxSpeed,
                  unit: state.unit,
                ),
              );
            },
          ),
          Positioned(
            bottom: 70,
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: state.displaySpeed),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, speed, child) {
                    return Text(
                      speed.toInt().toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.cyanAccent, blurRadius: 15)
                        ],
                      ),
                    );
                  }
                ),
                Text(
                  state.unit == SpeedUnit.kmh ? 'KM/H' : 'MPH',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _PremiumSpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final SpeedUnit unit;

  _PremiumSpeedometerPainter({required this.speed, required this.maxSpeed, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    // Inner dark background
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 10, bgPaint);

    const minAngle = -pi * 0.75;
    const maxAngle = pi * 0.75;
    final sweepAngle = maxAngle - minAngle;

    // Draw track arc
    final trackRect = Rect.fromCircle(center: center, radius: radius - 20);
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(trackRect, minAngle - pi / 2, sweepAngle, false, trackPaint);

    // Active speed arc gradient
    final activeGradient = SweepGradient(
      colors: const [Colors.greenAccent, Colors.cyanAccent, Colors.pinkAccent],
      stops: const [0.0, 0.5, 1.0],
      startAngle: minAngle - pi / 2,
      endAngle: maxAngle - pi / 2,
      transform: GradientRotation(-pi / 2),
    );

    final normalizedSpeed = (speed.clamp(0.0, maxSpeed) / maxSpeed);
    
    // Draw active arc
    if (normalizedSpeed > 0) {
      final activePaint = Paint()
        ..shader = activeGradient.createShader(trackRect)
        ..strokeWidth = 15
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(trackRect, minAngle - pi / 2, sweepAngle * normalizedSpeed, false, activePaint);
    }

    // Determine Tick intervals based on maxSpeed
    double step;
    if (unit == SpeedUnit.kmh) {
      if (maxSpeed <= 140) step = 10;
      else if (maxSpeed <= 300) step = 20;
      else step = 100;
    } else {
      if (maxSpeed <= 90) step = 10;
      else if (maxSpeed <= 200) step = 10;
      else step = 50;
    }

    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final majorTickPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw ticks
    for (double i = 0; i <= maxSpeed; i += step) {
      final ratio = i / maxSpeed;
      final angle = minAngle + ratio * sweepAngle - pi / 2;
      final isMajor = i % (step * 2) == 0;
      final tickLength = isMajor ? 16.0 : 8.0;
      
      final p1 = Offset(
        center.dx + (radius - 40 - tickLength) * cos(angle),
        center.dy + (radius - 40 - tickLength) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 40) * cos(angle),
        center.dy + (radius - 40) * sin(angle),
      );
      
      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);

      if (isMajor) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i.toInt().toString(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9), 
              fontSize: 12, 
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final textOffset = Offset(
          center.dx + (radius - 70) * cos(angle) - textPainter.width / 2,
          center.dy + (radius - 70) * sin(angle) - textPainter.height / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }

    // Draw needle
    final needleAngle = minAngle + normalizedSpeed * sweepAngle - pi / 2;
    final needlePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3); // Glow effect

    final needleEnd = Offset(
      center.dx + (radius - 45) * cos(needleAngle),
      center.dy + (radius - 45) * sin(needleAngle),
    );

    // Dynamic color for center dot
    final centerColor = normalizedSpeed > 0.8 ? Colors.pinkAccent : Colors.cyanAccent;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Center pivot
    final outerPivot = Paint()..color = Colors.white.withOpacity(0.1);
    canvas.drawCircle(center, 12, outerPivot);
    
    final dotPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, dotPaint);
    
    final dotInner = Paint()
      ..color = centerColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    canvas.drawCircle(center, 4, dotInner);
  }

  @override
  bool shouldRepaint(covariant _PremiumSpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed || 
           oldDelegate.maxSpeed != maxSpeed ||
           oldDelegate.unit != unit;
  }
}
