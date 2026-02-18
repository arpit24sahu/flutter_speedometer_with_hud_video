import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:equatable/equatable.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';

// ─── Events ───

abstract class LabsServiceEvent extends Equatable {
  const LabsServiceEvent();

  @override
  List<Object?> get props => [];
}

/// Load (or reload) both processing & processed file lists.
class LoadFiles extends LabsServiceEvent {
  const LoadFiles();
}

/// Delete a processing task (recorded video) by id.
class DeleteProcessingTask extends LabsServiceEvent {
  final String id;
  final String? videoFilePath;

  const DeleteProcessingTask({required this.id, this.videoFilePath});

  @override
  List<Object?> get props => [id, videoFilePath];
}

/// Delete a processed task (exported video) by id.
class DeleteProcessedTask extends LabsServiceEvent {
  final String id;
  final String? videoFilePath;

  const DeleteProcessedTask({required this.id, this.videoFilePath});

  @override
  List<Object?> get props => [id, videoFilePath];
}

// ─── State ───

class LabsServiceState extends Equatable {
  final List<ProcessingTask> processingTasks;
  final List<ProcessedTask> processedTasks;
  final bool isLoading;

  const LabsServiceState({
    this.processingTasks = const [],
    this.processedTasks = const [],
    this.isLoading = false,
  });

  LabsServiceState copyWith({
    List<ProcessingTask>? processingTasks,
    List<ProcessedTask>? processedTasks,
    bool? isLoading,
  }) {
    return LabsServiceState(
      processingTasks: processingTasks ?? this.processingTasks,
      processedTasks: processedTasks ?? this.processedTasks,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        processingTasks,
        processedTasks,
        isLoading,
      ];
}

// ─── Bloc ───

class LabsServiceBloc extends Bloc<LabsServiceEvent, LabsServiceState> {
  final LabsService labsService;

  LabsServiceBloc({
    required this.labsService,
  }) : super(const LabsServiceState()) {
    on<LoadFiles>(_onLoadFiles);
    on<DeleteProcessingTask>(_onDeleteProcessingTask);
    on<DeleteProcessedTask>(_onDeleteProcessedTask);
  }

  Future<void> _onLoadFiles(
    LoadFiles event,
    Emitter<LabsServiceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    await labsService.init();

    final processing = labsService.getAllProcessingTasks();
    final processed = labsService.getAllProcessedTasks();

    emit(state.copyWith(
      processingTasks: processing,
      processedTasks: processed,
      isLoading: false,
    ));
  }

  Future<void> _onDeleteProcessingTask(
    DeleteProcessingTask event,
    Emitter<LabsServiceState> emit,
  ) async {
    // Delete video file if it exists
    if (event.videoFilePath != null) {
      final file = File(event.videoFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await labsService.deleteProcessingTask(event.id);

    // Reload lists
    final processing = labsService.getAllProcessingTasks();
    emit(state.copyWith(processingTasks: processing));
  }

  Future<void> _onDeleteProcessedTask(
    DeleteProcessedTask event,
    Emitter<LabsServiceState> emit,
  ) async {
    // Delete video file if it exists
    if (event.videoFilePath != null) {
      final file = File(event.videoFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await labsService.deleteProcessedTask(event.id);

    // Reload lists
    final processed = labsService.getAllProcessedTasks();
    emit(state.copyWith(processedTasks: processed));
  }
}
