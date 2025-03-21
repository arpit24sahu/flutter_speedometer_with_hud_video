import 'package:flutter/material.dart';

class SettingsState {
  final bool isMetric;
  final Color speedometerColor;
  final Color backgroundColor;
  final bool isDarkMode;

  SettingsState({
    required this.isMetric,
    required this.speedometerColor,
    required this.backgroundColor,
    required this.isDarkMode,
  });

  factory SettingsState.initial() {
    return SettingsState(
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
}