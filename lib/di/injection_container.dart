import 'package:get_it/get_it.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/core/services/camera_service.dart';
import 'package:speedometer/core/services/sensors_service.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Services
  getIt.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  getIt.registerLazySingleton<CameraService>(() => CameraServiceImpl());
  getIt.registerLazySingleton<SensorsService>(() => SensorsServiceImpl());

  // BLoCs
  getIt.registerFactory<SpeedometerBloc>(() => SpeedometerBloc(
        locationService: getIt<LocationService>(),
        sensorsService: getIt<SensorsService>(),
      ));
  
  getIt.registerFactory<SettingsBloc>(() => SettingsBloc(
        sharedPreferences: getIt<SharedPreferences>(),
      ));
}