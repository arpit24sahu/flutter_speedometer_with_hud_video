import 'dart:math';
import 'package:flutter/material.dart';

class CompassWidget extends StatelessWidget {
  final double heading;
  final Color color;

  const CompassWidget({
    super.key,
    required this.heading,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        
        return SizedBox(
          width: size * 0.7,
          height: size * 0.7,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer circle
              Container(
                width: size * 0.7,
                height: size * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(
                    color: color.withOpacity(0.5),
                    width: 3,
                  ),
                ),
              ),
              
              // Compass dial
              Transform.rotate(
                angle: -heading * (pi / 180),
                child: Container(
                  width: size * 0.6,
                  height: size * 0.6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                    painter: CompassPainter(color: color),
                  ),
                ),
              ),
              
              // Center point
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              
              // North indicator
              Positioned(
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CompassPainter extends CustomPainter {
  final Color color;

  CompassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw circle
    canvas.drawCircle(center, radius, paint);
    
    // Draw cardinal points
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    final cardinalPoints = ['N', 'E', 'S', 'W'];
    final ordinalPoints = ['NE', 'SE', 'SW', 'NW'];
    
    // Draw cardinal points
    for (int i = 0; i < 4; i++) {
      // Fix 2: Correct angle calculation
      final angle = -i * (pi / 2) - (pi / 2); // Start north, clockwise
      
      final x = center.dx + cos(angle) * (radius - 20);
      final y = center.dy + sin(angle) * (radius - 20);
      
      textPainter.text = TextSpan(
        text: cardinalPoints[i],
        style: TextStyle(
          color: cardinalPoints[i] == 'N' ? Colors.red : color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
      
      // Draw line for cardinal point
      final lineStart = Offset(
        center.dx + cos(angle) * (radius - 40),
        center.dy + sin(angle) * (radius - 40),
      );
      final lineEnd = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      
      final linePaint = Paint()
        ..color = cardinalPoints[i] == 'N' ? Colors.red : color
        ..strokeWidth = 2;
      
      canvas.drawLine(lineStart, lineEnd, linePaint);
    }
    
    // Draw ordinal points
    for (int i = 0; i < 4; i++) {
      final angle = (i * (pi / 2)) + (pi / 4);
      final x = center.dx + cos(angle) * (radius - 25);
      final y = center.dy + sin(angle) * (radius - 25);
      
      textPainter.text = TextSpan(
        text: ordinalPoints[i],
        style: TextStyle(
          color: color.withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
      
      // Draw smaller line for ordinal point
      final lineStart = Offset(
        center.dx + cos(angle) * (radius - 30),
        center.dy + sin(angle) * (radius - 30),
      );
      final lineEnd = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      
      final linePaint = Paint()
        ..color = color.withOpacity(0.7)
        ..strokeWidth = 1;
      
      canvas.drawLine(lineStart, lineEnd, linePaint);
    }
    
    // Draw degree ticks
    for (int i = 0; i < 360; i += 15) {
      final angle = i * (pi / 180);
      final isMajor = i % 90 == 0;
      final isMinor = i % 45 == 0;
      
      final lineStart = Offset(
        center.dx + cos(angle) * (radius - (isMajor ? 15 : isMinor ? 10 : 5)),
        center.dy + sin(angle) * (radius - (isMajor ? 15 : isMinor ? 10 : 5)),
      );
      final lineEnd = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      
      final linePaint = Paint()
        ..color = isMajor
            ? (i == 0 ? Colors.red : color)
            : isMinor
                ? color.withOpacity(0.7)
                : color.withOpacity(0.5)
        ..strokeWidth = isMajor ? 2 : isMinor ? 1.5 : 1;
      
      canvas.drawLine(lineStart, lineEnd, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}