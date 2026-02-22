import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speedometer/features/labs/models/gauge_customization.dart';
import 'package:speedometer/features/labs/services/gauge_export_service.dart';
import 'package:speedometer/features/speedometer/models/position_data.dart';
import 'package:speedometer/services/remote_asset_service.dart';

/// A single speed sample at a point in time.
class SpeedSample {
  final double timeSec; // seconds from video start
  final double speedInUnit; // speed in km/h or mph

  const SpeedSample(this.timeSec, this.speedInUnit);
}

/// Configuration for the text overlay drawn on each gauge frame.
class _TextOverlayConfig {
  final bool showSpeed;
  final bool showBranding;
  final ui.Color textColor;
  final String unitLabel;

  /// Font sizes & padding are relative to the render canvas size,
  /// matching the ratios from the original FFmpeg drawtext approach.
  final double fontSizeSpeed; // 14% of canvas
  final double fontSizeBrand; // 10% of canvas
  final double verticalPadding; // 5% padding from bottom

  const _TextOverlayConfig({
    required this.showSpeed,
    required this.showBranding,
    required this.textColor,
    required this.unitLabel,
    required this.fontSizeSpeed,
    required this.fontSizeBrand,
    required this.verticalPadding,
  });
}

/// Service that generates transparent gauge PNG frames and then builds
/// an FFmpeg overlay command.
///
/// **Why this approach?**
/// The original [GaugeExportService] embeds a piecewise-linear rotation
/// expression directly in the FFmpeg filter graph. For long videos with
/// many speed samples this creates a command string that exceeds FFmpeg's
/// internal parser limits. By pre-rendering the gauge animation as a
/// 2fps PNG sequence in Flutter (using `dart:ui`) and then overlaying it
/// with a simple FFmpeg command, the command stays short regardless of
/// video length.
class GaugeExportService2 {
  GaugeExportService2._();

  // ─── Constants ───

  /// Frame rate for the gauge overlay image sequence.
  /// 2fps matches the ~500ms GPS sampling interval — no need for higher.
  static const double _overlayFps = 2.0;

  /// Size (px) of each rendered gauge frame (square canvas).
  /// We render at a fixed high resolution and let FFmpeg scale to the
  /// actual video-relative gauge size. 512px is a good balance of
  /// quality vs render speed.
  static const int _renderSize = 512;

  /// Font family name used after loading the custom font via
  /// [ui.loadFontFromList].
  static const String _fontFamily = 'RacingSansOneExport';

  // ─── Public API ───

