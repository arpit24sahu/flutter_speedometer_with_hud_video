import 'package:get_it/get_it.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/core/services/camera_service.dart';
import 'package:speedometer/core/services/sensors_service.dart';
import 'package:speedometer/features/files/bloc/files_bloc.dart';
import 'package:speedometer/features/premium/bloc/premium_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer/services/hive_service.dart';

import '../features/analytics/di/analytics_injection.dart';
import '../features/labs/presentation/bloc/gauge_customization_bloc.dart';
import '../features/premium/di/premium_injection.dart';
import '../features/premium/repository/purchase_repository.dart';
import '../features/premium/service/purchase_service.dart';
import '../packages/gal.dart';
import '../presentation/bloc/overlay_gauge_configuration_bloc.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  initPremiumFeature();
  await initAnalyticsFeature();
  // Services
  getIt.registerLazySingleton<GalService>(() => GalService());
  getIt.registerLazySingleton<LocationService>(() => LocationService());
  getIt.registerLazySingleton<CameraService>(() => CameraServiceImpl());
  getIt.registerLazySingleton<SensorsService>(() => SensorsServiceImpl());



  // BLoCs
  getIt.registerFactory<SpeedometerBloc>(() => SpeedometerBloc(
        locationService: getIt<LocationService>(),
        sensorsService: getIt<SensorsService>(),
      ));

  getIt.registerFactory<OverlayGaugeConfigurationBloc>(() => OverlayGaugeConfigurationBloc());

  getIt.registerFactory<SettingsBloc>(() => SettingsBloc(
    sharedPreferences: getIt<SharedPreferences>(),
  ));

  getIt.registerFactory<FilesBloc>(() => FilesBloc());
  getIt.registerFactory<GaugeCustomizationBloc>(() => GaugeCustomizationBloc());

  getIt.registerSingleton<HiveService>(HiveService()..init());
}