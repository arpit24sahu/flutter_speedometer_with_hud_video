import 'package:flutter/material.dart';

abstract class SettingsEvent {}

class LoadSettings extends SettingsEvent {}

class ToggleUnitSystem extends SettingsEvent {}

class ChangeSpeedometerColor extends SettingsEvent {
  final Color color;

  ChangeSpeedometerColor(this.color);
}

class ChangeBackgroundColor extends SettingsEvent {
  final Color color;

  ChangeBackgroundColor(this.color);
}

class ToggleDarkMode extends SettingsEvent {}