// hive_service.dart
import 'package:hive_ce/hive.dart';
import 'package:speedometer/features/processing/models/processing_job.dart';

class HiveBoxKeys {
  static const String pendingJobs = 'pendingJobs';
  static const String completedJobs = 'completedJobs';
  static const String failedJobs = 'failedJobs';
}

class HiveService {
  HiveService._internal();

  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;

  bool _initialized = false;
  bool _initializing = false;

  static const String pendingBoxName = HiveBoxKeys.pendingJobs;
  static const String completedBoxName = HiveBoxKeys.completedJobs;
  static const String failedBoxName = HiveBoxKeys.failedJobs;

  late final Box<ProcessingJob> pendingBox;
  late final Box<ProcessingJob> completedBox;
  late final Box<ProcessingJob> failedBox;

  Future<void> init() async {
    if(_initialized || _initializing) return;
    _initializing = true;
    pendingBox = await Hive.openBox<ProcessingJob>(pendingBoxName);
    completedBox = await Hive.openBox<ProcessingJob>(completedBoxName);
    failedBox = await Hive.openBox<ProcessingJob>(failedBoxName);
    _initialized = true;
    _initializing = false;
  }
}