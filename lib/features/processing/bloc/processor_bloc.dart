import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import '../../../../utils.dart';
import '../models/processing_job.dart';
import '../repository/processing_repository.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

    final ProcessingJob? job = event.job ?? repository.getNextPendingJob();
    if (job == null) {
      emit(state.copyWith(status: ProcessorStatus.idle, currentJob: null));
      return;
    }

    emit(state.copyWith(status: ProcessorStatus.ongoing, currentJob: job, progress: 0));

    try {

      String speedometerFilePath = await _generateSpeedometerVideoFile(job);

      // // String tempDirPath = job.framesFolderPath??"";
      // String outputPath = job.overlayFilePath??"";
      // int frameCaptureInterval = 50;
      //
      // print("Temp frames directory: $tempDirPath");
      // print("Output video path: $outputPath");
      // final tempDir = Directory(tempDirPath);
      // if (!await tempDir.exists()) {
      //   await tempDir.create(recursive: true);
      // }
      //
      // // Set up conversion parameters
      // final fps = (1000 / frameCaptureInterval)
      //     .round(); // Calculate FPS based on capture interval
      // print("Converting frames to video at $fps FPS...");
      //
      // try {
      //   final command = [
      //     '-framerate', '$fps',
      //     '-i', '${tempDirPath}/frame_%06d.png',
      //     '-c:v', 'mpeg4', // Use `mpeg4` instead of `libx264`
      //     '-q:v', '5', // Adjust quality (lower = better)
      //     '-preset', 'ultrafast',
      //     outputPath,
      //   ].join(' ');
      //
      //   // final command = '-framerate $fps -i ${tempDirPath}/frame_%06d.png -c:v libx264 -pix_fmt yuv420p -b:v 2M ${outputPath}';
      //   print("Executing FFmpeg command: $command");
      //   final session = await FFmpegKit.execute(command);
      //   final rc = await session.getReturnCode();
      //   print("FFmpeg execution return code: $rc");
      //
      //   if (ReturnCode.isSuccess(rc)) {
      //     print("Success");
      //   } else if (ReturnCode.isCancel(rc)) {
      //     print("Cancelled");
      //   } else {
      //     print("Failed");
      //   }
      //
      //   // Convert frames to video
      //   // final result = await ffmpeg.executeFFmpeg(
      //   //   inputPath: tempDirPath,
      //   //   inputPattern: 'frame_%06d.png',
      //   //   outputPath: outputPath,
      //   //   frameRate: fps,
      //   //   videoBitrate: "2M",  // 2 Mbps - adjust as needed
      //   // );
      // } catch (e) {
      //   print("Error converting frames to video: $e");
      // }



      print("Now starting chroma processing");


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
            foregroundPath: speedometerFilePath,
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
  //
  // Future<String> _generateSpeedometerVideoFile(StartProcessing event)async{
  //
  //
  //   // TODO
  //   return "";
  // }
  //
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

// Assuming these are already imported in your file:
// import 'package:equatable/equatable.dart';
// import 'package:hive/hive.dart';
// ... your event/job classes

Future<String> _generateSpeedometerVideoFile(ProcessingJob job) async {
  print('[SpeedoVideo] Started - Processing job: ${job.id ?? "no job"}');

  // final job = job;
  if (job == null || job.positionData == null || job.positionData!.isEmpty) {
    print('[SpeedoVideo] No job or no position data, exiting');
    return '';
  }

  // Extract speed data: timestamp (ms) → speed (double)
  // We use .toDouble() since speed in PositionData is double
  final Map<int, double> timeToSpeedMs = {};
  for (final entry in job.positionData!.entries) {
    final int timestampMs = entry.key;
    final double speed = entry.value.speed; // m/s from location data
    timeToSpeedMs[timestampMs] = speed;
  }

  if (timeToSpeedMs.isEmpty) {
    print('[SpeedoVideo] No valid speed data found');
    return '';
  }

  // For simplicity: hardcoded speedometer image URL
  // Later: you can add it to ProcessingJob or config
  const String imageUrl = 'https://i.ibb.co/whLrrLNy/image.png'; // ← REPLACE WITH REAL URL

  print('[SpeedoVideo] Downloading base speedometer image');
  final response = await http.get(Uri.parse(imageUrl));
  if (response.statusCode != 200) {
    print('[SpeedoVideo] Image download failed: ${response.statusCode}');
    // You can decide: throw or return ''
    return '';
  }

  final bytes = response.bodyBytes;
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final ui.Image baseImage = frame.image;

  final double size = baseImage.width.toDouble();
  if (baseImage.height != baseImage.width) {
    print('[SpeedoVideo] Image is not square (${baseImage.width}x${baseImage.height})');
    return '';
  }

  print('[SpeedoVideo] Base image loaded: ${size.toInt()}x${size.toInt()}');

  final dir = await getTemporaryDirectory();
  final String tempDirPath = dir.path;
  print('[SpeedoVideo] Temp directory: $tempDirPath');

  // Timestamps in ms
  final timesMs = timeToSpeedMs.keys.toList()..sort();
  final int firstMs = timesMs.first;
  final int lastMs = timesMs.last;
  final double totalSeconds = (lastMs - firstMs) / 1000.0;

  const int fps = 2;
  final int numFrames = (totalSeconds * fps).ceil() + 1; // +1 to include end

  print('[SpeedoVideo] Duration: ${totalSeconds.toStringAsFixed(2)}s | FPS: $fps | Frames: $numFrames');

  const double minSpeed = 0.0;
  const double maxSpeed = 240.0; // assuming km/h – adjust if your speed is in m/s!
  // If speed is in m/s (from PositionData), convert: speedKmh = speedMs * 3.6
  // For now assuming km/h — change multiplier below if needed

  const double minAngle = 4.1887902047863905; // ≈240° in radians
  const double maxAngle = 1.0471975511965976; // ≈60°
  const double sweepRad = minAngle - maxAngle;

  double getSpeedAt(double secondsElapsed) {
    final double msElapsed = secondsElapsed * 1000.0;
    final double targetMs = firstMs + msElapsed;

    if (targetMs <= timesMs.first) return timeToSpeedMs[timesMs.first]!;
    if (targetMs >= timesMs.last) return timeToSpeedMs[timesMs.last]!;

    int i = 1;
    while (i < timesMs.length && targetMs > timesMs[i]) {
      i++;
    }

    final double prevMs = timesMs[i - 1].toDouble();
    final double nextMs = timesMs[i].toDouble();
    final double frac = (targetMs - prevMs) / (nextMs - prevMs);

    return timeToSpeedMs[timesMs[i - 1]]! +
        frac * (timeToSpeedMs[timesMs[i]]! - timeToSpeedMs[timesMs[i - 1]]!);
  }

  print('[SpeedoVideo] Generating frames...');

  for (int frameIndex = 1; frameIndex <= numFrames; frameIndex++) {
    if (frameIndex % 30 == 0 || frameIndex == 1 || frameIndex == numFrames) {
      print('[SpeedoVideo] Frame $frameIndex / $numFrames');
    }

    final double tSec = (frameIndex - 1) / fps.toDouble();
    double speed = getSpeedAt(tSec);

    // If your PositionData.speed is in m/s → uncomment next line:
    speed *= 3.6; // convert m/s → km/h

    final double fraction = ((speed - minSpeed) / (maxSpeed - minSpeed)).clamp(0.0, 1.0);
    final double angle = minAngle - fraction * sweepRad;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size, size));

    canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());

    final double cx = size / 2;
    final double cy = size / 2;
    final double length = size * 0.4;

    final needleX = cx + length * math.cos(angle);
    final needleY = cy - length * math.sin(angle);

    final paint = ui.Paint()
      ..color = const ui.Color.fromARGB(255, 255, 0, 0)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawLine(ui.Offset(cx, cy), ui.Offset(needleX, needleY), paint);

    // Draw current speed text
    final textStyle = ui.TextStyle(
      color: const ui.Color.fromARGB(255, 0, 0, 0),
      fontSize: size * 0.06,
      fontWeight: ui.FontWeight.bold,
      height: 1.0,
    );

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText('${speed.toInt()}');

    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity)); // auto-size for accurate width

    final textX = cx - paragraph.width / 2;
    final textY = cy + size * 0.12 - paragraph.height / 2;

    canvas.drawParagraph(paragraph, ui.Offset(textX, textY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final framePath = '$tempDirPath/frame_${frameIndex.toString().padLeft(6, '0')}.png';
    await File(framePath).writeAsBytes(byteData!.buffer.asUint8List());

    picture.dispose();
    img.dispose();
  }

  print('[SpeedoVideo] Frame generation completed');

  final String outputPath = '$tempDirPath/speedo_${job.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';

  final command = [
    '-framerate', '$fps',
    '-i', '$tempDirPath/frame_%06d.png',
    '-c:v', 'mpeg4',           // better compatibility than mpeg4 on modern devices
    '-pix_fmt', 'yuv420p',       // important for broad playback support
    '-crf', '23',                // good quality/size balance (18–28 range)
    '-preset', 'ultrafast',
    '-y',                        // overwrite if exists
    outputPath,
  ].join(' ');

  print('[SpeedoVideo] Running FFmpeg');
  print('[SpeedoVideo] Command: $command');

  try {
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();

    print('[SpeedoVideo] FFmpeg return code: $rc');

    if (rc?.isValueSuccess() ?? false) {
      print('[SpeedoVideo] Video created successfully: $outputPath');
      // Optional: clean up frames if you want (delete after success)
      // for (int i = 1; i <= numFrames; i++) {
      //   final p = File('$tempDirPath/frame_${i.toString().padLeft(6, '0')}.png');
      //   if (await p.exists()) await p.delete();
      // }
      return outputPath;
    } else {
      print('[SpeedoVideo] FFmpeg failed');
      final logs = await session.getLogs();
      if ((logs).isNotEmpty) {
        print('Logs:');
        for (final log in logs) {
          print(log.getMessage());
        }
      }
      return '';
    }
  } catch (e) {
    print('[SpeedoVideo] FFmpeg exception: $e');
    return '';
  }
}
