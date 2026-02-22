import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';
import 'package:speedometer/firebase_options.dart';
import 'package:speedometer/presentation/app.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/data/gauge_options.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:speedometer/services/app_initialization_tracker.dart';
import 'package:speedometer/services/hive_service.dart';
import 'package:speedometer/services/misc_service.dart';
import 'package:speedometer/services/notification_service.dart';
import 'package:speedometer/services/remote_asset_service.dart';
import 'package:speedometer/services/scheduled_notification_service.dart';

import 'features/badges/badge_service.dart';

void main() async {
  final criticalStart = DateTime.now();
  await initializeCriticalServices();
  final criticalMs = DateTime.now().difference(criticalStart).inMilliseconds;
  debugPrint('⚡ Critical init completed in ${criticalMs}ms');

  runApp(const PlaneSpeedometerApp());

  // Non-critical services initialize in the background after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final bgStart = DateTime.now();
    await initializeRemainingServices();
    final bgMs = DateTime.now().difference(bgStart).inMilliseconds;
    debugPrint('⚡ Remaining init completed in ${bgMs}ms');
    AppInitializationTracker().track(criticalStart);
  });
}

/// Services that MUST finish before the app can render anything.
/// Keep this as lean as possible — every millisecond here blocks the splash.
Future<void> initializeCriticalServices() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kDebugMode) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      AnalyticsService().recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      AnalyticsService().recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Hive + DI are the minimum to boot the widget tree.
  await Hive.initFlutter();
  Hive.registerAdapter(PositionDataAdapter());
  Hive.registerAdapter(ProcessingTaskAdapter());
  Hive.registerAdapter(ProcessedTaskAdapter());
  await HiveService().init();
  await LabsService().init();

  await initializeDependencies();
}

/// Everything else — notifications, remote assets, device info.
/// These run after `runApp()` so the user sees UI immediately.
Future<void> initializeRemainingServices() async {
  PackageInfoService().init();
  DeviceInfoService().init();

  await NotificationService().initialize();
  await ScheduledNotificationService().setupRecurringNotifications();

  await RemoteAssetService().init();
  unawaited(RemoteAssetService().preloadUrls(getAllRemoteAssetUrls()));
}
