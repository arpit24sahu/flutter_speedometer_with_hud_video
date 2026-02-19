import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';
import 'package:speedometer/presentation/widgets/video_recorder_service.dart';

import '../../features/labs/models/gauge_customization.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';

class VideoRecorderBloc extends Bloc<VideoRecorderEvent, VideoRecorderState> {
  final WidgetRecorderService recorderService;
  
  VideoRecorderBloc({
    required this.recorderService,
  }) : super(VideoRecorderInitial()) {
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<ProcessingStarted>(_onProcessingStarted);
    on<ProcessingProgress>(_onProcessingProgress);
    on<ProcessingCompleted>(_onProcessingCompleted);
    on<ProcessingFailed>(_onProcessingFailed);
    on<ResetRecorder>(_onResetRecorder);
  }

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<VideoRecorderState> emit,
  ) async {
    try {
      bool recordingStarted = await recorderService.startRecording();
      if (recordingStarted) {
        await LocationService().startSpeedTracking();
        emit(VideoRecording());
      } else {
        debugPrint(
          'VideoRecorderBloc: Recording did not start – camera may not be ready',
        );
        emit(
          VideoRecordingError(
            'Recording could not start. Please wait for the camera to initialize and try again.',
          ),
        );
      }
    } catch (e) {
      emit(VideoRecordingError('Failed to start recording: $e'));
    }
  }

  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<VideoRecorderState> emit,
  ) async {
    try {
      print('DEBUG: Starting stop recording process');
      // First transition to processing state
      // emit(VideoProcessing(progress: 0));
      add(ProcessingStarted());
      
      print('DEBUG: Calling recorderService.stopRecording()');
      // Start the actual processing in an isolate
      final StopRecordingReturnObject initialResult = await recorderService
          .stopRecording(event.gaugePlacement, event.relativeSize);
      print('DEBUG: stopRecording result: $initialResult');

      Map<int, PositionData> positionData = LocationService().stopSpeedTracking();
      print("SpeedTracking stopped: ${positionData.length}");
      for (int key in positionData.keys) {
        print("$key ${positionData[key]?.speed}");
      }

      if (initialResult.error != null && initialResult.error!.isNotEmpty) {
        print('DEBUG: Error in initial result: ${initialResult.error}');
        add(ProcessingFailed(errorMessage: initialResult.error!));
        return;
      }

      final String cameraVideoPath = initialResult.cameraVideoPath ?? '';
      print('DEBUG: Camera video path: $cameraVideoPath');


      // Calculate approx duration from position data keys (timestamps)
      double durationSeconds = 0;
      if (positionData.isNotEmpty) {
        final keys = positionData.keys.toList()..sort();
        if (keys.isNotEmpty) {
          final start = keys.first;
          final end = keys.last;
          durationSeconds = (end - start) / 1000.0; // Convert ms to seconds
        }
      }

      // Save as a ProcessingTask for the Labs feature
      try {
        print("Final Position Data: ${positionData.length} points");
        await LabsService().createFromRecording(
          videoFilePath: cameraVideoPath,
          positionData: positionData,
          lengthInSeconds: durationSeconds,
        );
        print('DEBUG: ProcessingTask saved for Labs');
      } catch (e) {
        print('DEBUG: Failed to save ProcessingTask for Labs: $e');
      }

      // Emit job saved state for UI feedback
      emit(
        VideoJobSaved(
          videoPath: cameraVideoPath,
          positionDataPoints: positionData.length,
          durationSeconds: durationSeconds,
          maxSpeed: LocationService.getMaxSpeedFromPositionData(positionData.values.toList()),
        ),
      );
    } catch (e, stackTrace) {
      print('DEBUG: Exception during video processing: $e');
      print('DEBUG: Stack trace: $stackTrace');
      emit(VideoProcessingError('Failed to process video: $e'));
    }
  }
  
  void _onProcessingStarted(
    ProcessingStarted event,
    Emitter<VideoRecorderState> emit,
  ) {
    emit(VideoProcessing(progress: 0));
  }
  
  void _onProcessingProgress(
    ProcessingProgress event,
    Emitter<VideoRecorderState> emit,
  ) {
    emit(VideoProcessing(progress: event.progress));
  }
  
  void _onProcessingCompleted(
    ProcessingCompleted event,
    Emitter<VideoRecorderState> emit,
  ) {
    emit(VideoProcessed(
      cameraVideoPath: event.cameraVideoPath,
      widgetVideoPath: event.widgetVideoPath,
      finalVideoPath: event.finalVideoPath,
    ));
  }
  
  void _onProcessingFailed(
    ProcessingFailed event,
    Emitter<VideoRecorderState> emit,
  ) {
    emit(VideoProcessingError(event.errorMessage));
  }

  void _onResetRecorder(ResetRecorder event, Emitter<VideoRecorderState> emit) {
    emit(VideoRecorderInitial());
  }
}

