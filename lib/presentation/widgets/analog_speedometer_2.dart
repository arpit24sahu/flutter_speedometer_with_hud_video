import 'dart:math';
import 'package:flutter/material.dart';

class AnalogSpeedometer2 extends StatefulWidget {
  final double speed;
  final bool isMetric;
  final Color speedometerColor;
  final double maxSpeed;

  const AnalogSpeedometer2({
    super.key,
    required this.speed,
    required this.isMetric,
    required this.speedometerColor,
    this.maxSpeed = 180,
  });

  @override
  State<AnalogSpeedometer2> createState() => _AnalogSpeedometer2State();
}

class _AnalogSpeedometer2State extends State<AnalogSpeedometer2>
    with TickerProviderStateMixin {
  late AnimationController _needleController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _arcController;

  late Animation<double> _needleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _arcAnimation;

  double _previousSpeed = 0;
  double _previousNeedleAngle = 0;

  @override
  void initState() {
    super.initState();

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    final startAngle = _calculateAngle(0, _effectiveMaxSpeed(widget.speed));

    _needleAnimation = Tween<double>(
      begin: startAngle,
      end: startAngle,
    ).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutBack),
    );

    _arcAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _arcController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _previousNeedleAngle = startAngle;
    _animateTo(widget.speed);
  }

  double _effectiveMaxSpeed(double speed) {
    if (speed > 1000) return 5000;
    if (speed > 500) return 1000;
    if (speed > 180) return 500;
    return 180;
  }

  double _calculateAngle(double value, double maxSpeed) {
    const double startAngle = -225 * pi / 180;
    const double totalAngle = 270 * pi / 180;
    final double speedRatio = (value / maxSpeed).clamp(0.0, 1.0);
    return startAngle + (totalAngle * speedRatio);
  }

  void _animateTo(double newSpeed) {
    final maxSpeed = _effectiveMaxSpeed(newSpeed);
    final endAngle = _calculateAngle(newSpeed, maxSpeed);
    final endRatio = (newSpeed / maxSpeed).clamp(0.0, 1.0);

    _needleAnimation = Tween<double>(
      begin: _previousNeedleAngle,
      end: endAngle,
    ).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutBack),
    );

    _arcAnimation = Tween<double>(
      begin: _arcAnimation.value,
      end: endRatio,
    ).animate(CurvedAnimation(parent: _arcController, curve: Curves.easeOut));

    _needleController.forward(from: 0);
    _arcController.forward(from: 0);
    _previousNeedleAngle = endAngle;
    _previousSpeed = newSpeed;
  }

  @override
  void didUpdateWidget(AnalogSpeedometer2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _animateTo(widget.speed);
    }
  }

  @override
  void dispose() {
    _needleController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _arcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);

        return AnimatedBuilder(
          animation: Listenable.merge([
            _needleAnimation,
            _pulseAnimation,
            _glowAnimation,
            _arcAnimation,
          ]),
          builder: (context, child) {
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _SpeedometerPainter(
                    speed: widget.speed,
                    maxSpeed: _effectiveMaxSpeed(widget.speed),
                    needleAngle: _needleAnimation.value,
                    arcRatio: _arcAnimation.value,
                    color: widget.speedometerColor,
                    isMetric: widget.isMetric,
                    pulseValue: _pulseAnimation.value,
                    glowValue: _glowAnimation.value,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final double needleAngle;
  final double arcRatio;
  final Color color;
  final bool isMetric;
  final double pulseValue;
  final double glowValue;

  _SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.needleAngle,
    required this.arcRatio,
    required this.color,
    required this.isMetric,
    required this.pulseValue,
    required this.glowValue,
  });

  static const double _startAngle = -225 * pi / 180;
  static const double _totalAngle = 270 * pi / 180;

  Color get _arcColor {
    if (arcRatio < 0.45) return color;
    if (arcRatio < 0.75) {
      return Color.lerp(
        color,
        Colors.orange.shade400,
        (arcRatio - 0.45) / 0.3,
      )!;
    }
    return Color.lerp(
      Colors.orange.shade400,
      Colors.redAccent,
      (arcRatio - 0.75) / 0.25,
    )!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    _drawOuterRings(canvas, center, radius);
    _drawFaceBackground(canvas, center, radius);
    _drawTrackArc(canvas, center, radius);
    _drawSpeedArc(canvas, center, radius);
    _drawTicks(canvas, center, radius);
    _drawLabels(canvas, center, radius);
    _drawNeedle(canvas, center, radius);
    _drawCenterHub(canvas, center, radius);
    _drawDigitalReadout(canvas, center, radius);
  }

  void _drawOuterRings(Canvas canvas, Offset center, double radius) {
    // Ambient glow ring
    final outerGlow =
        Paint()
          ..color = color.withOpacity(0.08 * glowValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, radius * 0.98, outerGlow);

    // Outer bezel
    final bezelPaint =
        Paint()
          ..shader = SweepGradient(
            colors: [
              Colors.grey.shade700,
              Colors.grey.shade900,
              Colors.grey.shade600,
              Colors.grey.shade900,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.045;
    canvas.drawCircle(center, radius * 0.955, bezelPaint);

    // Inner bezel accent
    final accentPaint =
        Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.93, accentPaint);
  }

  void _drawFaceBackground(Canvas canvas, Offset center, double radius) {
    // Main face
    final facePaint =
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFF1a1a2e), const Color(0xFF0d0d0d)],
            center: const Alignment(-0.3, -0.3),
            radius: 1.2,
          ).createShader(
            Rect.fromCircle(center: center, radius: radius * 0.92),
          );
    canvas.drawCircle(center, radius * 0.92, facePaint);

    // Subtle inner shadow
    final innerShadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.04
          ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 8);
    canvas.drawCircle(center, radius * 0.90, innerShadowPaint);
  }

  void _drawTrackArc(Canvas canvas, Offset center, double radius) {
    final trackPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.055
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.70),
      _startAngle,
      _totalAngle,
      false,
      trackPaint,
    );
  }

  void _drawSpeedArc(Canvas canvas, Offset center, double radius) {
    if (arcRatio <= 0.001) return;

    final sweep = _totalAngle * arcRatio;
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.70);
    final arcColorFinal = _arcColor;

    // Wide blur glow
    final wideGlow =
        Paint()
          ..color = arcColorFinal.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.18
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawArc(arcRect, _startAngle, sweep, false, wideGlow);

    // Medium glow
    final medGlow =
        Paint()
          ..color = arcColorFinal.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.08
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(arcRect, _startAngle, sweep, false, medGlow);

    // Core arc
    final arcPaint =
        Paint()
          ..shader = SweepGradient(
            colors: [arcColorFinal.withOpacity(0.6), arcColorFinal],
            startAngle: _startAngle,
            endAngle: _startAngle + sweep,
          ).createShader(arcRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.055
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, _startAngle, sweep, false, arcPaint);

    // Bright leading tip
    final tipAngle = _startAngle + sweep;
    final tipX = center.dx + radius * 0.70 * cos(tipAngle);
    final tipY = center.dy + radius * 0.70 * sin(tipAngle);
    final tipPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(tipX, tipY), radius * 0.028, tipPaint);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    const int majorDivisions = 9;
    const int minorsPerMajor = 4;
    const int total = majorDivisions * minorsPerMajor;

    for (int i = 0; i <= total; i++) {
      final bool isMajor = i % minorsPerMajor == 0;
      final angle = _startAngle + _totalAngle * i / total;

      final outerR = radius * 0.82;
      final innerR = isMajor ? radius * 0.71 : radius * 0.77;

      final sinA = sin(angle);
      final cosA = cos(angle);

      canvas.drawLine(
        Offset(center.dx + innerR * cosA, center.dy + innerR * sinA),
        Offset(center.dx + outerR * cosA, center.dy + outerR * sinA),
        Paint()
          ..color =
              isMajor ? color.withOpacity(1.0) : Colors.white.withOpacity(0.6)
          ..strokeWidth = isMajor ? 3.0 : 1.5
          ..strokeCap = StrokeCap.round,
      );

      // Colored glow on major ticks at current speed zone
      if (isMajor) {
        final tickRatio = i / total;
        if (tickRatio <= arcRatio) {
          canvas.drawLine(
            Offset(center.dx + innerR * cosA, center.dy + innerR * sinA),
            Offset(center.dx + outerR * cosA, center.dy + outerR * sinA),
            Paint()
              ..color = _arcColor.withOpacity(0.8)
              ..strokeWidth = 2.0
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    final values = <int>[];
    final int step = (maxSpeed / 9).round();
    for (int i = 0; i <= 9; i++) {
      values.add(i * step);
    }

    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      final angle = _startAngle + _totalAngle * i / (values.length - 1);
      final labelR = radius * 0.58;

      final x = center.dx + labelR * cos(angle);
      final y = center.dy + labelR * sin(angle);

      final isActive = (i / (values.length - 1)) <= arcRatio;
      final labelColor =
          isActive ? _arcColor.withOpacity(1.0) : Colors.white.withOpacity(0.9);

      final tp = TextPainter(
        text: TextSpan(
          text: value.toString(),
          style: TextStyle(
            color: labelColor,
            fontSize: radius * 0.085,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(needleAngle + pi / 2);

    // Needle shadow
    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.5)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(
      const Offset(1.5, 12),
      Offset(0, -radius * 0.62),
      shadowPaint,
    );

    // Rear needle (counterbalance)
    final rearPaint =
        Paint()
          ..color = Colors.red.shade700
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(0, radius * 0.16), rearPaint);

    // Needle glow
    final needleGlow =
        Paint()
          ..color = color.withOpacity(0.45)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawLine(
      Offset(0, radius * 0.06),
      Offset(0, -radius * 0.62),
      needleGlow,
    );

    // Main needle body
    final path = Path();
    path.moveTo(-2.5, radius * 0.06);
    path.lineTo(2.5, radius * 0.06);
    path.lineTo(1.0, -radius * 0.62);
    path.lineTo(-1.0, -radius * 0.62);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, Colors.white.withOpacity(0.95)],
        ).createShader(Rect.fromLTWH(-2.5, -radius * 0.62, 5, radius * 0.68)),
    );

    canvas.restore();
  }

  void _drawCenterHub(Canvas canvas, Offset center, double radius) {
    // Pulsing halo
    final halo =
        Paint()
          ..color = color.withOpacity(0.2 * (pulseValue - 0.85) / 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius * 0.11 * pulseValue, halo);

    // Hub outer ring
    canvas.drawCircle(
      center,
      radius * 0.085,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.grey.shade600, Colors.grey.shade900],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.085)),
    );

    // Hub color ring
    canvas.drawCircle(
      center,
      radius * 0.075,
      Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Hub fill
    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.grey.shade500, Colors.grey.shade800],
          center: const Alignment(-0.4, -0.4),
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.06)),
    );

    // Center dot
    canvas.drawCircle(
      center,
      radius * 0.02,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  void _drawDigitalReadout(Canvas canvas, Offset center, double radius) {
    // Background panel
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.6), // 0.42),
        width: radius * 0.72,
        height: radius * 0.22,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      panelRect,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      panelRect,
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Speed number
    final speedText = speed.toStringAsFixed((speed >= 10) ? 0 : 1);
    final speedTp = TextPainter(
      text: TextSpan(
        text: speedText,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.18,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          height: 1,
          shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    speedTp.paint(
      canvas,
      Offset(center.dx - speedTp.width / 2, center.dy + radius * 0.52),
    );

    // Unit label
    final unitTp = TextPainter(
      text: TextSpan(
        text: isMetric ? 'KM/H' : 'MPH',
        style: TextStyle(
          color: color.withOpacity(0.7),
          fontSize: radius * 0.07,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    unitTp.paint(
      canvas,
      Offset(center.dx - unitTp.width / 2, center.dy + radius * 0.72),
    );
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.speed != speed ||
      old.needleAngle != needleAngle ||
      old.arcRatio != arcRatio ||
      old.pulseValue != pulseValue ||
      old.glowValue != glowValue ||
      old.color != color;
}
