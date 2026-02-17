import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:speedometer/core/theme/app_theme.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/features/files/bloc/files_bloc.dart';
import 'package:speedometer/features/labs/presentation/bloc/gauge_customization_bloc.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_bloc.dart';
import 'package:speedometer/presentation/screens/onboarding_screen.dart';
import 'package:speedometer/services/deeplink_service.dart';

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
        BlocProvider<FilesBloc>(create: (_) => getIt<FilesBloc>()..add(RefreshFiles())),
        BlocProvider<GaugeCustomizationBloc>(create: (_) => getIt<GaugeCustomizationBloc>()),
      ],
      child: GetMaterialApp(
        navigatorKey: DeeplinkService.navigatorKey,
        title: 'TurboGauge',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const OnboardingScreen(),
      ),
    );
  }
}
