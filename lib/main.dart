import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';
import 'package:speedometer/firebase_options.dart';
import 'package:speedometer/presentation/app.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:speedometer/features/processing/models/processing_job.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:speedometer/services/app_initialization_tracker.dart';
import 'package:speedometer/services/hive_service.dart';
import 'package:speedometer/services/misc_service.dart';

void main() async {
  await initializeApp();
  runApp(const PlaneSpeedometerApp());
  print("Done running runApp");
}

Future<void> initializeApp()async{
  DateTime startTime = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if(!kDebugMode){
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      AnalyticsService().recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      AnalyticsService().recordError(error, stack, fatal: true);
      return true;
    };
  }

  
  await Hive.initFlutter();
  Hive.registerAdapter(PositionDataAdapter());
  Hive.registerAdapter(ProcessingJobAdapter());
  Hive.registerAdapter(ProcessingTaskAdapter());
  Hive.registerAdapter(ProcessedTaskAdapter());
  await HiveService().init();
  await LabsService().init();

  PackageInfoService().init();
  DeviceInfoService().init();
  
  await initializeDependencies();

  AppInitializationTracker().track(startTime);
}