abstract class VideoRecorderEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartRecording extends VideoRecorderEvent {}

class StopRecording extends VideoRecorderEvent {
  final GaugePlacement gaugePlacement;
  final double relativeSize;

  StopRecording({required this.gaugePlacement, required this.relativeSize});

  @override
  List<Object?> get props => [gaugePlacement, relativeSize];
}

class ProcessingStarted extends VideoRecorderEvent {}

class ProcessingProgress extends VideoRecorderEvent {
  final double progress;

  ProcessingProgress({required this.progress});
  
  @override
  List<Object?> get props => [progress];
}

class ProcessingCompleted extends VideoRecorderEvent {
  final String cameraVideoPath;
  final String widgetVideoPath;
  final String finalVideoPath;

  ProcessingCompleted({
    required this.cameraVideoPath, 
    required this.widgetVideoPath,
    required this.finalVideoPath,
  });
  
  @override
  List<Object?> get props => [cameraVideoPath, widgetVideoPath, finalVideoPath];
}

class ProcessingFailed extends VideoRecorderEvent {
  final String errorMessage;

  ProcessingFailed({required this.errorMessage});
  
  @override
  List<Object?> get props => [errorMessage];
}

class ResetRecorder extends VideoRecorderEvent {}


@immutable
abstract class VideoRecorderState extends Equatable {
  @override
  List<Object?> get props => [];
}

class VideoRecorderInitial extends VideoRecorderState {}

class VideoRecording extends VideoRecorderState {}

class VideoProcessing extends VideoRecorderState {
  final double progress; // 0.0 to 1.0

  VideoProcessing({required this.progress});
  
  @override
  List<Object?> get props => [progress];
}

class VideoProcessed extends VideoRecorderState {
  final String cameraVideoPath;
  final String widgetVideoPath;
  final String finalVideoPath;

  VideoProcessed({
    required this.cameraVideoPath, 
    required this.widgetVideoPath,
    required this.finalVideoPath,
  });
  
  @override
  List<Object?> get props => [cameraVideoPath, widgetVideoPath, finalVideoPath];
}

class VideoRecordingError extends VideoRecorderState {
  final String message;

  VideoRecordingError(this.message);
  
  @override
  List<Object?> get props => [message];
}

class VideoProcessingError extends VideoRecorderState {
  final String message;

  VideoProcessingError(this.message);
  
  @override
  List<Object?> get props => [message];
}

/// Emitted when recording is stopped and job is saved for later processing
class VideoJobSaved extends VideoRecorderState {
  final String videoPath;
  final int positionDataPoints;
  final double durationSeconds;
  final double maxSpeed;

  VideoJobSaved({
    required this.videoPath,
    required this.positionDataPoints,
    required this.durationSeconds,
    required this.maxSpeed
  });

  @override
  List<Object?> get props => [videoPath, positionDataPoints, durationSeconds, maxSpeed];
}
