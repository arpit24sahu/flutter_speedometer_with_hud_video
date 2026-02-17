import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';

/// Singleton service managing ProcessingTask and ProcessedTask Hive boxes.
class LabsService {
  LabsService._internal();
  static final LabsService _instance = LabsService._internal();
  factory LabsService() => _instance;

  static const String _processingTaskBoxName = 'processing_task';
  static const String _processedTaskBoxName = 'processed_task';

  late final Box<ProcessingTask> processingTaskBox;
  late final Box<ProcessedTask> processedTaskBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    processingTaskBox = await Hive.openBox<ProcessingTask>(_processingTaskBoxName);
    processedTaskBox = await Hive.openBox<ProcessedTask>(_processedTaskBoxName);
    _initialized = true;
  }

  // ─── ID Generation (millisecond-based, sortable by time) ───

  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ─── ProcessingTask CRUD ───

  Future<void> saveProcessingTask(ProcessingTask task) async {
    if (task.id == null) return;
    await processingTaskBox.put(task.id, task);
  }

  List<ProcessingTask> getAllProcessingTasks() {
    final tasks = processingTaskBox.values.toList();
    // Sort descending by id (timestamp-based)
    tasks.sort((a, b) => (b.id ?? '').compareTo(a.id ?? ''));
    return tasks;
  }

  ProcessingTask? getProcessingTask(String id) {
    return processingTaskBox.get(id);
  }

  Future<void> deleteProcessingTask(String id) async {
    await processingTaskBox.delete(id);
  }

  // ─── ProcessedTask CRUD ───

  Future<void> saveProcessedTask(ProcessedTask task) async {
    if (task.id == null) return;
    await processedTaskBox.put(task.id, task);
  }

  List<ProcessedTask> getAllProcessedTasks() {
    final tasks = processedTaskBox.values.toList();
    tasks.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return tasks;
  }

  ProcessedTask? getProcessedTask(String id) {
    return processedTaskBox.get(id);
  }

  Future<void> deleteProcessedTask(String id) async {
    await processedTaskBox.delete(id);
  }

  // ─── Helpers ───

  /// Creates a ProcessingTask from recording data and saves it.
  Future<ProcessingTask> createFromRecording({
    required String videoFilePath,
    required Map<int, PositionData> positionData,
    double lengthInSeconds = 0,
  }) async {
    final id = generateId();
    final file = File(videoFilePath);
    double sizeInKb = 0;


    if (await file.exists()) {
      final stat = await file.stat();
      sizeInKb = stat.size / 1024.0;
    }

    final task = ProcessingTask(
      id: id,
      name: 'Recording_$id',
      videoFilePath: videoFilePath,
      positionData: positionData,
      sizeInKb: sizeInKb,
      lengthInSeconds: lengthInSeconds,
    );

    await saveProcessingTask(task);
    return task;
  }
}
