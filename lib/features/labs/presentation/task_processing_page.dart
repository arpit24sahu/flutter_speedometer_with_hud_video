import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_video/session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/labs/presentation/bloc/labs_service_bloc.dart';
import 'package:speedometer/features/labs/presentation/widgets/export_progress_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/badges/badge_manager.dart';
import 'package:speedometer/features/labs/models/processing_task.dart';
import 'package:speedometer/features/labs/models/processed_task.dart';
import 'package:speedometer/features/labs/models/gauge_customization.dart';
import 'package:speedometer/features/labs/presentation/bloc/gauge_customization_bloc.dart';
import 'package:speedometer/features/labs/presentation/speedometer_overlay_3.dart';
import 'package:speedometer/features/labs/services/gauge_export_service_2.dart';
import 'package:speedometer/features/labs/services/labs_service.dart';
import 'package:speedometer/features/premium/widgets/premium_feature_gate.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';
import 'package:speedometer/packages/gal.dart';
import 'package:speedometer/presentation/widgets/color_picker_bottom_sheet.dart';
import 'package:speedometer/presentation/widgets/gauge_needle_selector_widget.dart';
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

  bool _exportRawVideo = false;
  bool _isExporting = false;
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  GaugeCustomization get _config =>
      context.read<GaugeCustomizationBloc>().state.customization;

  void _updateConfig(GaugeCustomization Function(GaugeCustomization) updater) {
    final newConfig = updater(_config);
    context.read<GaugeCustomizationBloc>().add(
      ChangeGaugeCustomization(newConfig),
    );
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

  // ─── Placement Bottom Sheet ───

  void _showPlacementSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
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
                  itemBuilder: (ctx, index) {
                    final placement = GaugePlacement.values[index];
                    final isSelected = placement == _config.labsPlacement;
                    return GestureDetector(
                      onTap: () {
                        _updateConfig((c) => c.copyWith(placement: placement));
                        Navigator.pop(sheetContext);
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
    showColorPickerBottomSheet(
      context: context,
      currentColor: _config.textColor ?? Colors.white,
      title: 'Select Text Color',
      onColorSelected: (color) {
        _updateConfig((c) => c.copyWith(textColor: color));
      },
    );
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
    if (_isExporting) return; // guard re-entry

    setState(() => _isExporting = true);

    // ── Progress stream ──
    final progressController = StreamController<double>.broadcast();

    // ── Probe total duration for progress calculation ──
    int? totalDurationMs;
    try {
      final probeSession = await FFprobeKit.getMediaInformation(
        widget.task.videoFilePath!,
      );
      final info = probeSession.getMediaInformation();
      final durationStr = info?.getDuration();
      if (durationStr != null) {
        totalDurationMs = (double.parse(durationStr) * 1000).toInt();
      }
    } catch (_) {}

    // ── Show the progress dialog ──
    if (mounted) {
      ExportProgressDialog.show(
        context,
        progressStream: progressController.stream,
        thumbnailPath: _thumbnailPath,
        gaugeCustomization: _config,
      );
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final time = DateTime.now();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${directory.path}/TurboGauge_Export_$timestamp.mp4';
      final processId = timestamp.toString();

      // Build the FFmpeg command using GaugeExportService
      final GaugeExportResult command = await GaugeExportService2.buildCommand(
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
      debugPrint('[Labs Export] Command: ${command.command}', wrapWidth: 1024);

      // ── Use executeAsync with a statistics callback for progress ──
      final completer = Completer<void>();

      await FFmpegKit.executeAsync(
        command.command,
        // ── Completion callback ──
        (Session session) async {
          final rc = await session.getReturnCode();

          if (ReturnCode.isSuccess(rc)) {
            debugPrint('[Labs Export] Success: $outputPath');
            progressController.add(1.0); // ensure we show 100%
        final processRunTime = DateTime.now().difference(time).inMilliseconds;
            AnalyticsService().trackEvent(
              AnalyticsEvents.ffmpegCommandResult,
              properties: {
                "process_id": processId,
                "ffmpeg_command": command.command,
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
              },
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

            getIt<BadgeManager>().exportVideo();

            AnalyticsService().trackEvent(
              AnalyticsEvents.ffmpegProcessingFinished,
              properties: {
                "process_id": processId,
                "ffmpeg_command": command.command,
                "config": _config.toString(),
                "input_video_length": widget.task.lengthInSeconds,
                "input_video_size": widget.task.sizeInKb,
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
              },
            );

            // Dismiss progress dialog & show success
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // close dialog
              await Future.delayed(const Duration(milliseconds: 200));
              setState(() => _isExporting = false);
              _showSuccessDialog(outputPath, sizeInKb);
            }
          } else {
            final logs = await session.getLogsAsString();
            AnalyticsService().trackEvent(
              AnalyticsEvents.ffmpegCommandResult,
              properties: {
                "process_id": processId,
                "ffmpeg_command": command.command,
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
              },
            );
            debugPrint('[Labs Export] FFmpeg failed. RC: $rc');
            debugPrint('[Labs Export] Logs: $logs', wrapWidth: 1024);
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop();
              setState(() => _isExporting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export failed. Please try again.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }

          if(mounted) context.read<LabsServiceBloc>().add(LoadTasks());

          await progressController.close();
          if (!completer.isCompleted) completer.complete();
        },
        // ── Log callback (optional debug) ──
        null,
        // ── Statistics callback — drives the progress bar ──
        (statistics) {
          if (totalDurationMs != null && totalDurationMs > 0) {
            final processedMs = statistics.getTime();
            final progress = (processedMs / totalDurationMs).clamp(0.0, 1.0);
            if (!progressController.isClosed) {
              progressController.add(progress);
            }
          }
        },
      );

      // Wait for the async execution to finish
      await completer.future;
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
      if (!progressController.isClosed) {
        await progressController.close();
      }
      if (mounted) {
        // Pop progress dialog if it's still showing
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
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
    return BlocBuilder<GaugeCustomizationBloc, GaugeCustomizationState>(
      builder: (context, gaugeState) {
        final config = gaugeState.customization;
        final imperial = config.isMetric ?? false;
        final placement = config.labsPlacement;

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
      body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
              // ─── Video Preview (vertical with speedometer overlay) ───
                _buildSectionHeader('Video Preview'),
                const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final previewWidth = MediaQuery.of(context).size.width / 2;
                  final previewHeight = previewWidth * (16 / 9);
                  final gaugeSize = previewWidth * (config.sizeFactor ?? 0.25);

                  return Center(
                    child: Container(
                      width: previewWidth,
                      height: previewHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[900],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail
                          if (_thumbnailPath != null)
                            Image.file(File(_thumbnailPath!), fit: BoxFit.cover)
                          else
                            const Center(
                              child: Icon(
                                Icons.video_file,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          // Speedometer overlay
                          placement.buildPositioned(
                            gaugeSize: gaugeSize,
                            screenSize: Size(previewWidth, previewHeight),
                            margin: 8,
                            child: SpeedometerOverlay3(
                              speed: 60,
                              maxSpeed: 240,
                              size: gaugeSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
              const GaugeNeedleSelectorWidget(),

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
                                '${((config.sizeFactor ?? 0.25) * 100).toStringAsFixed(0)}% of video',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                          (config.sizeFactor ?? 0.25).toStringAsFixed(2),
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                      value: (config.sizeFactor ?? 0.25).toDouble(),
                          min: 0.10,
                          max: 0.50,
                          divisions: 8,
                          activeColor: Colors.blueAccent,
                      label:
                          '${((config.sizeFactor ?? 0.25) * 100).toStringAsFixed(0)}%',
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
                    '#${(config.textColor ?? Colors.white).value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    trailing: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                    color: config.textColor ?? Colors.white,
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
                  subtitle: (config.showBranding ?? true)
                          ? 'TurboGauge Watermark will be shown'
                          : 'No watermark',
                      trailing: Switch(
                    value: config.showBranding ?? true,
                          activeColor: Colors.blueAccent,
                    onChanged: (val) {
                            _updateConfig((c) => c.copyWith(showBranding: val));
                          }

                      ),
                      onTap: () {
                    _updateConfig(
                      (c) => c.copyWith(
                        showBranding: !(config.showBranding ?? true),
                      ),
                    );
                      }
                  ),
                  freeContent: _buildOptionTile(
                      icon: Icons.branding_watermark,
                      title: 'TurboGauge Watermark 👑',
                  subtitle:
                      (config.showBranding ?? true)
                          ? 'Watermark will be shown'
                          : 'No watermark',
                      trailing: Switch(
                    value: config.showBranding ?? true,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) {
                          PremiumUpgradeDialog.show(
                            context,
                            source: 'task_processing',
                      );
                          }

                      ),
                      onTap: () {
                        PremiumUpgradeDialog.show(
                          context,
                          source: 'task_processing',
                    );
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
      },
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
}