  /// Orchestrates the full export preparation:
  ///   1. Processes speed data
  ///   2. Probes the video
  ///   3. Loads the custom font
  ///   4. Renders all gauge PNG frames to a temp directory
  ///   5. Returns the FFmpeg command string + the temp directory path
  ///
  /// The caller is responsible for:
  ///   - Executing the FFmpeg command
  ///   - Cleaning up [tempDir] after the command completes
  ///
  /// [onProgress] is called with a value 0.0–1.0 as frames are rendered.
  static Future<GaugeExportResult> buildCommand({
    required GaugeCustomization config,
    required String inputVideoPath,
    required Map<int, PositionData> positionData,
    required String outputPath,
    void Function(double progress)? onProgress,
  }) async {
    final totalStopwatch = Stopwatch()..start();

    // ── 1. Process speed data ──
    final imperial = config.isMetric ?? false;
    final samples = _processRawData(positionData, imperial: imperial);

    debugPrint('[GaugeExport2] ${samples.length} speed samples processed');

    // ── 2. Probe video ──
    final videoInfo = await GaugeExportService.probeVideo(inputVideoPath);
    debugPrint('[GaugeExport2] Video: ${videoInfo.width}×${videoInfo.height}, '
        '${videoInfo.durationSec}s, ${videoInfo.fps}fps');

    // ── 3. Calculate gauge sizing ──
    final sizeFactor = config.sizeFactor ?? 0.25;
    final refDimension = min(videoInfo.width, videoInfo.height);
    final gaugeSize = (refDimension * sizeFactor).round();
    final gs = gaugeSize % 2 == 0 ? gaugeSize : gaugeSize + 1;

    debugPrint('[GaugeExport2] Gauge size: ${gs}px '
        '(${(sizeFactor * 100).toStringAsFixed(0)}% of ${refDimension}px)');

    // ── 4. Find max speed and dial range ──
    double maxSpeed = 0;
    for (final s in samples) {
      if (s.speedInUnit > maxSpeed) maxSpeed = s.speedInUnit;
    }
    final dialMax = GaugeExportService.dialMaxSpeed(maxSpeed);
    debugPrint('[GaugeExport2] Max speed: ${maxSpeed.toStringAsFixed(1)} '
        '${imperial ? "mph" : "km/h"}, dial range: 0–$dialMax');

    // ── 5. Calculate frames needed ──
    final totalFrames = (videoInfo.durationSec * _overlayFps).ceil();
    debugPrint('[GaugeExport2] Total frames to render: $totalFrames '
        '(${_overlayFps}fps × ${videoInfo.durationSec}s)');

    // ── 6. Load dial & needle images ──
    final dial = config.dial ?? const Dial();
    final needle = config.needle ?? const Needle();

    final ui.Image? dialImage = await _loadImage(
      dial.assetType,
      dial.path,
      tintColor: (dial.colorEditable == true) ? config.dialColor : null,
    );
    final ui.Image? needleImage = await _loadImage(
      needle.assetType,
      needle.path,
      tintColor: (needle.colorEditable == true) ? config.needleColor : null,
    );

    if (dialImage == null || needleImage == null) {
      throw Exception('Failed to load dial or needle image. '
          'dial=${dial.path}, needle=${needle.path}');
    }

    debugPrint('[GaugeExport2] Dial image: '
        '${dialImage.width}×${dialImage.height}');
    debugPrint('[GaugeExport2] Needle image: '
        '${needleImage.width}×${needleImage.height}');

    // ── 7. Load custom font for text overlays ──
    final showSpeed = config.showSpeed ?? true;
    final showBranding = config.showBranding ?? true;

    if (showSpeed || showBranding) {
      await _loadFont();
      debugPrint('[GaugeExport2] Custom font loaded: $_fontFamily');
    }

    // Build text config matching the original GaugeExportService ratios:
    //   fontSizeSpeed = gaugeSize * 0.14
    //   fontSizeBrand = gaugeSize * 0.10
    //   verticalPadding = gaugeSize * 0.05
    // Since we render at _renderSize and FFmpeg later scales to gs,
    // we use _renderSize as the base for these proportions.
    final textConfig = _TextOverlayConfig(
      showSpeed: showSpeed,
      showBranding: showBranding,
      textColor: config.textColor ?? const ui.Color(0xFFFFFFFF),
      unitLabel: imperial ? 'mph' : 'km/h',
      fontSizeSpeed: _renderSize * 0.14,
      fontSizeBrand: _renderSize * 0.10,
      verticalPadding: _renderSize * 0.03,
    );

    // ── 8. Create temp directory for frames ──
    final systemTempDir = await getTemporaryDirectory();
    final framesDir = Directory(
        '${systemTempDir.path}/gauge_frames_${DateTime.now().millisecondsSinceEpoch}');
    await framesDir.create(recursive: true);

    debugPrint('[GaugeExport2] Frames directory: ${framesDir.path}');

    // ── 9. Render frames ──
    final renderStopwatch = Stopwatch()..start();
    final halfSweepRad = dial.halfSweep * pi / 180;
    final totalSweepRad = dial.totalSweep * pi / 180;

    for (int i = 0; i < totalFrames; i++) {
      final frameTimeSec = i / _overlayFps;

      // Interpolate speed at this time
      final speed = _interpolateSpeed(samples, frameTimeSec);

      // Compute needle angle
      final fraction = (speed / dialMax).clamp(0.0, 1.0);
      final angleRad = -halfSweepRad + fraction * totalSweepRad;

      // Render the frame (with text overlays)
      final pngBytes = await _renderGaugeFrame(
        dialImage,
        needleImage,
        angleRad,
        speedValue: speed,
        textConfig: textConfig,
      );

      // Write to disk
      final frameIndex = i.toString().padLeft(6, '0');
      final framePath = '${framesDir.path}/frame_$frameIndex.png';
      await File(framePath).writeAsBytes(pngBytes);

      // Report progress
      onProgress?.call((i + 1) / totalFrames);

      // Log every 10 frames
      if ((i + 1) % 10 == 0 || i == totalFrames - 1) {
        debugPrint('[GaugeExport2] Rendered ${i + 1}/$totalFrames frames '
            '(${renderStopwatch.elapsedMilliseconds}ms elapsed)');
      }
    }

    renderStopwatch.stop();
    debugPrint('[GaugeExport2] Frame rendering complete: '
        '${renderStopwatch.elapsedMilliseconds}ms for $totalFrames frames');

    // Dispose loaded images
    dialImage.dispose();
    needleImage.dispose();

    // ── 10. Determine placement ──
    final placement = config.labsPlacement;
    final overlayPos = placement.overlayPosition(margin: 20);

    // ── 11. Build FFmpeg command ──
    //
    // Inputs:
    //   [0] = source video
    //   [1] = PNG image sequence at 2fps
    //
    // Filter:
    //   Scale the PNG sequence to the gauge size, then overlay at the
    //   configured position. shortest=1 ensures overlay stops when
    //   the video ends.
    final command = '-y '
        '-i "$inputVideoPath" '
        '-framerate ${_overlayFps.toStringAsFixed(0)} '
        '-i "${framesDir.path}/frame_%06d.png" '
        '-filter_complex "'
        '[1:v]format=rgba,scale=$gs:$gs[gauge];'
        '[0:v][gauge]overlay=$overlayPos:shortest=1[out]'
        '" '
        '-map "[out]" '
        '-map 0:a? '
        '-c:v mpeg4 '
        '-q:v 3 '
        '-c:a aac '
        '-b:a 192k '
        '"$outputPath"';

    totalStopwatch.stop();
    debugPrint('[GaugeExport2] Command built in '
        '${totalStopwatch.elapsedMilliseconds}ms total');
    debugPrint('[GaugeExport2] Command length: ${command.length} chars');
    debugPrint('[GaugeExport2] Command: $command');

    return GaugeExportResult(
      command: command,
      tempFramesDir: framesDir,
      totalFrames: totalFrames,
      renderTimeMs: renderStopwatch.elapsedMilliseconds,
      totalBuildTimeMs: totalStopwatch.elapsedMilliseconds,
      videoInfo: videoInfo,
      gaugeSize: gs,
      dialMax: dialMax,
    );
  }

