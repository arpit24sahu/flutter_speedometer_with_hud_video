import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsState extends Equatable {
  final bool isMetric;
  final Color speedometerColor;
  final Color backgroundColor;
  final bool isDarkMode;

  const SettingsState({
    required this.isMetric,
    required this.speedometerColor,
    required this.backgroundColor,
    required this.isDarkMode,
  });

  factory SettingsState.initial() {
    return const SettingsState(
      isMetric: true,
      speedometerColor: Colors.red,
      backgroundColor: Colors.black,
      isDarkMode: true,
    );
  }

  SettingsState copyWith({
    bool? isMetric,
    Color? speedometerColor,
    Color? backgroundColor,
    bool? isDarkMode,
  }) {
    return SettingsState(
      isMetric: isMetric ?? this.isMetric,
      speedometerColor: speedometerColor ?? this.speedometerColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  @override
  List<Object?> get props => [
    isMetric,
    speedometerColor,
    backgroundColor,
    isDarkMode,
  ];
}