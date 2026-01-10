import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:speedometer/core/theme/app_theme.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_bloc.dart';
import 'package:speedometer/presentation/bloc/video_recorder_bloc.dart';
import 'package:speedometer/presentation/screens/home_screen.dart';

import '../features/premium/bloc/premium_bloc.dart';

class PlaneSpeedometerApp extends StatelessWidget {
  const PlaneSpeedometerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SpeedometerBloc>(create: (_) => getIt<SpeedometerBloc>()),
        BlocProvider<OverlayGaugeConfigurationBloc>(
          create: (_) => getIt<OverlayGaugeConfigurationBloc>(),
        ),
        BlocProvider<SettingsBloc>(create: (_) => getIt<SettingsBloc>()),
        BlocProvider<PremiumBloc>(
          create: (_) => getIt<PremiumBloc>()..add(InitializePremium()),
        ),
      ],
      child: GetMaterialApp(
        title: 'Plane Speedometer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
