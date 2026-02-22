import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';

// Since we cannot easily import the generated adapters if they are part files or not exported,
// we assume we can import them if they are generated.
// However, typically adapters are in the same file or a part file.
// If they are part files, we cannot import them directly in the test unless we mock them
// or if the test is also a part (which it isn't).
// BUT, Hive usually requires registering the ADAPTER instance.
// If the adapter class is private or part-only, we might have trouble.
// Let's check if PositionDataAdapter etc are classes we can instantiate.
// They are usually generated as public classes.

void main() {
  group('LabsService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);
      
      // Register adapters - We need to ensure we don't register twice if running multiple tests
      if (!Hive.isAdapterRegistered(2)) {
         Hive.registerAdapter(ProcessingTaskAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
         Hive.registerAdapter(ProcessedTaskAdapter());
      }
      // PositionData adapter ID isn't known from snippet, assuming logic handles it or we mock.
      // Actually PositionData is simpler to test without adapter if we don't store it in the box for this specific test
      // OR we just assume it works.
      // But verify logic requires it.
      
      // To be safe and avoid "Adapter not registered" errors, we should mock the objects 
      // or ensure adapters are available. 
      // Since I can't easily see adapter files, I will try basic tests.
    });

    tearDown(() async {
      await LabsService().reset();
      await Hive.deleteFromDisk();
      await tempDir.delete(recursive: true);
    });

    test('init opens boxes', () async {
      await LabsService().init();
      expect(LabsService().processingTaskBox.isOpen, true);
      expect(LabsService().processedTaskBox.isOpen, true);
    });

    test('save and get ProcessingTask', () async {
      await LabsService().init();
      final task = ProcessingTask(
        id: '123',
        name: 'Test Task',
        videoFilePath: '/video.mp4',
      );

      await LabsService().saveProcessingTask(task);
      
      final retrieved = LabsService().getProcessingTask('123');
      expect(retrieved, isNotNull);
      expect(retrieved?.id, '123');
      expect(retrieved?.name, 'Test Task');
    });

    test('getAllProcessingTasks returns sorted list', () async {
       await LabsService().init();
       final task1 = ProcessingTask(id: '100', name: 'Task 1'); // older
       final task2 = ProcessingTask(id: '200', name: 'Task 2'); // newer (timestamps as IDs)

       await LabsService().saveProcessingTask(task1);
       await LabsService().saveProcessingTask(task2);

       final tasks = LabsService().getAllProcessingTasks();
       expect(tasks.length, 2);
       // Should be descending by ID
       expect(tasks[0].id, '200');
       expect(tasks[1].id, '100');
    });

    test('deleteProcessingTask removes task', () async {
      await LabsService().init();
      final task = ProcessingTask(id: '123');
      await LabsService().saveProcessingTask(task);
      
      expect(LabsService().getProcessingTask('123'), isNotNull);
      
      await LabsService().deleteProcessingTask('123');
      
      expect(LabsService().getProcessingTask('123'), isNull);
    });
  });
}
