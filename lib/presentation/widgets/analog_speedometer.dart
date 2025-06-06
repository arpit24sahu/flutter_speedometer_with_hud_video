import 'dart:math';
import 'package:flutter/material.dart';

class AnalogSpeedometer extends StatelessWidget {
  final double speed;
  final bool isMetric;
  final Color speedometerColor;
  final double maxSpeed;

  const AnalogSpeedometer({
    super.key,
    required this.speed,
    required this.isMetric,
    required this.speedometerColor,
    this.maxSpeed = 180,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        
        return Center(
          child: Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.7),
              boxShadow: [
                BoxShadow(
                  color: speedometerColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Speedometer background
                Container(
                  width: size * 0.85,
                  height: size * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: speedometerColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
                
                // Speedometer ticks
                ...List.generate(
                  19,
                  (index) {
                    final value = index * 10;
                    final angle = _calculateAngle(value.toDouble());
                    final isMajor = index % 2 == 0;
                    
                    return Transform.rotate(
                      angle: angle,
                      child: Transform.translate(
                        offset: Offset(0, -size * 0.35),
                        child: Container(
                          width: isMajor ? 3 : 1,
                          height: isMajor ? size * 0.08 : size * 0.04,
                          color: isMajor
                              ? speedometerColor
                              : speedometerColor.withOpacity(0.7),
                        ),
                      ),
                    );
                  },
                ),
                
                // Speedometer numbers
                ...List.generate(
                  10,
                  (index) {
                    final value = index * 20;
                    final angle = _calculateAngle(value.toDouble());
                    final radians = angle - pi / 2;
                    final x = cos(radians) * size * 0.28;
                    final y = sin(radians) * size * 0.28;
                    
                    return Transform.translate(
                      offset: Offset(x, y),
                      child: Text(
                        value.toString(),
                        style: TextStyle(
                          color: speedometerColor,
                          fontSize: size * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                
                // Unit label
                Positioned(
                  bottom: size * 0.25,
                  child: Text(
                    isMetric ? 'km/h' : 'mph',
                    style: TextStyle(
                      color: speedometerColor,
                      fontSize: size * 0.05,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                // Speed value
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        speed.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 100,
                      )
                    ],
                  ),
                ),
                
                // Needle
                Transform.rotate(
                  angle: _calculateAngle(speed),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Needle base
                      Container(
                        width: size * 0.08,
                        height: size * 0.08,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: speedometerColor,
                          boxShadow: [
                            BoxShadow(
                              color: speedometerColor.withOpacity(0.5),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      // Needle
                      Transform.translate(
                        offset: Offset(0, -size * 0.2),
                        child: Container(
                          width: 3,
                          height: size * 0.35,
                          decoration: BoxDecoration(
                            color: speedometerColor,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: speedometerColor.withOpacity(0.5),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateAngle(double value) {
    // Map speed value to angle (0 to 180 degrees, converted to radians)
    // Starting from -135 degrees (bottom left) to 135 degrees (bottom right)
    const double startAngle = -135 * pi / 180;
    const double totalAngle = 270 * pi / 180;
    
    final double speedRatio = min(value / maxSpeed, 1.0);
    return startAngle + (totalAngle * speedRatio);
  }
}