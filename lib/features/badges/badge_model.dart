import 'package:flutter/material.dart';
import 'badge_id.dart';

class AppBadge {
  final BadgeId id;
  final String name;
  final String description;
  final IconData? icon;
  final String? imageUrl;
  final Color color;
  final int tier;
  final int level;
  final int attainabilityScore; // Lower = easier to attain

  const AppBadge({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.imageUrl,
    required this.color,
    required this.tier,
    required this.level,
    required this.attainabilityScore,
  }) : assert(icon != null || imageUrl != null, 'Either icon or imageUrl must be provided');

  Map<String, dynamic> toJson() => {
        'id': id.name,
        'name': name,
        'description': description,
        'icon': icon?.codePoint,
        'imageUrl': imageUrl,
        'color': color.value,
        'tier': tier,
        'level': level,
        'attainabilityScore': attainabilityScore,
      };

  factory AppBadge.fromJson(Map<String, dynamic> json) => AppBadge(
        id: BadgeId.values.firstWhere((e) => e.name == json['id']),
        name: json['name'] as String,
        description: json['description'] as String,
        icon: json['icon'] != null ? IconData(json['icon'] as int, fontFamily: 'MaterialIcons') : null,
        imageUrl: json['imageUrl'] as String?,
        color: Color(json['color'] as int),
        tier: json['tier'] as int,
        level: json['level'] as int,
        attainabilityScore: json['attainabilityScore'] as int,
      );

  AppBadge copyWith({
    BadgeId? id,
    String? name,
    String? description,
    IconData? icon,
    String? imageUrl,
    Color? color,
    int? tier,
    int? level,
    int? attainabilityScore,
  }) {
    return AppBadge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      color: color ?? this.color,
      tier: tier ?? this.tier,
      level: level ?? this.level,
      attainabilityScore: attainabilityScore ?? this.attainabilityScore,
    );
  }
}