  // ─── Speed Data Processing ───

  /// Converts raw position data to sorted [SpeedSample] list.
  static List<SpeedSample> _processRawData(
    Map<int, PositionData> positionData, {
    required bool imperial,
  }) {
    if (positionData.isEmpty) return [const SpeedSample(0, 0)];

    final sortedEntries = positionData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final conversionFactor = imperial ? 2.23694 : 3.6;
    final samples = <SpeedSample>[];

    for (final entry in sortedEntries) {
      final t = entry.key / 1000.0;
      final s = entry.value.speed * conversionFactor;
      if (samples.isNotEmpty && t <= samples.last.timeSec) continue;
      samples.add(SpeedSample(t, s.clamp(0, double.infinity)));
    }

    // Ensure we start at 0.0s
    if (samples.isNotEmpty && samples.first.timeSec > 0) {
      samples.insert(0, SpeedSample(0.0, samples.first.speedInUnit));
    }

    return samples;
  }

  /// Linearly interpolates speed at [timeSec] from sorted samples.
  static double _interpolateSpeed(List<SpeedSample> samples, double timeSec) {
    if (samples.isEmpty) return 0;
    if (timeSec <= samples.first.timeSec) return samples.first.speedInUnit;
    if (timeSec >= samples.last.timeSec) return samples.last.speedInUnit;

    // Find the bracketing pair
    int i = 1;
    while (i < samples.length && samples[i].timeSec < timeSec) {
      i++;
    }

    final prev = samples[i - 1];
    final next = samples[i];
    final dt = next.timeSec - prev.timeSec;
    if (dt <= 0) return prev.speedInUnit;

    final fraction = (timeSec - prev.timeSec) / dt;
    return prev.speedInUnit + (next.speedInUnit - prev.speedInUnit) * fraction;
  }

