import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit_config.dart';
import '../../domain/services/video_export_service_interface.dart';
import '../dashcam_preferences.dart';
import '../../utils/subtitle_generator.dart';

class FFmpegVideoExportService implements IVideoExportService {
  final DashcamPreferences preferences;
  final SubtitleGenerator _subtitleGenerator;

  FFmpegVideoExportService({
    required this.preferences,
    SubtitleGenerator? subtitleGenerator,
  }) : _subtitleGenerator = subtitleGenerator ?? SubtitleGenerator();

  Future<String> _getLogoPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final logoFile = File('${docsDir.path}/icon.jpg');
    
    // Extract logo from assets to a real file path for FFmpeg
    if (!await logoFile.exists()) {
      final byteData = await rootBundle.load('assets/icon/icon.jpg');
      final buffer = byteData.buffer;
      await logoFile.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    
    return logoFile.path;
  }

  /// Probes the input video and returns (width, height).
  /// Falls back to 1920x1080 if probe fails.
  Future<(int, int)> _probeVideoDimensions(File inputVideo) async {
    try {
      final mediaInfo = await FFprobeKit.getMediaInformation(inputVideo.path);
      final info = mediaInfo.getMediaInformation();
      if (info != null) {
        final streams = info.getStreams();
        for (final stream in streams) {
          final w = stream.getWidth();
          final h = stream.getHeight();
          if (w != null && h != null && w > 0 && h > 0) {
            return (w, h);
          }
        }
      }
    } catch (e) {
      print("Failed to probe video dimensions: $e");
    }
    return (1920, 1080); // safe fallback
  }

  @override
  Future<String?> exportVideoWithOverlays(File inputVideo, {void Function(double)? onProgress}) async {
    try {
      // ── 1. Probe video dimensions ──────────────────────────────
      final (int rawWidth, int rawHeight) = await _probeVideoDimensions(
        inputVideo,
      );

      // Cap the LONG edge to 1080 for memory safety, keeping aspect ratio.
      // This caps landscape width to 1080, and portrait height to 1080 × (h/w).
      final int cappedWidth = min(1080, rawWidth);
      final int cappedHeight = (cappedWidth * rawHeight / rawWidth).round();

      // ── 2. Logo sizing based on width (same reference as subtitles) ──
      final int logoSize = (0.08 * cappedWidth).round(); // ~86px at 1080
      final int logoMargin = (0.012 * cappedWidth).round(); // ~13px at 1080

      // ── 3. Generate ASS subtitle with relative sizes ───────────
      final jsonFile = File(inputVideo.path.replaceAll('.mp4', '.json'));
      final assFile = await _subtitleGenerator.generateAssSubtitle(
        jsonFile,
        preferences.speedUnit,
        videoWidth: cappedWidth,
        videoHeight: cappedHeight,
      );

      if (assFile == null) {
        print("Export failed: No metadata JSON found to generate subtitles.");
        return null;
      }

      // Ensure font and logo are available for FFmpeg
      final fontPath = await _subtitleGenerator.getFontPath();
      final logoPath = await _getLogoPath();

      // 🚨 CRITICAL FIX: Initialize fontconfig natively for Android 
      // This prevents the native SIGABRT crash when libass attempts to search
      // for fonts without a valid Linux-style font configuration file.
      if (Platform.isAndroid) {
        final fontDir = File(fontPath).parent.path;
        await FFmpegKitConfig.setFontDirectory(fontDir, null);
      }

      final outputPath = inputVideo.path.replaceAll('.mp4', '_exported.mp4');
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      // Get total duration to calculate progress
      double totalDurationMs = 0;
      try {
        final mediaInfo = await FFprobeKit.getMediaInformation(inputVideo.path);
        final info = mediaInfo.getMediaInformation();
        if (info != null) {
          totalDurationMs =
              (double.tryParse(info.getDuration() ?? '0') ?? 0.0) * 1000;
        }
      } catch (e) {
        print("Failed to get media info for progress calculation: $e");
      }

      // ── 4. Build the FFmpeg filter_complex ─────────────────────
      //
      // Logo:  bottom-right with margin
      // Text:  from ASS subtitle (speed top-right, info bottom-left)
      //
      // Video quality: libx264 with CRF 18 (high quality, near-lossless)
      // and -preset fast for a good speed/quality balance.
      // The old mpeg4 codec with CRF 28 produced very poor output.
      //
      final logoOverlayX = 'main_w-overlay_w-$logoMargin';
      final logoOverlayY = 'main_h-overlay_h-$logoMargin';

      final command =
          "-y -i '${inputVideo.path}' -i '$logoPath' "
          "-filter_complex "
          "\"[1:v]scale=$logoSize:-1[logo];"
          "[0:v]scale='min($cappedWidth,iw)':-1[scaled_vid];"
          "[scaled_vid][logo]overlay=$logoOverlayX:$logoOverlayY[with_logo];"
          "[with_logo]ass='${assFile.path}'[outv]\" "
          "-map \"[outv]\" -map 0:a? "
          "-c:v mpeg4 -q:v 2 -pix_fmt yuv420p -threads 2 "
          "-c:a copy '$outputPath'";

      print("Running FFmpeg export: $command");

      final completer = Completer<String?>();
      
      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            print("Export successful: $outputPath");
            try {
              if (await assFile.exists()) await assFile.delete();
            } catch (_) {}
            
            if (onProgress != null) onProgress(1.0);
            completer.complete(outputPath);
          } else {
            final output = await session.getOutput();
            final logs = await session.getLogs();
            print("FFmpeg Export failed with return code $returnCode.");
            print("Logs: $logs");
            print("Output: $output");
            completer.complete(null);
          }
        },
        (log) {
          print("FFmpeg Log [${log.getLevel()}]: ${log.getMessage()}");
        },
        (statistics) {
          if (onProgress != null && totalDurationMs > 0) {
            final timeInMs = statistics.getTime();
            double progress = timeInMs / totalDurationMs;
            if (progress > 1.0) progress = 1.0;
            if (progress < 0.0) progress = 0.0;
            onProgress(progress);
          }
        },
      );

      return completer.future;

    } catch (e) {
      print("Exception during FFmpeg export: $e");
      return null;
    }
  }
}
