import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_event.dart';
import 'package:speedometer/presentation/bloc/settings/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SharedPreferences sharedPreferences;
  
  SettingsBloc({
    required this.sharedPreferences,
  }) : super(SettingsState.initial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleUnitSystem>(_onToggleUnitSystem);
    on<ChangeSpeedometerColor>(_onChangeSpeedometerColor);
    on<ChangeBackgroundColor>(_onChangeBackgroundColor);
    on<ToggleDarkMode>(_onToggleDarkMode);
    
    // Load settings when bloc is created
    add(LoadSettings());
  }

  void _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) {
    final isMetric = sharedPreferences.getBool('isMetric') ?? true;
    final speedometerColor = sharedPreferences.getInt('speedometerColor') ?? Colors.red.value;
    final backgroundColor = sharedPreferences.getInt('backgroundColor') ?? Colors.black.value;
    final isDarkMode = sharedPreferences.getBool('isDarkMode') ?? true;
    
    emit(state.copyWith(
      isMetric: isMetric,
      speedometerColor: Color(speedometerColor),
      backgroundColor: Color(backgroundColor),
      isDarkMode: isDarkMode,
    ));
  }

  void _onToggleUnitSystem(ToggleUnitSystem event, Emitter<SettingsState> emit) {
    final isMetric = !state.isMetric;
    sharedPreferences.setBool('isMetric', isMetric);
    emit(state.copyWith(isMetric: isMetric));
  }

  void _onChangeSpeedometerColor(ChangeSpeedometerColor event, Emitter<SettingsState> emit) {
    sharedPreferences.setInt('speedometerColor', event.color.value);
    emit(state.copyWith(speedometerColor: event.color));
  }

  void _onChangeBackgroundColor(ChangeBackgroundColor event, Emitter<SettingsState> emit) {
    sharedPreferences.setInt('backgroundColor', event.color.value);
    emit(state.copyWith(backgroundColor: event.color));
  }

  void _onToggleDarkMode(ToggleDarkMode event, Emitter<SettingsState> emit) {
    final isDarkMode = !state.isDarkMode;
    sharedPreferences.setBool('isDarkMode', isDarkMode);
    emit(state.copyWith(isDarkMode: isDarkMode));
  }
}