  // ─── Font Loading ───

  /// Loads the RacingSansOne font from assets and registers it with
  /// the engine so [ui.ParagraphBuilder] can reference it by family name.
  /// Safe to call multiple times — subsequent calls are no-ops.
  static bool _fontLoaded = false;

  static Future<void> _loadFont() async {
    if (_fontLoaded) return;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/RacingSansOne-Regular.ttf',
      );
      await ui.loadFontFromList(
        fontData.buffer.asUint8List(),
        fontFamily: _fontFamily,
      );
      _fontLoaded = true;
    } catch (e) {
      debugPrint('[GaugeExport2] Failed to load font: $e');
    }
  }

  // ─── Image Loading ───

  /// Loads an image from the given asset type and path into a [ui.Image].
  /// If [tintColor] is non-null, the image is redrawn with a
  /// `ColorFilter.mode(tintColor, BlendMode.srcIn)` applied.
  static Future<ui.Image?> _loadImage(
    AssetType? assetType,
    String? path, {
    ui.Color? tintColor,
  }) async {
    if (path == null || path.isEmpty) return null;

    try {
      Uint8List bytes;

      if (assetType == AssetType.asset) {
        final data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List();
      } else if (assetType == AssetType.network) {
        final cachedBytes = await RemoteAssetService().getBytes(path);
        if (cachedBytes == null) return null;
        bytes = cachedBytes;
      } else {
        // File path
        final file = File(path);
        if (!await file.exists()) return null;
        bytes = await file.readAsBytes();
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final originalImage = frameInfo.image;

      // If no tint, return original
      if (tintColor == null) return originalImage;

      // Create a tinted copy using ColorFilter
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint =
          ui.Paint()
            ..colorFilter = ui.ColorFilter.mode(tintColor, ui.BlendMode.srcIn);

      canvas.drawImage(originalImage, Offset.zero, paint);

      final picture = recorder.endRecording();
      final tintedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );

      // Dispose original since we have the tinted copy
      originalImage.dispose();
      picture.dispose();

      return tintedImage;
    } catch (e) {
      debugPrint('[GaugeExport2] Failed to load image ($path): $e');
      return null;
    }
  }

  // ─── Frame Rendering ───

  /// Renders a single transparent gauge frame with:
  ///   1. The dial image (static background)
  ///   2. The needle image (rotated by [needleAngleRad])
  ///   3. Speed text (e.g. "85 km/h") — if [textConfig.showSpeed]
  ///   4. Branding text ("TURBOGAUGE") — if [textConfig.showBranding]
  ///
  /// Text positioning matches the original FFmpeg drawtext approach:
  ///   - Speed text: centered horizontally,
  ///       y = canvasHeight - 2 × speedTextHeight - verticalPadding
  ///   - Brand text: centered horizontally,
  ///       y = canvasHeight - brandTextHeight
  static Future<Uint8List> _renderGaugeFrame(
    ui.Image dialImage,
    ui.Image needleImage,
    double needleAngleRad, {
    required double speedValue,
    required _TextOverlayConfig textConfig,
  }) async {
    final size = _renderSize.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final center = size / 2.0;
    final dstRect = Rect.fromLTWH(0, 0, size, size);

    // ── Layer 1: Dial ──
    final dialSrcRect = Rect.fromLTWH(
      0,
      0,
      dialImage.width.toDouble(),
      dialImage.height.toDouble(),
    );
    canvas.drawImageRect(dialImage, dialSrcRect, dstRect, ui.Paint());

    // ── Layer 2: Rotated needle ──
    canvas.save();
    canvas.translate(center, center);
    canvas.rotate(needleAngleRad);
    canvas.translate(-center, -center);

    final needleSrcRect = Rect.fromLTWH(
      0,
      0,
      needleImage.width.toDouble(),
      needleImage.height.toDouble(),
    );
    canvas.drawImageRect(needleImage, needleSrcRect, dstRect, ui.Paint());
    canvas.restore();

    // ── Text layout (bottom-up stacking) ──
    //
    // Vertical stacking from the bottom of the canvas:
    //   ┌─────────────────────────┐
    //   │                         │
    //   │      (dial + needle)    │
    //   │                         │
    //   │    ┌─ speed text ─┐     │  ← above branding + padding
    //   │    │  85 km/h     │     │
    //   │    └──────────────┘     │
    //   │      (padding gap)      │
    //   │    ┌─ brand text ──┐    │  ← touches bottom baseline
    //   │    │  TURBOGAUGE   │    │
    //   └────┴───────────────┴────┘
    //
    // Horizontal: both paragraphs are laid out at full canvas width
    // with TextAlign.center, so we draw at x = 0.

    // Calculate branding height first (needed for speed text y)
    double brandingHeight = 0;

    // ── Layer 4: Branding text (bottom baseline) ──
    if (textConfig.showBranding) {
      final brandParagraph = _buildParagraph(
        text: 'TURBOGAUGE',
        fontSize: textConfig.fontSizeBrand,
        color: textConfig.textColor,
        maxWidth: size,
      );

      brandingHeight = brandParagraph.height;

      // Branding sits at the very bottom of the canvas
      final brandY = size - brandingHeight;
      canvas.drawParagraph(brandParagraph, Offset(0, brandY));
    }

    // ── Layer 3: Speed text (above branding) ──
    if (textConfig.showSpeed) {
      final speedText = '${speedValue.toInt()} ${textConfig.unitLabel}';
      final speedParagraph = _buildParagraph(
        text: speedText,
        fontSize: textConfig.fontSizeSpeed,
        color: textConfig.textColor,
        maxWidth: size,
      );

      // Speed text sits above: branding height + padding gap
      final speedY =
          size -
          brandingHeight -
          // textConfig.verticalPadding -
          speedParagraph.height;
      canvas.drawParagraph(speedParagraph, Offset(0, speedY));
    }

    // ── Encode to PNG ──
    final picture = recorder.endRecording();
    final image = await picture.toImage(_renderSize, _renderSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    picture.dispose();
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to encode gauge frame to PNG');
    }

    return byteData.buffer.asUint8List();
  }

  /// Builds a [ui.Paragraph] with the given text, font, size and color.
  /// Uses the pre-loaded RacingSansOne font to match the original styling.
  static ui.Paragraph _buildParagraph({
    required String text,
    required double fontSize,
    required ui.Color color,
    required double maxWidth,
  }) {
    final style = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontFamily: _fontFamily,
      maxLines: 1,
    );

    final builder =
        ui.ParagraphBuilder(style)
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w400,
            ),
          )
          ..addText(text);

    final paragraph =
        builder.build()..layout(ui.ParagraphConstraints(width: maxWidth));

    return paragraph;
  }

  // ─── Cleanup ───

  /// Deletes all temporary frame files. Call this in a finally block
  /// after the FFmpeg command completes (success or failure).
  static Future<void> cleanup(Directory tempFramesDir) async {
    try {
      if (await tempFramesDir.exists()) {
        await tempFramesDir.delete(recursive: true);
        debugPrint('[GaugeExport2] Cleaned up temp frames: '
            '${tempFramesDir.path}');
      }
    } catch (e) {
      debugPrint('[GaugeExport2] Cleanup failed: $e');
    }
  }
}

/// Result of the [GaugeExportService2.buildCommand] call.
///
/// Contains the FFmpeg command and metadata needed for analytics
/// and cleanup.
class GaugeExportResult {
  /// The full FFmpeg command string ready to execute.
  final String command;

  /// The temporary directory containing the PNG frame sequence.
  /// Must be cleaned up after the FFmpeg command completes.
  final Directory tempFramesDir;

  /// Total number of gauge frames rendered.
  final int totalFrames;

  /// Time taken to render all frames (ms).
  final int renderTimeMs;

  /// Total time for buildCommand (including probe + render, ms).
  final int totalBuildTimeMs;

  /// Video metadata.
  final VideoInfo videoInfo;

  /// Final gauge pixel size.
  final int gaugeSize;

  /// Dial max speed used for scaling.
  final double dialMax;

  const GaugeExportResult({
    required this.command,
    required this.tempFramesDir,
    required this.totalFrames,
    required this.renderTimeMs,
    required this.totalBuildTimeMs,
    required this.videoInfo,
    required this.gaugeSize,
    required this.dialMax,
  });
}
