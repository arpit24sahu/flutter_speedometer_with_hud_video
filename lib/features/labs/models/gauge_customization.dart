import 'package:flutter/material.dart';

// ─── Enums ───

enum DialStyle {
  analog,
  digital,
}

enum AssetType {
  asset,
  network,
  memory,
  widget,
}

// ─── 3×3 Gauge Placement ───

enum LabsGaugePlacement {
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

extension LabsGaugePlacementExt on LabsGaugePlacement {
  String get displayName {
    switch (this) {
      case LabsGaugePlacement.topLeft:
        return 'Top Left';
      case LabsGaugePlacement.topCenter:
        return 'Top Center';
      case LabsGaugePlacement.topRight:
        return 'Top Right';
      case LabsGaugePlacement.centerLeft:
        return 'Center Left';
      case LabsGaugePlacement.center:
        return 'Center';
      case LabsGaugePlacement.centerRight:
        return 'Center Right';
      case LabsGaugePlacement.bottomLeft:
        return 'Bottom Left';
      case LabsGaugePlacement.bottomCenter:
        return 'Bottom Center';
      case LabsGaugePlacement.bottomRight:
        return 'Bottom Right';
    }
  }

  IconData get icon {
    switch (this) {
      case LabsGaugePlacement.topLeft:
        return Icons.north_west;
      case LabsGaugePlacement.topCenter:
        return Icons.north;
      case LabsGaugePlacement.topRight:
        return Icons.north_east;
      case LabsGaugePlacement.centerLeft:
        return Icons.west;
      case LabsGaugePlacement.center:
        return Icons.center_focus_strong;
      case LabsGaugePlacement.centerRight:
        return Icons.east;
      case LabsGaugePlacement.bottomLeft:
        return Icons.south_west;
      case LabsGaugePlacement.bottomCenter:
        return Icons.south;
      case LabsGaugePlacement.bottomRight:
        return Icons.south_east;
    }
  }

  /// FFmpeg overlay position expression based on placement.
  /// Uses main_w, main_h (main video) and overlay_w, overlay_h (gauge).
  String overlayPosition({int margin = 20}) {
    switch (this) {
      case LabsGaugePlacement.topLeft:
        return 'x=$margin:y=$margin';
      case LabsGaugePlacement.topCenter:
        return 'x=(main_w-overlay_w)/2:y=$margin';
      case LabsGaugePlacement.topRight:
        return 'x=main_w-overlay_w-$margin:y=$margin';
      case LabsGaugePlacement.centerLeft:
        return 'x=$margin:y=(main_h-overlay_h)/2';
      case LabsGaugePlacement.center:
        return 'x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2';
      case LabsGaugePlacement.centerRight:
        return 'x=main_w-overlay_w-$margin:y=(main_h-overlay_h)/2';
      case LabsGaugePlacement.bottomLeft:
        return 'x=$margin:y=main_h-overlay_h-$margin';
      case LabsGaugePlacement.bottomCenter:
        return 'x=(main_w-overlay_w)/2:y=main_h-overlay_h-$margin';
      case LabsGaugePlacement.bottomRight:
        return 'x=main_w-overlay_w-$margin:y=main_h-overlay_h-$margin';
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
    this.id, this.name,
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
class GaugeCustomizationSelected {
  final String? id;
  final Dial? dial;
  final Needle? needle;
  final DialStyle? dialStyle;
  final bool? showSpeed;
  final bool? showBranding;
  final bool? imperial;

  /// Aspect ratio of the full gauge area (height / width). Default 7:5.
  final double? gaugeAspectRatio;

  /// Size of gauge relative to video width. Default 0.25 (25%).
  final double? sizeFactor;

  /// Placement key (corresponds to LabsGaugePlacement.name).
  final String? placement;

  final Map<String, dynamic>? extra;

  const GaugeCustomizationSelected({
    this.id,
    this.dial,
    this.needle,
    this.dialStyle = DialStyle.analog,
    this.showSpeed = true,
    this.showBranding = true,
    this.imperial = false,
    this.gaugeAspectRatio = 1.4, // 7/5
    this.sizeFactor = 0.25,
    this.placement = 'bottomRight',
    this.extra,
  });

  GaugeCustomizationSelected copyWith({
    String? id,
    Dial? dial,
    Needle? needle,
    DialStyle? dialStyle,
    bool? showSpeed,
    bool? showBranding,
    bool? imperial,
    double? gaugeAspectRatio,
    double? sizeFactor,
    String? placement,
    Map<String, dynamic>? extra,
  }) {
    return GaugeCustomizationSelected(
      id: id ?? this.id,
      dial: dial ?? this.dial,
      needle: needle ?? this.needle,
      dialStyle: dialStyle ?? this.dialStyle,
      showSpeed: showSpeed ?? this.showSpeed,
      showBranding: showBranding ?? this.showBranding,
      imperial: imperial ?? this.imperial,
      gaugeAspectRatio: gaugeAspectRatio ?? this.gaugeAspectRatio,
      sizeFactor: sizeFactor ?? this.sizeFactor,
      placement: placement ?? this.placement,
      extra: extra ?? this.extra,
    );
  }

  /// Resolve the LabsGaugePlacement from the placement string.
  LabsGaugePlacement get labsPlacement {
    return LabsGaugePlacement.values.firstWhere(
      (p) => p.name == placement,
      orElse: () => LabsGaugePlacement.bottomRight,
    );
  }

  @override
  String toString() =>
      'GaugeCustomizationSelected(dial: ${dial?.id}, needle: ${needle?.id}, '
      'imperial: $imperial, sizeFactor: $sizeFactor, placement: $placement)';
}
