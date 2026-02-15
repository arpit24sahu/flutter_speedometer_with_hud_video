import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/gauge_customization.dart';
import 'bloc/gauge_customization_bloc.dart';

class SpeedometerOverlay3 extends StatelessWidget {
  final double speed; // current speed
  final double maxSpeed; // e.g. 240
  final Size screenSize;

  const SpeedometerOverlay3({
    super.key,
    required this.speed,
    required this.maxSpeed,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GaugeCustomizationBloc, GaugeCustomizationState>(
      builder: (context, state) {
        final config = state.customization;

        final dial = config.dial;
        final needle = config.needle;

        if (dial == null) return const SizedBox.shrink();

        final sizeFactor = config.sizeFactor ?? 0.25;
        final gaugeWidth = screenSize.width * sizeFactor;
        final gaugeHeight =
            gaugeWidth * (config.gaugeAspectRatio ?? 1.0);

        final position = _calculatePosition(
          placement: config.placement ?? GaugePlacement.bottomRight,
          gaugeSize: Size(gaugeWidth, gaugeHeight),
          screenSize: screenSize,
        );

        final rotationAngle = _calculateNeedleAngle(
          speed: speed,
          maxSpeed: maxSpeed,
          dial: dial,
        );

        return Positioned(
          top: position.top,
          bottom: position.bottom,
          left: position.left,
          right: position.right,
          width: gaugeWidth,
          height: gaugeHeight,
          child: IgnorePointer(
            child: Stack(
              alignment: Alignment.center,
              children: [

                /// ───── Dial ─────
                _buildDial(dial, gaugeWidth),

                /// ───── Needle ─────
                if (needle != null)
                  Transform.rotate(
                    angle: rotationAngle,
                    alignment: Alignment.center,
                    child: _buildNeedle(needle, gaugeWidth),
                  ),

                /// ───── Speed Text ─────
                if (config.showSpeed ?? true)
                  Positioned(
                    bottom: 8,
                    child: Text(
                      "${speed.toStringAsFixed(0)} ${config.isMetric == true ? "mph" : "km/h"}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                /// ───── Branding ─────
                if (config.showBranding ?? true)
                  const Positioned(
                    top: 6,
                    child: Text(
                      "TURBOGAUGE",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Dial Builder
  // ─────────────────────────────────────────────

  Widget _buildDial(Dial dial, double size) {
    switch (dial.assetType) {
      case AssetType.asset:
        return Image.asset(
          dial.path ?? "",
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      case AssetType.network:
        return Image.network(
          dial.path ?? "",
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      case AssetType.memory:
        return Image.memory(
          dial.extra?['bytes'],
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────
  // Needle Builder
  // ─────────────────────────────────────────────

  Widget _buildNeedle(Needle needle, double size) {
    switch (needle.assetType) {
      case AssetType.asset:
        return Image.asset(
          needle.path ?? "",
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      case AssetType.network:
        return Image.network(
          needle.path ?? "",
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      case AssetType.memory:
        return Image.memory(
          needle.extra?['bytes'],
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────
  // Angle Calculation
  // ─────────────────────────────────────────────

  double _calculateNeedleAngle({
    required double speed,
    required double maxSpeed,
    required Dial dial,
  }) {
    final clampedSpeed = speed.clamp(0, maxSpeed);

    final progress = clampedSpeed / maxSpeed;

    final angleDegrees =
        dial.needleMinAngle + (dial.totalSweep * progress);

    return (angleDegrees * pi) / 180;
  }

  // ─────────────────────────────────────────────
  // Position Calculation
  // ─────────────────────────────────────────────

  _OverlayPosition _calculatePosition({
    required GaugePlacement placement,
    required Size gaugeSize,
    required Size screenSize,
    double margin = 16,
  }) {
    switch (placement) {
      case GaugePlacement.topLeft:
        return _OverlayPosition(
            top: margin, left: margin);

      case GaugePlacement.topCenter:
        return _OverlayPosition(
            top: margin,
            left: (screenSize.width - gaugeSize.width) / 2);

      case GaugePlacement.topRight:
        return _OverlayPosition(
            top: margin,
            right: margin);

      case GaugePlacement.centerLeft:
        return _OverlayPosition(
            top: (screenSize.height - gaugeSize.height) / 2,
            left: margin);

      case GaugePlacement.center:
        return _OverlayPosition(
            top: (screenSize.height - gaugeSize.height) / 2,
            left: (screenSize.width - gaugeSize.width) / 2);

      case GaugePlacement.centerRight:
        return _OverlayPosition(
            top: (screenSize.height - gaugeSize.height) / 2,
            right: margin);

      case GaugePlacement.bottomLeft:
        return _OverlayPosition(
            bottom: margin, left: margin);

      case GaugePlacement.bottomCenter:
        return _OverlayPosition(
            bottom: margin,
            left: (screenSize.width - gaugeSize.width) / 2);

      case GaugePlacement.bottomRight:
        return _OverlayPosition(
            bottom: margin, right: margin);
    }
  }
}

class _OverlayPosition {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  _OverlayPosition({
    this.top,
    this.bottom,
    this.left,
    this.right,
  });
}