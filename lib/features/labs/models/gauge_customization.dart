import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../data/gauge_options.dart';

// ─── Enums ───

enum DialStyle { analog, digital }

enum AssetType { asset, network, memory, widget }

// ─── 3×3 Gauge Placement ───

enum GaugePlacement {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

extension GaugePlacementExt on GaugePlacement {
  String get displayName {
    switch (this) {
      case GaugePlacement.topLeft: return 'Top Left';
      case GaugePlacement.topCenter: return 'Top Center';
      case GaugePlacement.topRight: return 'Top Right';
      case GaugePlacement.centerLeft: return 'Center Left';
      case GaugePlacement.center: return 'Center';
      case GaugePlacement.centerRight: return 'Center Right';
      case GaugePlacement.bottomLeft: return 'Bottom Left';
      case GaugePlacement.bottomCenter: return 'Bottom Center';
      case GaugePlacement.bottomRight: return 'Bottom Right';
    }
  }

  IconData get icon {
    switch (this) {
      case GaugePlacement.topLeft: return Icons.north_west;
      case GaugePlacement.topCenter: return Icons.north;
      case GaugePlacement.topRight: return Icons.north_east;
      case GaugePlacement.centerLeft: return Icons.west;
      case GaugePlacement.center: return Icons.center_focus_strong;
      case GaugePlacement.centerRight: return Icons.east;
      case GaugePlacement.bottomLeft: return Icons.south_west;
      case GaugePlacement.bottomCenter: return Icons.south;
      case GaugePlacement.bottomRight: return Icons.south_east;
    }
  }

  /// FFmpeg overlay position expression based on placement.
  /// Uses main_w, main_h (main video) and overlay_w, overlay_h (gauge).
  String overlayPosition({int margin = 20}) {
    switch (this) {
      case GaugePlacement.topLeft:
        return 'x=$margin:y=$margin';
      case GaugePlacement.topCenter:
        return 'x=(main_w-overlay_w)/2:y=$margin';
      case GaugePlacement.topRight:
        return 'x=main_w-overlay_w-$margin:y=$margin';
      case GaugePlacement.centerLeft:
        return 'x=$margin:y=(main_h-overlay_h)/2';
      case GaugePlacement.center:
        return 'x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2';
      case GaugePlacement.centerRight:
        return 'x=main_w-overlay_w-$margin:y=(main_h-overlay_h)/2';
      case GaugePlacement.bottomLeft:
        return 'x=$margin:y=main_h-overlay_h-$margin';
      case GaugePlacement.bottomCenter:
        return 'x=(main_w-overlay_w)/2:y=main_h-overlay_h-$margin';
      case GaugePlacement.bottomRight:
        return 'x=main_w-overlay_w-$margin:y=main_h-overlay_h-$margin';
    }
  }

