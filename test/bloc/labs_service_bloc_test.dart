import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/presentation/bloc/labs_service_bloc.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';

class MockLabsService extends Mock implements LabsService {}

void main() {
  group('LabsServiceBloc', () {
    late LabsServiceBloc labsServiceBloc;
    late MockLabsService mockLabsService;

    final mockProcessingTasks = [
      ProcessingTask(
        id: '1',
        name: 'Task 1',
        videoFilePath: '/path/to/video1.mp4',
        positionData: const {},
      ),
    ];

    final mockProcessedTasks = [
      ProcessedTask(
        id: '1',
        name: 'Processed 1',
        savedVideoFilePath: '/path/to/processed1.mp4',
        createdAt: DateTime(2023, 1, 2),
      ),
    ];

    setUp(() {
      mockLabsService = MockLabsService();
      when(() => mockLabsService.init()).thenAnswer((_) async {});
      labsServiceBloc = LabsServiceBloc(labsService: mockLabsService);
    });

    tearDown(() {
      labsServiceBloc.close();
    });

    test('initial state is LabsServiceState()', () {
      expect(labsServiceBloc.state, const LabsServiceState());
    });

    test('emits [loading, loaded] when LoadTasks is added', () async {
      when(() => mockLabsService.getAllProcessingTasks())
          .thenReturn(mockProcessingTasks);
      when(() => mockLabsService.getAllProcessedTasks())
          .thenReturn(mockProcessedTasks);

      labsServiceBloc.add(const LoadTasks());

      await expectLater(
        labsServiceBloc.stream,
        emitsInOrder([
          const LabsServiceState(isLoading: true),
          LabsServiceState(
            isLoading: false,
            processingTasks: mockProcessingTasks,
            processedTasks: mockProcessedTasks,
          ),
        ]),
      );

      verify(() => mockLabsService.init()).called(1);
      verify(() => mockLabsService.getAllProcessingTasks()).called(1);
      verify(() => mockLabsService.getAllProcessedTasks()).called(1);
    });

    test('emits updated processing tasks when DeleteProcessingTask is added',
        () async {
      when(() => mockLabsService.deleteProcessingTask(any()))
          .thenAnswer((_) async {});
      when(() => mockLabsService.getAllProcessingTasks()).thenReturn([]);

      labsServiceBloc.add(const DeleteProcessingTask(id: '1'));

      await expectLater(
        labsServiceBloc.stream,
        emitsInOrder([
          const LabsServiceState(processingTasks: []),
        ]),
      );

      verify(() => mockLabsService.deleteProcessingTask('1')).called(1);
      verify(() => mockLabsService.getAllProcessingTasks()).called(1);
    });

    test('emits updated processed tasks when DeleteProcessedTask is added',
        () async {
      when(() => mockLabsService.deleteProcessedTask(any()))
          .thenAnswer((_) async {});
      when(() => mockLabsService.getAllProcessedTasks()).thenReturn([]);

      labsServiceBloc.add(const DeleteProcessedTask(id: '1'));

      await expectLater(
        labsServiceBloc.stream,
        emitsInOrder([
          const LabsServiceState(processedTasks: []),
        ]),
      );

      verify(() => mockLabsService.deleteProcessedTask('1')).called(1);
      verify(() => mockLabsService.getAllProcessedTasks()).called(1);
    });
  });
}
