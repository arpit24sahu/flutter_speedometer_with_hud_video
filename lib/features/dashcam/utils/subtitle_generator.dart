import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class SubtitleGenerator {
  Future<String> getFontPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final fontsDir = Directory('${docsDir.path}/fonts');
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    
    final fontFile = File('${fontsDir.path}/Roboto-Regular.ttf');
    
    // Extract font from assets to a real file path in the dedicated directory for FFmpeg to access
    if (!await fontFile.exists()) {
      final byteData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final buffer = byteData.buffer;
      await fontFile.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }

    // Also extract RobotoMono-Bold for the speed HUD overlay
    final monoFontFile = File('${fontsDir.path}/RobotoMono-Bold.ttf');
    if (!await monoFontFile.exists()) {
      final byteData = await rootBundle.load('assets/fonts/RobotoMono-Bold.ttf');
      final buffer = byteData.buffer;
      await monoFontFile.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    
    return fontFile.path;
  }

  String _formatAssTime(int milliseconds) {
    final int hours = milliseconds ~/ 3600000;
    final int minutes = (milliseconds % 3600000) ~/ 60000;
    final int seconds = (milliseconds % 60000) ~/ 1000;
    final int centiseconds = (milliseconds % 1000) ~/ 10;
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}.${twoDigits(centiseconds)}';
  }

  DateTime _parseTime(Map<String, dynamic> meta) {
    if (meta['ts'] != null) {
      return DateTime.parse(meta['ts'] as String);
    } else if (meta['timestamp'] != null) {
      return DateTime.parse(meta['timestamp'] as String);
    } else if (meta['timestampNs'] != null) {
      final ms = (meta['timestampNs'] as num).toInt() ~/ 1000000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.now();
  }

  /// Generates an ASS subtitle file with overlays positioned relative to the
  /// video dimensions.
  ///
  /// Layout:
  ///   Top-right     → Speed (large bold number + smaller unit)
  ///   Bottom-left   → Single stacked block (guaranteed order via \N newlines):
  ///                    Line 1: "TurboGauge" branding
  ///                    Line 2: Date/time
  ///                    Line 3: GPS coordinates
  ///
  /// Sizing: All elements are sized relative to the VIDEO WIDTH, which is
  /// always capped at ≤1080 by the export service. This gives identical pixel
  /// sizes in both portrait and landscape — the simplest universal solution.
  Future<File?> generateAssSubtitle(
    File jsonFile,
    String speedUnit, {
    required int videoWidth,
    required int videoHeight,
  }) async {
    if (!await jsonFile.exists()) return null;

    String content = await jsonFile.readAsString();
    if (content.isEmpty) return null;

    // Handle potentially unclosed JSON array if recording was interrupted
    content = content.trim();
    if (content.startsWith('[') && !content.endsWith(']')) {
      if (content.endsWith(',')) {
        content = content.substring(0, content.length - 1);
      }
      content += ']';
    }

    final List<dynamic> rawList;
    try {
      rawList = jsonDecode(content);
    } catch (_) {
      return null;
    }

    if (rawList.isEmpty) return null;

    final metadata = rawList.cast<Map<String, dynamic>>();

    // ── Universal sizing based on video width ───────────────────
    //
    // The export service caps width to ≤1080, so this reference is always
    // consistent. Both portrait (1080×1920) and landscape (1080×607)
    // produce the SAME pixel-size text, which looks natural since you
    // view both on the same phone screen.
    //
    //   width=1080 → speed=38px, brand=27px, info=17px
    //   width=720  → speed=25px, brand=18px, info=11px  (scales for lower res)
    //
    final int w = videoWidth;
    final int speedFontSize = (0.035 * w).round(); // ~38px at 1080
    final int speedUnitFontSize = (0.018 * w).round(); // ~19px at 1080
    final int brandFontSize = (0.025 * w).round(); // ~27px at 1080
    final int infoFontSize = (0.016 * w).round(); // ~17px at 1080
    final int speedMargin = (0.012 * w).round(); // ~13px at 1080

    final StringBuffer ass = StringBuffer();
    ass.writeln('[Script Info]');
    ass.writeln('ScriptType: v4.00+');
    ass.writeln('PlayResX: $videoWidth');
    ass.writeln('PlayResY: $videoHeight');
    ass.writeln('');
    ass.writeln('[V4+ Styles]');
    ass.writeln(
      'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, '
      'OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, '
      'ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, '
      'Alignment, MarginL, MarginR, MarginV, Encoding',
    );

    // Speed — top-right (Alignment 9 = top-right in ASS numpad layout)
    ass.writeln(
      'Style: SpeedStyle,Roboto Mono,$speedFontSize,'
      '&H00FFFFFF,&H000000FF,&H00000000,&H80000000,'
      '-1,0,0,0,100,100,0,0,1,2,2,9,$speedMargin,$speedMargin,$speedMargin,1',
    );

    // Bottom-left block (Alignment 1 = bottom-left)
    // Uses brandFontSize as the base; time and GPS lines are resized inline.
    ass.writeln(
      'Style: BottomInfoStyle,Roboto,$brandFontSize,'
      '&H00FFFFFF,&H000000FF,&H00000000,&H80000000,'
      '-1,0,0,0,100,100,0,0,1,2,1,1,0,0,0,1',
    );

    ass.writeln('');
    ass.writeln('[Events]');
    ass.writeln(
      'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
    );

    final DateTime firstDt = _parseTime(metadata.first);

    for (int i = 0; i < metadata.length; i++) {
      final currentMeta = metadata[i];
      final DateTime currentDt = _parseTime(currentMeta);
      final int startMs = currentDt.difference(firstDt).inMilliseconds;

      int endMs;
      if (i < metadata.length - 1) {
        final DateTime nextDt = _parseTime(metadata[i + 1]);
        endMs = nextDt.difference(firstDt).inMilliseconds;
      } else {
        endMs = startMs + 3600000;
      }

      double speed =
          (currentMeta['speed'] as num?)?.toDouble() ??
          (currentMeta['speed_kmh'] as num?)?.toDouble() ??
          0.0;
      if (speedUnit == 'mph') {
        speed = speed * 0.621371;
      }

      final lat = (currentMeta['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (currentMeta['lng'] as num?)?.toDouble() ?? 0.0;

      int currentSliceStartMs = startMs;
      while (currentSliceStartMs < endMs) {
        int sliceEndMs = currentSliceStartMs + 1000;
        if (sliceEndMs > endMs) {
          sliceEndMs = endMs;
        }

        final startAss = _formatAssTime(currentSliceStartMs);
        final endAss = _formatAssTime(sliceEndMs);

        final DateTime sliceDt = firstDt.add(
          Duration(milliseconds: currentSliceStartMs),
        );
        final String timeText = sliceDt.toString().substring(0, 19);
        final gpsText =
            '${lat.toStringAsFixed(5)}°N, ${lng.toStringAsFixed(5)}°E';

        // Speed — top-right
        final speedText =
            '${speed.toStringAsFixed(0)} {\\fs$speedUnitFontSize\\alpha&H89&}$speedUnit';
        ass.writeln(
          'Dialogue: 0,$startAss,$endAss,SpeedStyle,,0,0,0,,$speedText',
        );

        // Bottom-left — single Dialogue with \N to guarantee line ordering:
        //   Line 1: TurboGauge (brand size — style default)
        //   Line 2: time       (smaller, light grey)
        //   Line 3: GPS        (smaller, grey, monospace)
        final bottomText =
            'TurboGauge\\N'
            '{\\fs$infoFontSize\\c&HE0E0E0&}$timeText\\N'
            '{\\fs$infoFontSize\\c&HC0C0C0&\\fnRoboto Mono}$gpsText';
        ass.writeln(
          'Dialogue: 0,$startAss,$endAss,BottomInfoStyle,,0,0,0,,$bottomText',
        );

        currentSliceStartMs += 1000;
      }
    }

    final assPath = jsonFile.path.replaceAll('.json', '.ass');
    final assFile = File(assPath);
    await assFile.writeAsString(ass.toString());

    return assFile;
  }
}
