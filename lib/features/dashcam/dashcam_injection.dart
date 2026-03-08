import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/dashcam_preferences.dart';
import 'data/datasources/camera_datasource.dart';
import 'data/datasources/camera_datasource_interface.dart';
import 'data/datasources/metadata_datasource.dart';
import 'data/datasources/metadata_datasource_interface.dart';
import 'data/datasources/storage_datasource.dart';
import 'data/datasources/storage_datasource_interface.dart';
import 'data/datasources/system_monitor_datasource.dart';
import 'data/datasources/system_monitor_interface.dart';
import 'data/repositories/dashcam_repository_impl.dart';
import 'domain/repositories/dashcam_repository.dart';
import 'domain/services/audio_session_service_interface.dart';
import 'data/services/audio_session_service_impl.dart';
import 'domain/services/video_export_service_interface.dart';
import 'data/services/ffmpeg_video_export_service.dart';
import 'domain/usecases/start_recording_usecase.dart';
import 'domain/usecases/stop_recording_usecase.dart';
import 'domain/usecases/rotate_segment_usecase.dart';
import 'domain/usecases/manage_storage_usecase.dart';
import 'domain/usecases/monitor_safety_usecase.dart';
import 'domain/usecases/export_video_usecase.dart';
import 'presentation/bloc/dashcam_bloc.dart';
import 'service/dashcam_platform_service.dart';

void initDashcamFeature(GetIt locator) {
  // ── Preferences ────────────────────────────────────────────
  locator.registerLazySingleton<DashcamPreferences>(
    () => DashcamPreferences(locator<SharedPreferences>()),
  );

  // ── Data Sources (interfaces → implementations) ────────────
  locator.registerLazySingleton<ICameraDataSource>(
    () => CameraDataSource(enableAudio: locator<DashcamPreferences>().enableMic),
  );
  locator.registerLazySingleton<IMetadataDataSource>(
    () => MetadataDataSource(),
  );
  locator.registerLazySingleton<IStorageDataSource>(
    () => StorageDataSource(),
  );
  locator.registerLazySingleton<ISystemMonitorDataSource>(
    () => SystemMonitorDataSource(),
  );

  // ── Services ───────────────────────────────────────────────
  locator.registerLazySingleton<IVideoExportService>(
    () => FFmpegVideoExportService(preferences: locator<DashcamPreferences>()),
  );
  locator.registerLazySingleton<IAudioSessionService>(
    () => AudioSessionServiceImpl(),
  );

  // ── Platform Service ───────────────────────────────────────
  locator.registerLazySingleton<DashcamPlatformService>(
    () => DashcamPlatformService(),
  );

  // ── Repository ─────────────────────────────────────────────
  locator.registerLazySingleton<DashcamRepository>(
    () => DashcamRepositoryImpl(
      cameraDataSource: locator<ICameraDataSource>(),
      metadataDataSource: locator<IMetadataDataSource>(),
      storageDataSource: locator<IStorageDataSource>(),
      videoExportService: locator<IVideoExportService>(),
      platformService: locator<DashcamPlatformService>(),
      preferences: locator<DashcamPreferences>(),
    ),
  );

  // ── Use Cases ──────────────────────────────────────────────
  locator.registerLazySingleton<StartRecordingUseCase>(
    () => StartRecordingUseCase(locator<DashcamRepository>()),
  );
  locator.registerLazySingleton<StopRecordingUseCase>(
    () => StopRecordingUseCase(locator<DashcamRepository>()),
  );
  locator.registerLazySingleton<RotateSegmentUseCase>(
    () => RotateSegmentUseCase(locator<DashcamRepository>()),
  );
  locator.registerLazySingleton<ManageStorageUseCase>(
    () => ManageStorageUseCase(locator<DashcamRepository>()),
  );
  locator.registerLazySingleton<MonitorSafetyUseCase>(
    () => MonitorSafetyUseCase(),
  );
  locator.registerLazySingleton<ExportVideoUseCase>(
    () => ExportVideoUseCase(locator<DashcamRepository>()),
  );

  // ── BLoC ───────────────────────────────────────────────────
  locator.registerFactory<DashcamBloc>(
    () => DashcamBloc(
      repository: locator<DashcamRepository>(),
      startRecording: locator<StartRecordingUseCase>(),
      stopRecording: locator<StopRecordingUseCase>(),
      rotateSegment: locator<RotateSegmentUseCase>(),
      manageStorage: locator<ManageStorageUseCase>(),
      monitorSafety: locator<MonitorSafetyUseCase>(),
      cameraDataSource: locator<ICameraDataSource>(),
      metadataDataSource: locator<IMetadataDataSource>(),
      systemMonitor: locator<ISystemMonitorDataSource>(),
      audioSessionService: locator<IAudioSessionService>(),
      preferences: locator<DashcamPreferences>(),
    ),
  );
}
