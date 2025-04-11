import 'package:get_it/get_it.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/core/services/camera_service.dart';
import 'package:speedometer/core/services/sensors_service.dart';
import 'package:speedometer/features/premium/bloc/premium_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer/presentation/bloc/video_recorder_bloc.dart';
import 'package:speedometer/presentation/widgets/video_recorder_service.dart';

import '../features/premium/repository/purchase_repository.dart';
import '../features/premium/service/purchase_service.dart';
import '../packages/gal.dart';
import '../presentation/bloc/overlay_gauge_configuration_bloc.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Services
  getIt.registerLazySingleton<GalService>(() => GalService());
  getIt.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  getIt.registerLazySingleton<CameraService>(() => CameraServiceImpl());
  getIt.registerLazySingleton<SensorsService>(() => SensorsServiceImpl());
  getIt.registerLazySingleton<PurchaseService>(() => PurchaseService());


  
  // Repositories
  getIt.registerLazySingleton<PurchaseRepository>(() => PurchaseRepository(getIt<PurchaseService>()));


  // BLoCs
  getIt.registerFactory<SpeedometerBloc>(() => SpeedometerBloc(
        locationService: getIt<LocationService>(),
        sensorsService: getIt<SensorsService>(),
      ));

  getIt.registerFactory<OverlayGaugeConfigurationBloc>(() => OverlayGaugeConfigurationBloc());

  getIt.registerFactory<SettingsBloc>(() => SettingsBloc(
    sharedPreferences: getIt<SharedPreferences>(),
  ));
  getIt.registerFactory<PremiumBloc>(() => PremiumBloc(
    getIt<PurchaseRepository>(),
  ));

}