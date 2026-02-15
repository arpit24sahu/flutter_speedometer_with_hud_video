import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/gauge_customization.dart';
import 'bloc/gauge_customization_bloc.dart';

/// A speedometer overlay widget that renders a dial + needle + optional text.
///
/// This widget does NOT position itself — it fills whatever size its parent
/// gives it. Positioning should be handled by the parent (e.g. via
/// `GaugePlacement.buildPositioned()`).
class SpeedometerOverlay3 extends StatelessWidget {
  final double speed; // current speed
  final double maxSpeed; // e.g. 240

  /// Optional fixed size. If null, the widget uses LayoutBuilder to fill
  /// the available parent constraints.
  final double? size;

  /// Kept for backward compatibility but no longer used for positioning.
  /// @deprecated — use parent positioning instead.
  final Size? screenSize;

  const SpeedometerOverlay3({
    super.key,
    required this.speed,
    required this.maxSpeed,
    this.size,
    this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GaugeCustomizationBloc, GaugeCustomizationState>(
      builder: (context, state) {
        final config = state.customization;

        final dial = config.dial;
        final needle = config.needle;
        print("Building Speedometer Overlay: ${dial == null}");

        if (dial == null) return const SizedBox.shrink();

        final rotationAngle = _calculateNeedleAngle(
          speed: speed,
          maxSpeed: maxSpeed,
          dial: dial,
        );


        // If a fixed size was provided, use it; otherwise fill parent.
        if (size != null) {
          return _buildGaugeContent(
            config: config,
            dial: dial,
            needle: needle,
            rotationAngle: rotationAngle,
            gaugeWidth: size!,
            gaugeHeight: size! * (config.gaugeAspectRatio ?? 1.0),
          );
        }

        print("Building Speedometer Overlay: ${state.customization.isMetric}");


        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final gaugeWidth = availableWidth;
            final gaugeHeight = gaugeWidth * (config.gaugeAspectRatio ?? 1.0);

            return _buildGaugeContent(
              config: config,
              dial: dial,
              needle: needle,
              rotationAngle: rotationAngle,
              gaugeWidth: gaugeWidth,
              gaugeHeight: gaugeHeight,
            );
          },
        );
      },
    );
  }

  /// Builds the actual gauge content (dial, needle, speed text, branding)
  /// without any positioning wrapper.
  Widget _buildGaugeContent({
    required GaugeCustomization config,
    required Dial dial,
    required Needle? needle,
    required double rotationAngle,
    required double gaugeWidth,
    required double gaugeHeight,
  }) {
    return IgnorePointer(
      child: SizedBox(
        width: gaugeWidth,
        height: gaugeHeight,
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
                  style: TextStyle(
                    color: config.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: (gaugeWidth * 0.12).clamp(10, 20),
                  ),
                ),
              ),

            /// ───── Branding ─────
            if (config.showBranding ?? true)
              Positioned(
                bottom: 0,
                child: Text(
                  "TURBOGAUGE",
                  style: TextStyle(
                    color: config.textColor,
                    fontSize: (gaugeWidth * 0.08).clamp(6, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
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

    final dialAngleSpan = dial.needleMaxAngle - dial.needleMinAngle;

    final angleDegrees = dial.needleMinAngle + (dial.totalSweep * progress) - (dialAngleSpan/2);

    return (angleDegrees * pi) / 180;
  }
}