  Positioned buildPositioned({
    required Widget child,
    required double gaugeSize,
    required Size screenSize,
    double margin = 20,
  }) {
    switch (this) {
      case GaugePlacement.topLeft:
        return Positioned(
          top: margin,
          left: margin,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.topCenter:
        return Positioned(
          top: margin,
          left: (screenSize.width - gaugeSize) / 2,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.topRight:
        return Positioned(
          top: margin,
          right: margin,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.centerLeft:
        return Positioned(
          top: (screenSize.height - gaugeSize) / 2,
          left: margin,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.center:
        return Positioned(
          top: (screenSize.height - gaugeSize) / 2,
          left: (screenSize.width - gaugeSize) / 2,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.centerRight:
        return Positioned(
          top: (screenSize.height - gaugeSize) / 2,
          right: margin,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.bottomLeft:
        return Positioned(
          bottom: margin,
          left: margin,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.bottomCenter:
        return Positioned(
          bottom: margin,
          left: (screenSize.width - gaugeSize) / 2,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );

      case GaugePlacement.bottomRight:
        return Positioned(
          bottom: margin,
          right: margin,
          width: gaugeSize,
          height: gaugeSize,
          child: child,
        );
    }
  }
}

// ─── Dial ───

class Dial {
  final String? id;
  final String? name;
  final DialStyle? style;
  final AssetType? assetType;
  final String? path;
  final int? sizeInKb;
  final double? aspectRatio;
  final double needleMinAngle;
  final double needleMaxAngle;
  final bool? showMarkings;
  final bool? showMarkingValues;
  final String? markingColor;
  final String? dialColor;
  final Map<String, dynamic>? extra;

  const Dial({
    this.id,
    this.name,
    this.style,
    this.assetType,
    this.path,
    this.sizeInKb,
    this.aspectRatio = 1.0,
    this.needleMinAngle = 0,
    this.needleMaxAngle = 270,
    this.showMarkings,
    this.showMarkingValues,
    this.markingColor,
    this.dialColor,
    this.extra,
  });

  /// Total angular sweep of the gauge in degrees.
  double get totalSweep => needleMaxAngle - needleMinAngle;

  /// Half of the angular sweep (used for centering the needle).
  double get halfSweep => totalSweep / 2;

  @override
  String toString() =>
      'Dial(id: $id, name: $name, style: $style, path: $path, '
      'sweep: $needleMinAngle→$needleMaxAngle)';
}

// ─── Needle ───

class Needle {
  final String? id;
  final String? name;
  final AssetType? assetType;
  final String? path;
  final int? sizeInKb;
  final double? aspectRatio;
  final String? color;

  /// The rotation origin of the needle.
  /// (0,0) = center of the needle image square.
  final Offset? pivotPoint;

  final Map<String, dynamic>? extra;

  const Needle({
    this.id,
    this.name,
    this.assetType,
    this.path,
    this.sizeInKb,
    this.aspectRatio = 1.0,
    this.color,
    this.pivotPoint = Offset.zero,
    this.extra,
  });

  @override
  String toString() => 'Needle(id: $id, name: $name, path: $path, color: $color)';
}

// ─── GaugeCustomizationOption ───

/// One choosable gauge option (a dial + its compatible needles).
class GaugeCustomizationOption {
  final String? id, name;
  final Dial? dial;
  final List<Needle>? needles;
  final Map<String, dynamic>? extra;

  const GaugeCustomizationOption({
    this.id,
    this.name,
    this.dial,
    this.needles,
    this.extra,
  });

  /// Whether this option has at least one needle.
  bool get hasNeedles => needles != null && needles!.isNotEmpty;

  @override
  String toString() =>
      'GaugeCustomizationOption(id: $id, name: $name} dial: ${dial?.id}, '
      'needles: ${needles?.length ?? 0})';
}

// ─── GaugeCustomizationSelected ───

/// The user's final selection of gauge settings for export.
class GaugeCustomization extends Equatable {
  final String? id;
  final Dial? dial;
  final Needle? needle;
  final DialStyle? dialStyle;
  final bool? showSpeed;
  final bool? showBranding;
  final bool? isMetric;
  final Color? textColor;
  /// Aspect ratio of the full gauge area (height / width). Default 7:5.
  final double? gaugeAspectRatio;

  /// Size of gauge relative to video width. Default 0.25 (25%).
  final double? sizeFactor;

  /// Placement key (corresponds to LabsGaugePlacement.name).
  final GaugePlacement? placement;

  final Map<String, dynamic>? extra;

  const GaugeCustomization({
    this.id,
    this.dial = defaultDial,
    this.needle = defaultNeedle,
    this.dialStyle = DialStyle.analog,
    this.showSpeed = true,
    this.showBranding = true,
    this.isMetric = false,
    this.textColor = const Color(0xFFFFFFFF),
    this.gaugeAspectRatio = 1.4, // 7/5
    this.sizeFactor = 1,
    this.placement = GaugePlacement.topRight,
    this.extra,
  });

  GaugeCustomization copyWith({
    String? id,
    Dial? dial,
    Needle? needle,
    DialStyle? dialStyle,
    bool? showSpeed,
    bool? showBranding,
    bool? isMetric,
    Color? textColor,
    double? gaugeAspectRatio,
    double? sizeFactor,
    GaugePlacement? placement,
    Map<String, dynamic>? extra,
  }) {
    return GaugeCustomization(
      id: id ?? this.id,
      dial: dial ?? this.dial,
      needle: needle ?? this.needle,
      dialStyle: dialStyle ?? this.dialStyle,
      showSpeed: showSpeed ?? this.showSpeed,
      showBranding: showBranding ?? this.showBranding,
      isMetric: isMetric ?? this.isMetric,
      textColor: textColor ?? this.textColor,
      gaugeAspectRatio: gaugeAspectRatio ?? this.gaugeAspectRatio,
      sizeFactor: sizeFactor ?? this.sizeFactor,
      placement: placement ?? this.placement,
      extra: extra ?? this.extra,
    );
  }

  /// Resolve the GaugePlacement from the placement field.
  GaugePlacement get labsPlacement {
    return placement ?? GaugePlacement.topRight;
  }

  /// Converts the textColor to an FFmpeg-compatible hex string (e.g. 'FFFFFF').
  String get textColorHex {
    final c = textColor ?? const Color(0xFFFFFFFF);
    return '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}';
  }

  @override
  String toString() =>
      'GaugeCustomization(dial: ${dial?.id}, needle: ${needle?.id}, '
      'isMetric: $isMetric, sizeFactor: $sizeFactor, placement: $placement, '
      'textColor: $textColor)';

  @override
  List<Object?> get props => [
    id,
    dial,
    needle,
    dialStyle,
    showSpeed,
    showBranding,
    isMetric,
    textColor,
    gaugeAspectRatio,
    sizeFactor,
    placement,
    extra,
  ];
}
