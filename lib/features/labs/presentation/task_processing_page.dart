import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/badges/badge_manager.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/models/gauge_customization.dart';
import 'package:speedometer/features/labs/data/gauge_options.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:speedometer/features/labs/services/gauge_export_service.dart';
import 'package:speedometer/features/premium/widgets/premium_feature_gate.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';
import 'package:speedometer/packages/gal.dart';
import 'package:speedometer/services/remote_asset_service.dart';
import 'package:get_it/get_it.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class TaskProcessingPage extends StatefulWidget {
  final ProcessingTask task;

  const TaskProcessingPage({super.key, required this.task});

  @override
  State<TaskProcessingPage> createState() => _TaskProcessingPageState();
}

class _TaskProcessingPageState extends State<TaskProcessingPage> {
  // ─── State ───
  late GaugeCustomization _config;
  late GaugeCustomizationOption _selectedOption;
  Needle? _selectedNeedle;

  bool _exportRawVideo = false;
  bool _isExporting = false;
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();

    // Auto-select first gauge and first needle
    _selectedOption = kGaugeOptions.first;
    _selectedNeedle =
        _selectedOption.hasNeedles ? _selectedOption.needles!.first : null;

    _config = GaugeCustomization(
      dial: _selectedOption.dial,
      needle: _selectedNeedle,
      dialStyle: DialStyle.analog,
      showSpeed: true,
      showBranding: true,
      isMetric: false,
      gaugeAspectRatio: 1.4, // 7:5
      sizeFactor: 0.25,
      placement: GaugePlacement.topRight,
    );

    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    if (widget.task.videoFilePath == null) return;
    try {
      final path = await VideoThumbnail.thumbnailFile(
        video: widget.task.videoFilePath!,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      );
      if (mounted) setState(() => _thumbnailPath = path);
    } catch (_) {}
  }

  void _updateConfig(GaugeCustomization Function(GaugeCustomization) updater) {
    setState(() {
      _config = updater(_config);
    });
  }

  // ─── Gauge + Needle Bottom Sheet ───

  void _showGaugeAndNeedleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasNeedles = _selectedOption.hasNeedles;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─ Section: Gauge ─
                  const Text(
                    'Select Gauge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: kGaugeOptions.length,
                    itemBuilder: (context, index) {
                      final option = kGaugeOptions[index];
                      final isSelected = option.id == _selectedOption.id;
                      return _GaugeTile(
                        option: option,
                        isSelected: isSelected,
                        onTap: () {
                          setSheetState(() {
                            _selectedOption = option;
                            _selectedNeedle = option.hasNeedles
                                ? option.needles!.first
                                : null;
                          });
                          setState(() {
                            _updateConfig((c) => c.copyWith(
                                  dial: option.dial,
                                  needle: _selectedNeedle,
                                ));
                          });
                        },
                      );
                    },
                  ),

                  // ─ Section: Needle (only if gauge has needles) ─
                  if (hasNeedles) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text(
                      'Select Needle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedOption.needles!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final needle = _selectedOption.needles![index];
                          final isNeedleSelected =
                              needle.id == _selectedNeedle?.id;
                          return _NeedleTile(
                            needle: needle,
                            isSelected: isNeedleSelected,
                            onTap: () {
                              setSheetState(() {
                                _selectedNeedle = needle;
                              });
                              setState(() {
                                _updateConfig(
                                    (c) => c.copyWith(needle: needle));
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ─ Done Button ─
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Placement Bottom Sheet ───

  void _showPlacementSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Gauge Placement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: GaugePlacement.values.length,
                  itemBuilder: (context, index) {
                    final placement = GaugePlacement.values[index];
                    final isSelected = placement == _config.labsPlacement;
                    return GestureDetector(
                      onTap: () {
                        _updateConfig((c) => c.copyWith(placement: placement));
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.grey[700]!,
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected
                              ? Colors.blueAccent.withOpacity(0.15)
                              : Colors.grey[850],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              placement.icon,
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white54,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              placement.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : Colors.white70,
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ─── Text Color Bottom Sheet ───

  void _showTextColorSheet() {
    const presetColors = <Color>[
      Colors.white,
      Color(0xFFE0E0E0),
      Color(0xFF9E9E9E),
      Colors.black,
      Color(0xFFFF1744),
      Color(0xFFFF9100),
      Color(0xFFFFEA00),
      Color(0xFF00E676),
      Color(0xFF00B0FF),
      Color(0xFFD500F9),
      Color(0xFFFF4081),
      Color(0xFF00BFA5),
    ];

    final currentColor = _config.textColor ?? Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Color previewColor = currentColor;
        final hexController = TextEditingController(
          text: _colorToHex(currentColor),
        );

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Text Color',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: presetColors.length,
                    itemBuilder: (ctx, index) {
                      final color = presetColors[index];
                      final isSelected = color.value == previewColor.value;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            previewColor = color;
                            hexController.text = _colorToHex(color);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.blueAccent
                                      : Colors.grey[600]!,
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: Colors.blueAccent.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ]
                                    : null,
                          ),
                          child:
                              isSelected
                                  ? Icon(
                                    Icons.check,
                                    color:
                                        color.computeLuminance() > 0.5
                                            ? Colors.black
                                            : Colors.white,
                                    size: 20,
                                  )
                                  : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  const Text(
                    'Custom Hex Color',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: previewColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[600]!,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hexController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            prefixText: '#',
                            prefixStyle: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'monospace',
                              fontSize: 16,
                            ),
                            hintText: 'FFFFFF',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.blueAccent,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          maxLength: 6,
                          onChanged: (text) {
                            final color = _hexToColor(text);
                            if (color != null) {
                              setSheetState(() {
                                previewColor = color;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _updateConfig(
                          (c) => c.copyWith(textColor: previewColor),
                        );
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Color',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _colorToHex(Color c) {
    return '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}';
  }

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '').trim();
    if (hex.length == 6) {
      final intVal = int.tryParse(hex, radix: 16);
      if (intVal != null) {
        return Color(0xFF000000 | intVal);
      }
    }
    return null;
  }

  // ─── Export ───

  Future<void> _export() async {
    if (widget.task.videoFilePath == null) return;
    if (_config.dial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a gauge before exporting.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final time = DateTime.now();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${directory.path}/TurboGauge_Export_$timestamp.mp4';
      final processId = timestamp.toString();

      // Build the FFmpeg command using GaugeExportService
      final command = await GaugeExportService.buildCommand(
        config: _config,
        inputVideoPath: widget.task.videoFilePath!,
        positionData: widget.task.positionData ?? {},
        outputPath: outputPath,
      );
      final commandBuildTime = DateTime.now().difference(time).inMilliseconds;
      AnalyticsService().trackEvent(
        AnalyticsEvents.ffmpegProcessingStarted,
        properties: {
          "process_id": processId,
          "ffmpeg_command": command,
          "config": _config.toString(),
          "input_video_length": widget.task.lengthInSeconds,
          "input_video_size": widget.task.sizeInKb,
          "position_data_length": widget.task.positionData?.length,
          "dial_id": _config.dial?.id,
          "needle_id": _config.needle?.id,
          "command_build_time": commandBuildTime
        }
      );
      AnalyticsService().flush();

      debugPrint('[Labs Export] Running FFmpeg command...');
      debugPrint('[Labs Export] Command: $command', wrapWidth: 1024);

      final session = await FFmpegKit.execute(command);
      final rc = await session.getReturnCode();

      if (ReturnCode.isSuccess(rc)) {
        debugPrint('[Labs Export] Success: $outputPath');
        final processRunTime = DateTime.now().difference(time).inMilliseconds;
        AnalyticsService().trackEvent(
            AnalyticsEvents.ffmpegCommandResult,
            properties: {
              "process_id": processId,
              "ffmpeg_command": command,
              "config": _config.toString(),
              "input_video_length": widget.task.lengthInSeconds,
              "input_video_size": widget.task.sizeInKb,
              "position_data_length": widget.task.positionData?.length,
              "dial_id": _config.dial?.id,
              "needle_id": _config.needle?.id,
              "command_build_time": commandBuildTime,
              "process_run_time": processRunTime,
              "return_code": rc?.getValue(),
              AnalyticsParams.success: true,
              "get_duration": await session.getDuration(),
            }
        );

        // Get file stats
        final file = File(outputPath);
        final stat = await file.stat();
        final sizeInKb = stat.size / 1024.0;

        String? gallerySaveError, rawExportError;
        // Save to gallery
        try {
          final galService = GetIt.I<GalService>();
          await galService.saveVideoToGallery(outputPath, albumName: 'TurboGauge Exports');
          debugPrint('[Labs Export] Saved to gallery');
        } catch (e) {
          gallerySaveError = e.toString();
          debugPrint('[Labs Export] Gallery save error: $e');
        }

        // Also export raw video if requested
        if (_exportRawVideo && widget.task.videoFilePath != null) {
          try {
            final galService = GetIt.I<GalService>();
            await galService.saveVideoToGallery(
              widget.task.videoFilePath!,
              albumName: 'TurboGauge Exports',
            );
            debugPrint('[Labs Export] Raw video saved to gallery');
          } catch (e) {
            rawExportError = e.toString();
            debugPrint('[Labs Export] Raw video gallery save error: $e');
          }
        }

        // Create ProcessedTask entry
        final processedId = LabsService().generateId();
        final processedTask = ProcessedTask(
          id: processedId,
          name: 'Export_$processedId',
          savedVideoFilePath: outputPath,
          processingTask: widget.task,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          sizeInKb: sizeInKb,
          lengthInSeconds: widget.task.lengthInSeconds,
        );
        await LabsService().saveProcessedTask(processedTask);

        if (mounted) {
          setState(() => _isExporting = false);
          _showSuccessDialog(outputPath, sizeInKb);
        }

        getIt<BadgeManager>().exportVideo();

        AnalyticsService().trackEvent(
            AnalyticsEvents.ffmpegProcessingFinished,
            properties: {
              "process_id": processId,
              "ffmpeg_command": command,
              "config": _config.toString(),
              "input_video_length": widget.task.lengthInSeconds,
              "input_video_size": widget.task.sizeInKb,
              // "output_video_length": widget.task.lengthInSeconds,
              "output_video_size": sizeInKb,
              "position_data_length": widget.task.positionData?.length,
              "dial_id": _config.dial?.id,
              "needle_id": _config.needle?.id,
              "command_build_time": commandBuildTime,
              "process_run_time": processRunTime,
              "return_code": rc?.getValue(),
              AnalyticsParams.success: true,
              "gallery_save_error": gallerySaveError,
              "raw_export_error": rawExportError,
              "get_duration": await session.getDuration(),
            }
        );
      } else {
        final logs = await session.getLogsAsString();
        AnalyticsService().trackEvent(
            AnalyticsEvents.ffmpegCommandResult,
            properties: {
              "process_id": processId,
              "ffmpeg_command": command,
              "config": _config.toString(),
              "input_video_length": widget.task.lengthInSeconds,
              "input_video_size": widget.task.sizeInKb,
              "position_data_length": widget.task.positionData?.length,
              "dial_id": _config.dial?.id,
              "needle_id": _config.needle?.id,
              "command_build_time": commandBuildTime,
              "return_code": rc?.getValue(),
              AnalyticsParams.success: false,
              "logs": logs,
              "is_crash": false,
              "get_duration": await session.getDuration(),
            }
        );
        debugPrint('[Labs Export] FFmpeg failed. RC: $rc');
        debugPrint('[Labs Export] Logs: $logs', wrapWidth: 1024);
        if (mounted) {
          setState(() => _isExporting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export failed. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[Labs Export] Exception: $e');
      debugPrint('[Labs Export] Stack: $stackTrace');
      AnalyticsService().trackEvent(
          AnalyticsEvents.ffmpegProcessingFailed,
          properties: {
            "config": _config.toString(),
            "input_video_length": widget.task.lengthInSeconds,
            "input_video_size": widget.task.sizeInKb,
            "position_data_length": widget.task.positionData?.length,
            "dial_id": _config.dial?.id,
            "needle_id": _config.needle?.id,
            AnalyticsParams.success: false,
            "is_crash": false,
            "error": e.toString(),
            "stack_trace": stackTrace.toString()
          }
      );
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(String outputPath, double sizeKb) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Colors.greenAccent, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Export Complete!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your video has been exported and saved to your gallery.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.movie_creation,
                      color: Colors.greenAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${(sizeKb / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to labs
            },
            child: const Text(
              'Done',
              style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final imperial = _config.isMetric ?? false;
    final placement = _config.labsPlacement;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.task.name ?? 'Process Video',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isExporting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Exporting your video...',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Video Preview ───
                _buildSectionHeader('Video Preview'),
                const SizedBox(height: 8),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[900],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _thumbnailPath != null
                      ? Image.file(File(_thumbnailPath!), fit: BoxFit.cover)
                      : const Center(
                    child: Icon(Icons.video_file,
                        size: 48, color: Colors.grey),
                  ),
                ),


                const SizedBox(height: 16),
                Text('Use these options to customize and export your video.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 16),

                // ─── Measurement System ───
                _buildSectionHeader('Measurement System'),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.straighten,
                  title: imperial ? 'Imperial (mph)' : 'Metric (km/h)',
                  subtitle: 'Tap to switch',
                  trailing: Switch(
                    value: !imperial,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) =>
                        _updateConfig((c) => c.copyWith(isMetric: !val)),
                  ),
                  onTap: () =>
                      _updateConfig((c) => c.copyWith(isMetric: !imperial)),
                ),

                const SizedBox(height: 20),

                // ─── Gauge Style ───
                _buildSectionHeader('Gauge Style'),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.speed,
                  title: _selectedOption.id ?? 'Select Gauge',
                  subtitle: _selectedNeedle != null
                      ? 'Needle: ${_selectedNeedle!.color ?? _selectedNeedle!.id ?? "default"}'
                      : 'No needle',
                  trailing:
                  _selectedOption.dial?.assetType == AssetType.network
                      ? Stack(
                        children: [
                                _buildCachedThumbnail(
                                  _selectedOption.dial?.path ?? "",
                                  30,
                                  30,
                                ),
                          Transform.rotate(
                            angle: -pi/4,
                                  child: _buildCachedThumbnail(
                                    _selectedNeedle?.path ?? "",
                                    30,
                                    30,
                                  )
                          ),
                        ],
                      )
                      : const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
                  onTap: _showGaugeAndNeedleSheet,
                ),

                const SizedBox(height: 20),

                // ─── Gauge Placement ───
                _buildSectionHeader('Gauge Placement'),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: placement.icon,
                  title: placement.displayName,
                  subtitle: 'Tap to change position',
                  trailing: const Icon(Icons.grid_3x3, color: Colors.white54),
                  onTap: _showPlacementSheet,
                ),

                const SizedBox(height: 20),

                  // ─── Gauge Size ───
                  _buildSectionHeader('Gauge Size'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.photo_size_select_large,
                                color: Colors.blueAccent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Size Factor',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${((_config.sizeFactor ?? 0.25) * 100).toStringAsFixed(0)}% of video',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              (_config.sizeFactor ?? 0.25).toStringAsFixed(2),
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: (_config.sizeFactor ?? 0.25).toDouble(),
                          min: 0.10,
                          max: 0.50,
                          divisions: 8,
                          activeColor: Colors.blueAccent,
                          label:
                              '${((_config.sizeFactor ?? 0.25) * 100).toStringAsFixed(0)}%',
                          onChanged:
                              (val) => _updateConfig(
                                (c) => c.copyWith(sizeFactor: val),
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Text Color ───
                  _buildSectionHeader('Text Color'),
                  const SizedBox(height: 8),
                  _buildOptionTile(
                    icon: Icons.format_color_text,
                    title: 'Text Color',
                    subtitle:
                        '#${(_config.textColor ?? Colors.white).value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    trailing: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _config.textColor ?? Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1.5),
                      ),
                    ),
                    onTap: () => _showTextColorSheet(),
                  ),

                  const SizedBox(height: 20),

                // ─── TurboGauge Branding ───
                _buildSectionHeader('Watermark'),
                const SizedBox(height: 8),
                PremiumFeatureGate(
                  premiumContent: _buildOptionTile(
                      icon: Icons.branding_watermark,
                      title: 'Show Watermark',
                      subtitle: (_config.showBranding ?? true)
                          ? 'TurboGauge Watermark will be shown'
                          : 'No watermark',
                      trailing: Switch(
                          value: _config.showBranding ?? true,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) {
                          PremiumUpgradeDialog.show(
                            context,
                            source: 'task_processing',
                          );
                            _updateConfig((c) => c.copyWith(showBranding: val));
                          }

                      ),
                      onTap: () {
                        _updateConfig((c) =>
                            c.copyWith(showBranding: !(_config.showBranding ?? true)));
                      }
                  ),
                  freeContent: _buildOptionTile(
                      icon: Icons.branding_watermark,
                      title: 'TurboGauge Watermark',
                      subtitle: (_config.showBranding ?? true)
                          ? 'Watermark will be shown'
                          : 'No watermark',
                      trailing: Switch(
                          value: _config.showBranding ?? true,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) {
                          PremiumUpgradeDialog.show(
                            context,
                            source: 'task_processing',
                          );
                            // _updateConfig((c) => c.copyWith(showBranding: val));
                          }

                      ),
                      onTap: () {
                        PremiumUpgradeDialog.show(
                          context,
                          source: 'task_processing',
                        );
                        // _updateConfig((c) =>
                        //     c.copyWith(showBranding: !(_config.showBranding ?? true)));
                      }
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Export Raw Video ───
                _buildOptionTile(
                  icon: Icons.file_copy_outlined,
                  title: 'Export Raw Video',
                  subtitle: 'Save original video without overlay to gallery',
                  trailing: Checkbox(
                    value: _exportRawVideo,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) =>
                        setState(() => _exportRawVideo = val ?? false),
                  ),
                  onTap: () =>
                      setState(() => _exportRawVideo = !_exportRawVideo),
                ),

                const SizedBox(height: 32),

                // ─── Export Button ───
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _export,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Export',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.blueAccent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a cached thumbnail from a remote URL.
  Widget _buildCachedThumbnail(String url, double width, double height) {
    return FutureBuilder<Uint8List?>(
      future: RemoteAssetService().getBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            height: height,
            width: width,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
        }
        return SizedBox(width: width, height: height);
      },
    );
  }
}

// ─── Gauge Tile Widget ───

class _GaugeTile extends StatelessWidget {
  final GaugeCustomizationOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _GaugeTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dialPath = option.dial?.path;
    final isNetwork = option.dial?.assetType == AssetType.network;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.grey[850],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dialPath != null && isNetwork)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _CachedNetworkImage(
                  url: dialPath,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: const Icon(
                    Icons.speed,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              )
            else
              const Icon(Icons.speed, color: Colors.white54, size: 40),
            const SizedBox(height: 6),
            Text(
              option.name ?? '',
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child:
                    Icon(Icons.check_circle, color: Colors.blueAccent, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Needle Tile Widget ───

class _NeedleTile extends StatelessWidget {
  final Needle needle;
  final bool isSelected;
  final VoidCallback onTap;

  const _NeedleTile({
    required this.needle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNetwork = needle.assetType == AssetType.network;
    final path = needle.path;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.grey[850],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (path != null && isNetwork)
              _CachedNetworkImage(
                url: path,
                width: 35,
                height: 35,
                fit: BoxFit.contain,
                errorWidget: const Icon(
                    Icons.navigation, color: Colors.white54, size: 30),
              )
            else
              Icon(Icons.navigation,
                  color: isSelected ? Colors.blueAccent : Colors.white54,
                  size: 30),
            const SizedBox(height: 4),
            Text(
              needle.name ?? needle.color ?? needle.id ?? '',
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white70,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cached Network Image ───

/// A reusable widget that loads images through RemoteAssetService cache.
class _CachedNetworkImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? errorWidget;

  const _CachedNetworkImage({
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: RemoteAssetService().getBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
            );
          }
          // Error or null data
          return errorWidget ?? SizedBox(width: width, height: height);
        }
        // Loading
        return SizedBox(width: width, height: height);
      },
    );
  }
}
