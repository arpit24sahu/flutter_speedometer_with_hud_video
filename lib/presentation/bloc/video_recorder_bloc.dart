import 'dart:async';
import 'dart:isolate';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/widgets/video_recorder_service.dart';

import '../../utils.dart';

class VideoRecorderBloc extends Bloc<VideoRecorderEvent, VideoRecorderState> {
  final WidgetRecorderService recorderService;
  
  VideoRecorderBloc({required this.recorderService}) : super(VideoRecorderInitial()) {
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
      await recorderService.startRecording();
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
      final Map<String, String> initialResult = await recorderService.stopRecording(
        event.gaugePlacement,
        event.relativeSize,
      );
      print('DEBUG: stopRecording result: $initialResult');

      if (initialResult.containsKey('error')) {
        print('DEBUG: Error in initial result: ${initialResult['error']}');
        add(ProcessingFailed(errorMessage: initialResult['error']!));
        return;
      }

      final resultCompleter = Completer<Map<String, String>>();
      final receivePort = ReceivePort();
      print('DEBUG: Setting up ReceivePort');
      
      final rootIsolateToken = RootIsolateToken.instance!;
      print('DEBUG: Got RootIsolateToken');

      final String cameraVideoPath = initialResult['cameraVideoPath'] ?? '';
      final String widgetVideoPath = initialResult['widgetVideoPath'] ?? '';
      print('DEBUG: Camera video path: $cameraVideoPath');
      print('DEBUG: Widget video path: $widgetVideoPath');

      print('DEBUG: Spawning isolate for video processing');
      Isolate.spawn(
        _processVideoInIsolate,
        _VideoProcessingParams(
          sendPort: receivePort.sendPort,
          rootIsolateToken: rootIsolateToken,
          cameraVideoPath: cameraVideoPath,
          widgetVideoPath: widgetVideoPath,
          gaugePlacement: event.gaugePlacement,
          relativeSize: event.relativeSize,
        ),
      );
      print('DEBUG: Isolate spawned successfully');
      
      // Listen for messages from the isolate
      print('DEBUG: Setting up listener for isolate messages');
      receivePort.listen((message) {
        print('DEBUG: Received message from isolate: ${message.runtimeType}');
        if (message is double) {
          // Progress update
          print('DEBUG: Progress update: $message');
          add(ProcessingProgress(progress: message));
        } else if (message is Map) {
          // Check if it's a Map with String keys
          print('DEBUG: Processing completed with result: $message');
          
          // Convert the map to Map<String, String>
          final Map<String, String> finalResult = {};
          message.forEach((key, value) {
            if (key is String) {
              finalResult[key] = value?.toString() ?? '';
            }
          });
          
          resultCompleter.complete(finalResult);
          receivePort.close();
        } else if (message is String) {
          // Error occurred
          print('DEBUG: Error message from isolate: $message');
          resultCompleter.completeError(message);
          receivePort.close();
        }
      });
      
      // Wait for the result
      print('DEBUG: Waiting for result from isolate');
      final result = await resultCompleter.future;
      print("DEBUG: Done All!! Final video path: ${result['finalVideoPath']}");
      
      if (result.containsKey('error')) {
        print('DEBUG: Error in final result: ${result['error']}');
        add(ProcessingFailed(errorMessage: result['error']!));
      } else {
        print('DEBUG: Processing completed successfully');
        add(ProcessingCompleted(
          cameraVideoPath: cameraVideoPath,
          widgetVideoPath: widgetVideoPath,
          finalVideoPath: result['finalVideoPath']!,
        ));
      }
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
  
  void _onResetRecorder(
    ResetRecorder event,
    Emitter<VideoRecorderState> emit,
  ) {
    emit(VideoRecorderInitial());
  }
}

// Parameters to pass to the isolate
class _VideoProcessingParams {
  final SendPort sendPort;
  final String cameraVideoPath;
  final RootIsolateToken rootIsolateToken;
  final String widgetVideoPath;
  final GaugePlacement gaugePlacement;
  final double relativeSize;
  
  _VideoProcessingParams({
    required this.sendPort,
    required this.cameraVideoPath,
    required this.rootIsolateToken,
    required this.widgetVideoPath,
    required this.gaugePlacement,
    required this.relativeSize,
  });
}

// Isolate entry point function
void _processVideoInIsolate(_VideoProcessingParams params) async {
  try {
    final SendPort sendPort = params.sendPort;
    BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

    // First notify that recording has stopped
    // sendPort.send(0.1); // Initial progress

    // for (double progress = 0.2; progress < 0.6; progress += 0.1) {
    //   sendPort.send(progress);
    //   await Future.delayed(Duration(milliseconds: 200)); // Simulate processing time
    // }

    final finalVideoPath = await processChromaKeyVideo(
      backgroundPath: params.cameraVideoPath,
      foregroundPath: params.widgetVideoPath,
      placement: params.gaugePlacement,
      relativeSize: params.relativeSize,
    );
    // Process the video
    
    // Send regular progress updates - in a real implementation,
    // these would come from the actual processing
    // for (double progress = 0.6; progress < 1.0; progress += 0.1) {
    //   sendPort.send(progress);
    //   await Future.delayed(Duration(milliseconds: 300)); // Simulate processing time
    // }
    
    // Send the final result
    sendPort.send({"finalVideoPath": finalVideoPath});
  } catch (e) {
    params.sendPort.send({'error': 'Error processing video: $e'});
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

  StopRecording({
    required this.gaugePlacement, 
    required this.relativeSize,
  });
  
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
