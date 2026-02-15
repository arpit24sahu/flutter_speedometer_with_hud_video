import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/widgets/video_recorder_service.dart';

import 'package:uuid/uuid.dart';
import '../../features/processing/models/processing_job.dart';
import '../../features/processing/bloc/jobs_bloc.dart';
import '../../features/processing/bloc/processor_bloc.dart';
import '../../utils.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';

class VideoRecorderBloc extends Bloc<VideoRecorderEvent, VideoRecorderState> {
  final WidgetRecorderService recorderService;
  final JobsBloc jobsBloc;
  final ProcessorBloc processorBloc;
  
  VideoRecorderBloc({
    required this.recorderService,
    required this.jobsBloc,
    required this.processorBloc,
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
      if (recordingStarted) await LocationService().startSpeedTracking();

      print("!!! Recording did not start");

      emit(VideoRecording());
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

      Map<int, PositionData> positionData =
          LocationService().stopSpeedTracking();
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


      // Construct the command string for reference
      final filterComplex = buildFilterComplex(
        event.gaugePlacement,
        event.relativeSize,
      );

      // Step 2: Get the output directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${directory.path}/TurboGauge_$timestamp.mp4';

      // Build the full command as a **single string**
      final commandDescription =
          '-y '
          '-i "$cameraVideoPath" '
          // '-i "$widgetVideoPath" '
          '-filter_complex "$filterComplex" '
          '-map "[out]" '
          '-map 0:a? '
          '-c:v mpeg4 '
          '-q:v 5 '
          '-c:a aac '
          '-b:a 192k '
          '"$outputPath"';

      // final commandDescription =
      //     '-y -i "$cameraVideoPath" -i "$widgetVideoPath" -filter_complex "$filterComplex" ...'

      final job = ProcessingJob(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        videoFilePath: cameraVideoPath,
        overlayFilePath: "",
        gaugePlacement: event.gaugePlacement.name,
        relativeSize: event.relativeSize,
        ffmpegCommand: commandDescription,
        positionData: positionData
      );

      jobsBloc.add(AddJob(job));

      // Also save as a ProcessingTask for the Labs feature
      try {
        final List<PositionData> positionDataList = positionData.values.toList();
        // final List<PositionData> positionDataList = positionData.values.map((PositionData data) {
        //   return data.copyWith(
        //     speed: 10 + Random().nextDouble() * 190, // 10 → 200
        //   );
        // }).toList();
        print("Final Position Data");
        print(positionDataList.map((e) => e.speed));
        await LabsService().createFromRecording(
          videoFilePath: cameraVideoPath,
          positionData: positionData //positionDataList,
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

// Parameters to pass to the isolate
class _VideoProcessingParams {
  final String cameraVideoPath;
  final String widgetVideoPath;
  final GaugePlacement gaugePlacement;
  final double relativeSize;

  _VideoProcessingParams({
    required this.cameraVideoPath,
    required this.widgetVideoPath,
    required this.gaugePlacement,
    required this.relativeSize,
  });
}

Future<String> _processVideo(_VideoProcessingParams params) async {

  String? finalPath;

  void onSuccess(String path, double size){
    finalPath = path;
  }

  try {

    final finalVideoPath = await processChromaKeyVideo(
      backgroundPath: params.cameraVideoPath,
      foregroundPath: params.widgetVideoPath,
      placement: params.gaugePlacement,
      relativeSize: params.relativeSize,
      onProcessSuccess: onSuccess,
      onProcessFailure: (String error){
        throw error;
      }
    );
    if(finalVideoPath == null){
      throw Exception("Failed to process video");
    }
    return finalPath??"";
  } catch (e) {
    rethrow;
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

  VideoJobSaved({required this.videoPath, required this.positionDataPoints});

  @override
  List<Object?> get props => [videoPath, positionDataPoints];
}
