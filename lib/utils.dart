import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_video/session.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';

Future<String> getDownloadsPath()async{
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<void> openFile(FileSystemEntity file) async {
  OpenResult result = await OpenFile.open(file.path);
  if (result.type != ResultType.done) {
    Get.snackbar(
        'Error',
        result.message,
        colorText: Colors.black,
        backgroundColor: Colors.white
    );
  }
}

Future<String?> processChromaKeyVideo(
{
  required String backgroundPath,
  required String foregroundPath,
  required GaugePlacement placement,
  required double relativeSize
}
    ) async {

  // Step 2: Get the output directory
  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  String outputPath = '${directory.path}/chroma_output_$timestamp.mp4';

  // Build filter complex (same logic)
  final filterComplex = buildFilterComplex(placement, relativeSize);

  // Build the full command as a **single string**
  final command =
      '-y '
      '-i "$backgroundPath" '
      '-i "$foregroundPath" '
      '-filter_complex "$filterComplex" '
      '-map "[out]" '
      '-map 0:a? '
      '-c:v mpeg4 '
      '-q:v 5 '
      '-c:a aac '
      '-b:a 192k '
      '"$outputPath"';

  print('Executing FFmpeg command:');
  print(command);
  print('─' * 60);

  try {
    final session = await FFmpegKit.executeAsync(
      command,
      (Session session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          print('✓ Chroma key processing completed successfully');
          print('Output saved at: $outputPath');
        } else {
          final failStackTrace = await session.getFailStackTrace();
          final logs = await session.getLogs();

          print('✗ Processing failed with return code: $returnCode');
          if (logs.isNotEmpty) {
            print('Logs:');
            for (final log in logs) {
              print(log.getMessage());
            }
          }
          if (failStackTrace != null && failStackTrace.isNotEmpty) {
            print('Fail stack trace:');
            print(failStackTrace);
          }
        }
      },
      (log) {
        // You can uncomment for very detailed output
        // print('LOG: ${log.getMessage()}');
      },
      (statistics) {
        // Optional progress tracking
        // print('Time: ${statistics.getTime()}, FPS: ${statistics.getVideoFps()}');
      },
    );

    // You can optionally wait here if you need synchronous behavior
    // final rc = await session.getReturnCode();

    return outputPath;
  } catch (e, stack) {
    print('Exception during FFmpeg execution: $e');
    print(stack);
    return null;
  }
}

String buildFilterComplex(GaugePlacement placement, double relativeSize) {
  String filter =
      '[1:v]chromakey=0x000000:0.1:0.02,scale=iw*${relativeSize.toStringAsFixed(2)}:-1[fg];';

  String overlayPosition;
  switch (placement) {
    case GaugePlacement.topLeft:
      overlayPosition = 'x=0:y=0';
      break;
    case GaugePlacement.topCenter:
      overlayPosition = 'x=(main_w-overlay_w)/2:y=0';
      break;
    case GaugePlacement.topRight:
      overlayPosition = 'x=main_w-overlay_w:y=0';
      break;
    case GaugePlacement.centerLeft:
      overlayPosition = 'x=0:y=(main_h-overlay_h)/2';
      break;
    case GaugePlacement.center:
      overlayPosition = 'x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2';
      break;
    case GaugePlacement.centerRight:
      overlayPosition = 'x=main_w-overlay_w:y=(main_h-overlay_h)/2';
      break;
    case GaugePlacement.bottomLeft:
      overlayPosition = 'x=0:y=main_h-overlay_h';
      break;
    case GaugePlacement.bottomCenter:
      overlayPosition = 'x=(main_w-overlay_w)/2:y=main_h-overlay_h';
      break;
    case GaugePlacement.bottomRight:
      overlayPosition = 'x=main_w-overlay_w:y=main_h-overlay_h';
      break;
  }

  filter += '[0:v][fg]overlay=$overlayPosition[out]';

  return filter;
}