import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg_utils/flutter_ffmpeg_utils.dart';

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

Future<String?> processChromaKeyVideo() async {
  print("AAAA");
  // Step 1: Pick two video files (background & foreground)
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: true,
  );

  if (result == null || result.files.length < 2) {
    print("❌ Please select two videos.");
    return null;
  } else {
    print("Picked 2 files");
  }

  String backgroundPath = result.files[0].path!;
  String foregroundPath = result.files[1].path!;

  print("${backgroundPath}");
  print("${foregroundPath}");
  // Step 2: Get the output directory
  final directory = await getApplicationDocumentsDirectory();
  String outputPath = '${directory.path}/chroma_output.mp4';

  print("Calling the funciton: ${outputPath}");
  // Step 3: Set up FFmpeg command
  final ffmpegUtils = FlutterFfmpegUtils();
  List<String> command = [
    '-i', backgroundPath,
    '-i', foregroundPath,
    '-filter_complex', '[1:v]chromakey=0x00FF00:0.2:0.1[fg];[0:v][fg]overlay[out]',
    '-map', '[out]',
    '-map', '0:a?',
    '-c:a', 'copy',
    outputPath
  ];

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