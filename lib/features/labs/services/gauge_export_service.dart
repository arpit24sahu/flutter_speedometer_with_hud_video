import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:speedometer/features/labs/models/gauge_customization.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';

/// A single speed sample at a point in time.
class _SpeedSample {
  final double timeSec; // seconds from video start
  final double speedInUnit; // speed in km/h or mph

  const _SpeedSample(this.timeSec, this.speedInUnit);
}

/// Video metadata obtained from FFprobe.
class VideoInfo {
  final int width;
  final int height;
  final double durationSec;
  final double fps;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.durationSec,
    required this.fps,
  });
}

/// Service that builds FFmpeg commands with speed-synchronized
/// needle rotation overlays.
class GaugeExportService {
  GaugeExportService._();

  // ─── Public API ───

  /// Probes the video and returns its metadata.
  static Future<VideoInfo> probeVideo(String videoPath) async {
    int width = 1080;
    int height = 1920;
    double durationSec = 0;
    double fps = 30;

    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();

      if (info != null) {
        // Duration
        final durStr = info.getDuration();
        if (durStr != null) {
          durationSec = double.tryParse(durStr) ?? 0;
        }

        // Video stream
        final streams = info.getStreams();
        for (final stream in streams) {
          final type = stream.getType();
          if (type == 'video') {
            width = int.tryParse(
                    stream.getProperty('width')?.toString() ?? '') ??
                width;
            height = int.tryParse(
                    stream.getProperty('height')?.toString() ?? '') ??
                height;
            // Parse frame rate (may be "30/1" or "29.97")
            final rateStr =
                stream.getProperty('r_frame_rate')?.toString() ?? '';
            if (rateStr.contains('/')) {
              final parts = rateStr.split('/');
              final num = double.tryParse(parts[0]) ?? 30;
              final den = double.tryParse(parts[1]) ?? 1;
              fps = den > 0 ? num / den : 30;
            } else {
              fps = double.tryParse(rateStr) ?? 30;
            }
            break; // first video stream is enough
          }
        }
      }
    } catch (e) {
      debugPrint('[GaugeExport] Probe failed: $e');
    }

