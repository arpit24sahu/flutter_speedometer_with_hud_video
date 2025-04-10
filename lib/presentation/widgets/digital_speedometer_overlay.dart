import 'package:flutter/material.dart';

class DigitalSpeedometerOverlay extends StatelessWidget {
  final double speed;
  final bool isMetric;
  final Color speedometerColor;

  const DigitalSpeedometerOverlay({
    super.key,
    required this.speed,
    required this.isMetric,
    required this.speedometerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // color: Colors.black.withOpacity(0.7),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: speedometerColor.withOpacity(0.7),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SPEED',
            style: TextStyle(
              color: speedometerColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                speed.toStringAsFixed(1),
                style: TextStyle(
                  color: speedometerColor,
                  // color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: speedometerColor.withOpacity(0.7),
                      blurRadius: 5,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isMetric ? 'km/h' : 'mph',
                style: TextStyle(
                  color: speedometerColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}