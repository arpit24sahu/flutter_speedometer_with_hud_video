import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import '../../../../utils.dart';
import '../models/processing_job.dart';
import '../repository/processing_repository.dart';

// Events
abstract class ProcessorEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartProcessing extends ProcessorEvent {
  final ProcessingJob? job;
  StartProcessing({this.job});

  @override
  List<Object?> get props => [job];
}

class _UpdateProcessingProgress extends ProcessorEvent {
  final double? progress;
  _UpdateProcessingProgress({this.progress});

  @override
  List<Object?> get props => [progress];
}

class _ProcessingActionCompleted extends ProcessorEvent {
    final ProcessingJob job;
    final String outputPath;
    final int fileSizeKb;
    _ProcessingActionCompleted(this.job, this.outputPath, this.fileSizeKb);
    
    @override
    List<Object?> get props => [job, outputPath, fileSizeKb];
}

class _ProcessingActionFailed extends ProcessorEvent {
    final ProcessingJob job;
    final String error;
    _ProcessingActionFailed(this.job, this.error);
    
    @override
    List<Object?> get props => [job, error];
}

// State
enum ProcessorStatus { idle, ongoing, success, failure }

class ProcessorState extends Equatable {
  final ProcessorStatus status;
  final ProcessingJob? currentJob;
  final double progress;
  final String? error;
  final String? successMessage, failureMessage;

  const ProcessorState({
    this.status = ProcessorStatus.idle,
    this.currentJob,
    this.progress = 0.0,
    this.error,
    this.successMessage, this.failureMessage
  });

  ProcessorState copyWith({
    ProcessorStatus? status,
    ProcessingJob? currentJob,
    double? progress,
    String? error,
    String? successMessage, failureMessage
  }) {
    return ProcessorState(
      status: status ?? this.status,
      currentJob: currentJob ?? this.currentJob,
      progress: progress ?? this.progress,
      error: error,
      successMessage: successMessage, // they should not copy from the original
      failureMessage: failureMessage // they are onetime events
    );
  }

  @override
  List<Object?> get props => [status, currentJob, progress, error, successMessage, failureMessage];
}

class ProcessorBloc extends Bloc<ProcessorEvent, ProcessorState> {
  final ProcessingRepository repository;

  ProcessorBloc({required this.repository}) : super(const ProcessorState()) {
    on<StartProcessing>(_onStartProcessing);
    on<_UpdateProcessingProgress>(_onUpdateProgress);
    on<_ProcessingActionCompleted>(_onProcessingCompleted);
    on<_ProcessingActionFailed>(_onProcessingFailed);
  }

  Future<void> _onStartProcessing(StartProcessing event, Emitter<ProcessorState> emit) async {
    if (state.status == ProcessorStatus.ongoing && event.job != null) {
      // retry it after 10 seconds.
      if(event.job != null) {
        await Future.delayed(Duration(seconds: 10), (){
          add(event);
        });
      }
      return;
    }

    final job = event.job ?? repository.getNextPendingJob();
    if (job == null) {
      emit(state.copyWith(status: ProcessorStatus.idle, currentJob: null));
      return;
    }

    emit(state.copyWith(status: ProcessorStatus.ongoing, currentJob: job, progress: 0));

    try {
        final placement = _parsePlacement(job.gaugePlacement);
        //
        Future<void> onUpdateProgress(double progress)async{
          print("Progress: $progress");
          add(_UpdateProcessingProgress(progress: progress));
          // emit(state.copyWith(status: ProcessorStatus.ongoing, currentJob: job, progress: 0));
        }
        Future<void> onProcessSuccess(String resultPath, double size)async{
          add(_ProcessingActionCompleted(job, resultPath, size ~/ 1024));
          // emit(state.copyWith(status: ProcessorStatus.ongoing, currentJob: job, progress: 0));
        }
        Future<void> onProcessFailure(String error)async{
          add(_ProcessingActionFailed(job, error));
        }

        // Note: processChromaKeyVideo currently doesn't support cancellation 
        // effectively, so "Pause" will only take effect after this finishes.
        final resultPath = await processChromaKeyVideo(
            backgroundPath: job.videoFilePath,
            foregroundPath: job.overlayFilePath,
            placement: placement,
            relativeSize: job.relativeSize,
            onUpdateProgress: onUpdateProgress,
            onProcessSuccess: onProcessSuccess,
            onProcessFailure: onProcessFailure
        );

        // if (resultPath != null) {
        //      final file = File(resultPath);
        //      int size = 0;
        //      print("File Exists: ${await file.exists()}");
        //      if(await file.exists()){
        //        print("File Exists: ${await file.length()}");
        //        size = await file.length();
        //      }
        //      add(_ProcessingActionCompleted(job, resultPath, size ~/ 1024));
        // } else {
        //      add(_ProcessingActionFailed(job, "Unknown error returned null path"));
        // }
    } catch (e) {
        add(_ProcessingActionFailed(job, e.toString()));
    }
  }
  
  GaugePlacement _parsePlacement(String name) {
      return GaugePlacement.values.firstWhere(
          (e) => e.name == name, 
          orElse: () => GaugePlacement.bottomRight
      );
  }


  Future<void> _onUpdateProgress(_UpdateProcessingProgress event, Emitter<ProcessorState> emit) async {
    if(state.status == ProcessorStatus.ongoing){
      emit(state.copyWith(progress: event.progress));
    }
  }

  Future<void> _onProcessingCompleted(_ProcessingActionCompleted event, Emitter<ProcessorState> emit) async {
      // Update Job status
      final updatedJob = event.job.copyWith(
          processedFilePath: event.outputPath,
          processedFileSizeInKb: event.fileSizeKb,
          processedAt: DateTime.now(),
      );
      await repository.moveToCompleted(updatedJob);

      emit(state.copyWith(currentJob: null, status: ProcessorStatus.success, successMessage: "Processing Successful"));

      await Future.delayed(Duration(milliseconds: 5000), (){
        emit(state.copyWith(currentJob: null, status: ProcessorStatus.idle));
      });
  }

   Future<void> _onProcessingFailed(_ProcessingActionFailed event, Emitter<ProcessorState> emit) async {
       // Update Job status
       final updatedJob = event.job.copyWith(
           failedAt: DateTime.now(),
           lastError: event.error,
           failureCount: event.job.failureCount + 1,
       );
       await repository.moveToFailed(updatedJob);

       emit(state.copyWith(currentJob: null, status: ProcessorStatus.failure, successMessage: "Processing Unsuccessful"));

       await Future.delayed(Duration(milliseconds: 5000), (){
         emit(state.copyWith(currentJob: null, status: ProcessorStatus.idle));
       });
   }
}