    return VideoInfo(
      width: width,
      height: height,
      durationSec: durationSec,
      fps: fps,
    );
  }

  /// Copies a bundled asset to a temporary file and returns the path.
  /// For network URLs, downloads the image to a temp file first
  /// (FFmpeg is not compiled with SSL support).
  static Future<String> resolveAssetPath(
      AssetType? assetType, String? path) async {
    if (path == null || path.isEmpty) return '';

    if (assetType == AssetType.asset) {
      // Copy from Flutter asset bundle to temp directory
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final fileName = path.split('/').last;
      final tempFile = File('${dir.path}/gauge_asset_$fileName');
      await tempFile.writeAsBytes(bytes);
      return tempFile.path;
    }

    if (assetType == AssetType.network) {
      // Download network image to temp file since FFmpeg lacks HTTPS support
      try {
        debugPrint('[GaugeExport] Downloading network image: $path');
        final uri = Uri.parse(path);
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(uri);
        final response = await request.close();

        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          // Use a hash-like name to avoid collisions
          final fileName = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : 'network_image_${path.hashCode}.png';
          final tempFile = File('${dir.path}/gauge_net_$fileName');
          final bytes = await consolidateHttpClientResponseBytes(response);
          await tempFile.writeAsBytes(bytes);
          debugPrint('[GaugeExport] Downloaded to: ${tempFile.path}');
          httpClient.close();
          return tempFile.path;
        } else {
          debugPrint('[GaugeExport] Download failed: HTTP ${response.statusCode}');
          httpClient.close();
          return path; // fallback to original URL
        }
      } catch (e) {
        debugPrint('[GaugeExport] Failed to download network image: $e');
        return path; // fallback to original URL
      }
    }

    // For memory, widget — return as-is
    return path;
  }

  /// Determines the dial max speed based on the highest recorded speed.
  ///
  /// Speed thresholds (in the selected unit):
  ///   - max < 200  → dial shows 0–240
  ///   - 200 ≤ max < 1200 → dial shows 0–1200
  ///   - max ≥ 1200 → dial shows 0–6000
  static double dialMaxSpeed(double maxRecordedSpeed) {
    if (maxRecordedSpeed < 200) return 240;
    if (maxRecordedSpeed < 1200) return 1200;
    return 6000;
  }

  /// Processes the position data map and converts speeds to the
  /// requested unit.
  ///
  /// [positionData] — map of elapsed ms (from video start) → PositionData.
  /// [imperial] — if true, convert to mph; otherwise km/h.
  static List<_SpeedSample> _processRawData(
      Map<int, PositionData> positionData, {
        required bool imperial,
      }) {
    print("Position Data before processing");
    print(" ElapsedMs: Speed (m/s)");
    for (final entry in positionData.entries) {
      print(" ${entry.key}: ${entry.value.speed}");
    }

    if (positionData.isEmpty) return [const _SpeedSample(0, 0)];

    // 1. Sort entries by key (elapsed ms) ascending — crucial for FFmpeg
    final sortedEntries = positionData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final conversionFactor = imperial ? 2.23694 : 3.6;

    final samples = <_SpeedSample>[];

    // 2. Convert raw points directly to seconds & unit speed
    for (final entry in sortedEntries) {
      final t = entry.key / 1000.0; // Convert elapsed ms → seconds
      final s = entry.value.speed * conversionFactor; // m/s → km/h or mph
      // Prevent duplicate timestamps (FFmpeg crashes if time doesn't move forward)
      if (samples.isNotEmpty && t <= samples.last.timeSec) continue;
      samples.add(_SpeedSample(t, s.clamp(0, double.infinity)));
    }

    // 3. Ensure we start at 0.0s (good for video start)
    if (samples.isNotEmpty && samples.first.timeSec > 0) {
      samples.insert(0, _SpeedSample(0.0, samples.first.speedInUnit));
    }

    return samples;
  }


  /// Builds the FFmpeg expression for the speed text value (JUST THE MATH).
  static String _buildSpeedTextExpression(
      List<_SpeedSample> samples,
      ) {
    if (samples.isEmpty) return '0';

    // Start with the last known speed
    String expr = samples.last.speedInUnit.toStringAsFixed(0);

    // Build the nested if/else logic backwards
    for (int i = samples.length - 2; i >= 0; i--) {
      final tI = samples[i].timeSec;
      final tNext = samples[i + 1].timeSec;
      final sI = samples[i].speedInUnit;
      final sNext = samples[i + 1].speedInUnit;
      final dt = tNext - tI;

      if (dt <= 0) continue;

      final slope = (sNext - sI) / dt;

      // Logic: speed_start + slope * (t - t_start)
      // We use 'floor' or 'trunc' to ensure we get a clean integer for the text
      expr = 'if(lt(t\\,${tNext.toStringAsFixed(3)})\\,'
          'floor(${sI.toStringAsFixed(2)}+${slope.toStringAsFixed(4)}*(t-${tI.toStringAsFixed(3)}))'
          '\\,$expr)';
    }

    return expr;
  }

  /// Linear interpolation of speed at a given timestamp (ms since epoch).
  static double _interpolateSpeed(
      List<PositionData> sorted, int targetMs) {
    if (sorted.isEmpty) return 0;
    if (targetMs <= sorted.first.timestamp) return sorted.first.speed;
    if (targetMs >= sorted.last.timestamp) return sorted.last.speed;

    // Find the bracketing points
    int i = 1;
    while (i < sorted.length && sorted[i].timestamp < targetMs) {
      i++;
    }

    final prev = sorted[i - 1];
    final next = sorted[i];
    final dt = (next.timestamp - prev.timestamp).toDouble();
    if (dt <= 0) return prev.speed;

    final fraction = (targetMs - prev.timestamp) / dt;
    return prev.speed + (next.speed - prev.speed) * fraction;
  }

  /// Builds the FFmpeg piecewise linear rotation expression for the
  /// needle, synchronized with sampled speed data.
  ///
  /// The expression uses `t` (time in seconds) and evaluates to an
  /// angle in radians. Positive = clockwise in FFmpeg's rotate filter.
  ///
  /// Needle math:
  ///   - Needle image points straight up (0°)
  ///   - At speed 0: rotate by -halfSweep (counterclockwise)
  ///   - At max speed: rotate by +halfSweep (clockwise)
  ///   - angle = (-halfSweep + fraction * totalSweep) × π / 180
  static String _buildRotationExpression(
    List<_SpeedSample> samples,
    double dialMax,
    Dial dial,
  ) {
    final halfSweepRad = dial.halfSweep * pi / 180;
    final totalSweepRad = dial.totalSweep * pi / 180;

    // Convert each sample to a target rotation angle in radians
    List<double> angles = samples.map((s) {
      final fraction = (s.speedInUnit / dialMax).clamp(0.0, 1.0);
      return -halfSweepRad + fraction * totalSweepRad;
    }).toList();

    if (samples.length <= 1) {
      return angles.isNotEmpty
          ? angles.first.toStringAsFixed(6)
          : '0';
    }

    // Build nested if(lt(t, t_next), lerp(a_i, a_next, (t-t_i)/(t_next-t_i)), ...)
    // Start from the last interval and wrap backwards
    String expr = angles.last.toStringAsFixed(6);

    for (int i = samples.length - 2; i >= 0; i--) {
      final tI = samples[i].timeSec;
      final tNext = samples[i + 1].timeSec;
      final aI = angles[i];
      final aNext = angles[i + 1];
      final dt = tNext - tI;

      if (dt <= 0) continue;

      final slope = (aNext - aI) / dt;

      // Linear interpolation: a_i + slope * (t - t_i)
      expr = 'if(lt(t\\,${tNext.toStringAsFixed(3)})\\,'
          '${aI.toStringAsFixed(6)}+${slope.toStringAsFixed(6)}*(t-${tI.toStringAsFixed(3)})'
          '\\,$expr)';
    }

    return expr;
  }

  /// Builds the complete FFmpeg command string for exporting a video
  /// with a gauge overlay.
  ///
  /// Inputs:
  ///   - [0] source video
  ///   - [1] dial image (transparent PNG)
  ///   - [2] needle image (transparent PNG, pointing up)
  ///
  /// Filter:
  ///   1. Scale dial to gauge size
  ///   2. Scale needle to gauge size, then rotate with time-based expression
  ///   3. Overlay needle on dial (centered)
  ///   4. Overlay gauge composite on source video at chosen placement
  static Future<String> buildCommand({
    required GaugeCustomizationSelected config,
    required String inputVideoPath,
    required Map<int, PositionData> positionData,
    required String outputPath,
  }) async {
    // 1. Probe video
    final videoInfo = await probeVideo(inputVideoPath);
    debugPrint('[GaugeExport] Video: ${videoInfo.width}×${videoInfo.height}, '
        '${videoInfo.durationSec}s, ${videoInfo.fps}fps');

    // 2. Resolve asset paths
    final dialPath = await resolveAssetPath(
        config.dial?.assetType, config.dial?.path);
    final needlePath = await resolveAssetPath(
        config.needle?.assetType, config.needle?.path);

    // 3. Calculate gauge pixel size
    final sizeFactor = config.sizeFactor ?? 0.25;
    // Use the smaller dimension as reference for sizing
    final refDimension = min(videoInfo.width, videoInfo.height);
    final gaugeSize = (refDimension * sizeFactor).round();
    // Ensure even number for FFmpeg compatibility
    final gs = gaugeSize % 2 == 0 ? gaugeSize : gaugeSize + 1;

    debugPrint('[GaugeExport] Gauge size: ${gs}px '
        '(${(sizeFactor * 100).toStringAsFixed(0)}% of ${refDimension}px)');

    // 4. Sample speed data
    final imperial = config.imperial ?? false;
    final List<_SpeedSample> samples = _processRawData(positionData, imperial: imperial);

    print("Printing speed Samples");
    for(_SpeedSample sample in samples){
      print("   ${sample.timeSec}: ${sample.speedInUnit}");
    }

    // Find max speed for dial range
    double maxSpeed = 0;
    for (final s in samples) {
      if (s.speedInUnit > maxSpeed) maxSpeed = s.speedInUnit;
    }
    final dialMax = dialMaxSpeed(maxSpeed);
    debugPrint('[GaugeExport] Max speed: ${maxSpeed.toStringAsFixed(1)} '
        '${imperial ? "mph" : "km/h"}, dial range: 0–$dialMax');

    // 5. Build rotation expression
    final dial = config.dial ?? const Dial();
    final rotExpr = _buildRotationExpression(samples, dialMax, dial);
    debugPrint('[GaugeExport] Rotation expression length: ${rotExpr.length} chars');
    // CHANGED: We now pass the unit separately in the drawtext filter, not the expression
    final speedMathExpr = _buildSpeedTextExpression(samples);
    final unitLabel = imperial ? "mph" : "km/h";

    // 7. Build filter_complex
    // We apply drawtext to the [gauge] layer (the dial + needle composite)
    // before overlaying it on the main video.

    // Relative sizes based on gauge size (gs)
    final fontSizeSpeed = (gs * 0.14).round(); // 12% of gauge size
    final fontSizeBrand = (gs * 0.10).round(); // 10% of gauge size
    final verticalPadding = (gs * 0.05).round(); // 5% padding from bottom


    // 6. Determine placement
    final placement = config.labsPlacement;
    final overlayPos = placement.overlayPosition(margin: 20);

    // 7. Build filter_complex
    //
    // [1:v] = dial image → scale to gauge size
    // [2:v] = needle image → scale to gauge size → rotate by speed expression
    // Overlay needle on dial → overlay composite on source video
    // NOTE: Use bare commas for filter separators, and \, only inside
    // expressions (like rotate=). The command wraps this in single quotes
    // so ffmpeg_kit preserves backslashes literally for FFmpeg.

    String filterComplex =
        '[1:v]format=rgba,scale=$gs:$gs[dial];'
        '[2:v]format=rgba,scale=$gs:$gs,'
        'rotate=angle=\'$rotExpr\':ow=$gs:oh=$gs:fillcolor=none[nrot];'
        '[dial][nrot]overlay=0:0:format=auto[base_gauge];';


    final ByteData data = await rootBundle.load("assets/fonts/RacingSansOne-Regular.ttf");
    final Uint8List bytes = data.buffer.asUint8List();

    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/RacingSansOne-Regular.ttf');
    await file.writeAsBytes(bytes, flush: true);
    String fontFile = file.path;

    // // Add Dynamic Speed Text
    filterComplex += '[base_gauge]drawtext='
        'text=\'%{eif\\:$speedMathExpr\\:d} $unitLabel\':'
        'fontcolor=white:'
        'fontfile=$fontFile:'
        'fontsize=$fontSizeSpeed:'
        'x=(w-text_w)/2:'
        'y=h-text_h-text_h-$verticalPadding'
        '[gauge_with_speed];';


    // filterComplex += '[base_gauge]drawtext='
    //     'text=\'%{eif\\:$speedMathExpr\\:d}\':'
    //     'fontfile=$fontFile:'
    //     'fontcolor=white:'
    //     'fontsize=$fontSizeSpeed:'
    //     'x=(w/2)-(text_w)-10:'
    //     'y=h-$fontSizeSpeed-$verticalPadding'
    //     '[speed_layer];';
    //
    // filterComplex +=
    // '[speed_layer]drawtext='
    //     'text=\'$unitLabel\':'
    //     'fontfile=$fontFile:'
    //     'fontcolor=white:'
    //     'fontsize=${fontSizeSpeed*0.8}:'
    //     'x=(w/2)-10:'
    //     'y=h-${fontSizeSpeed*0.8}-$verticalPadding'
    //     '[gauge_with_speed];';



    // Add Static Branding (TurboGauge) if enabled
    // Assuming config has a boolean for watermark. If not, add one to your model.
    bool showWatermark = true; // Replace with config.showWatermark if available
    String lastLabel = '[gauge_with_speed]';

    if(showWatermark){
        filterComplex += '${lastLabel}drawtext='
      'text=\'TURBOGAUGE\':'
      'fontcolor=white:'
      'fontfile=$fontFile:'
      'fontsize=$fontSizeBrand:'
      'x=(w-text_w)/2:'
      'y=h-text_h'
      '[gauge_final];';
      lastLabel = '[gauge_final]';
    } else {
      lastLabel = '[gauge_with_speed]';
    }

    // Final overlay onto the main video
    filterComplex += '[0:v]$lastLabel overlay=$overlayPos:format=auto[out]';

    final tempDir = await getTemporaryDirectory();
    final filterFile = File('${tempDir.path}/filter.txt');
    await filterFile.writeAsString(filterComplex);

    // 8. Full command
    // Use single quotes around filter_complex so ffmpeg_kit's argument
    // parser preserves backslash-escapes (\,) literally for FFmpeg.
    // Double quotes would strip \, → , and break expression parsing.
    final command = '-y '
        '-i "$inputVideoPath" '
        '-loop 1 -i "$dialPath" '
        '-loop 1 -i "$needlePath" '
        // '-filter_complex "$filterComplex" ' // Use double quotes outside
        '-filter_complex_script ${filterFile.path} '
        '-map "[out]" '
        '-map 0:a? '
        '-shortest '                  // Stop when video ends -> CRITICAL
        '-c:v mpeg4 '
        '-q:v 3 '
        '-c:a aac '
        '-b:a 192k '
        '"$outputPath"';

    debugPrint('[GaugeExport] Command length: ${command.length} chars');
    return command;
  }
}
