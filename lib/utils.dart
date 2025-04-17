import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg_utils/flutter_ffmpeg_utils.dart';
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


final ffmpegUtils = FlutterFfmpegUtils();
//

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

  final ffmpegUtils = FlutterFfmpegUtils();
  List<String> command = [
    '-i', backgroundPath,
    '-i', foregroundPath,
    '-filter_complex',
    buildFilterComplex(placement, relativeSize),
    // '-filter_complex',
    // '[1:v]chromakey=0x000000:0.1:0.02,scale=iw*0.3:-1[fg];'
    //     + '[0:v][fg]overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2[out]',
    '-map', '[out]',
    '-map', '0:a?',
    '-c:v', 'mpeg4',  // Use mobile-compatible encoder
    '-q:v', '5',      // Quality (1=best, 31=worst)
    '-c:a', 'aac',    // Encode audio
    '-b:a', '192k',

    // '-map', '[out]',
    // '-map', '0:a?',
    // // '-c:a', 'copy',
    outputPath
  ];

  // List<String> command = [
  //   '-i', backgroundPath,
  //   '-i', foregroundPath,
  //   '-filter_complex',
  //   '[1:v]chromakey=0x000000:0.1:0.02[fg];[0:v][fg]overlay[out]',
  //   '-map', '[out]',
  //   '-map', '0:a?',
  //   '-c:a', 'copy',
  //   outputPath
  // ];

  // Step 4: Execute FFmpeg command
  try {
    await ffmpegUtils.executeFFmpeg(command);
    print("✅ Processing complete! Video saved at: $outputPath");
    return outputPath;
  } catch (e) {
    print("❌ Error: $e");
    return null;
  }
}

String buildFilterComplex(GaugePlacement placement, double relativeSize) {
  // First part of the filter - chromakey and scale
  String filter = '[1:v]chromakey=0x000000:0.1:0.02,scale=iw*${relativeSize.toStringAsFixed(2)}:-1[fg];';

  // Second part - overlay with position based on placement enum
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

  // Combine the filter parts
  filter += '[0:v][fg]overlay=$overlayPosition[out]';

  return filter;
}