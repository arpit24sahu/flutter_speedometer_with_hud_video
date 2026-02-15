import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speedometer/core/services/camera_service.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/files/bloc/files_bloc.dart';
import 'package:speedometer/features/labs/presentation/bloc/gauge_customization_bloc.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_bloc.dart';
import 'package:speedometer/features/speedometer/bloc/speedometer_state.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../features/labs/models/gauge_customization.dart';
import '../../features/labs/presentation/speedometer_overlay_3.dart';
import '../../features/processing/bloc/jobs_bloc.dart';
import '../../features/processing/bloc/processor_bloc.dart';
import '../../features/speedometer/bloc/speedometer_event.dart';
import '../../packages/gal.dart';
import '../bloc/video_recorder_bloc.dart';
import '../widgets/video_recorder_service.dart';
import 'gauge_settings_screen.dart';
import 'gauge_settings_screen_2.dart';
import 'home_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver implements TabVisibilityAware  {


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Also logs App Backgrounded or Foregrounded Events
    AnalyticsService().trackAppLifeCycle(state);
    if (state == AppLifecycleState.resumed) {
      if(context.mounted) context.read<SpeedometerBloc>().add(StartSpeedTracking());
    } else if (state == AppLifecycleState.paused) {
      if(context.mounted) context.read<SpeedometerBloc>().add(StopSpeedTracking());
    }
  }



  CameraController? _cameraController;
  final CameraService _cameraService = getIt<CameraService>();
  final GlobalKey _speedometerKey = GlobalKey();

  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    if(context.mounted) context.read<SpeedometerBloc>().add(StartSpeedTracking());

    _initializeCamera(_currentCameraIndex);
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    final List<CameraDescription> cameras =
        await _cameraService.getAvailableCameras();
    if (cameras.isEmpty) {
      return;
    }

    _cameraController = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );
    _currentCameraIndex = cameraIndex;

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void onTabInvisible() {
    _cameraController?.pausePreview();
  }

  @override
  void onTabVisible() {
    _cameraController?.resumePreview();
  }

  @override
  void dispose() {
    _cameraController?.dispose();

    WidgetsBinding.instance.removeObserver(this);
    if(context.mounted) context.read<SpeedometerBloc>().add(StopSpeedTracking());

    super.dispose();
  }

  Future<void> _toggleRecording(BuildContext contextWithBloc) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not initialized'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    try {
      final currentState = contextWithBloc.read<VideoRecorderBloc>().state;

      if (currentState is VideoRecording || currentState is VideoProcessing) {
        final gaugeConfigState = context.read<OverlayGaugeConfigurationBloc>().state;
        contextWithBloc.read<VideoRecorderBloc>().add(StopRecording(
              gaugePlacement: gaugeConfigState.gaugePlacement,
              relativeSize: gaugeConfigState.gaugeRelativeSize,
        ));
      } else {
        contextWithBloc.read<VideoRecorderBloc>().add(StartRecording());
      }
    } catch (e) {
      debugPrint("Error toggling recording: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return BlocProvider<VideoRecorderBloc>(
      create: (context) => VideoRecorderBloc(
            recorderService: WidgetRecorderService(
              widgetKey: _speedometerKey,
              cameraController: _cameraController!,
            ),
            jobsBloc: GetIt.I<JobsBloc>(),
            processorBloc: GetIt.I<ProcessorBloc>(),
          ),
      child: BlocConsumer<VideoRecorderBloc, VideoRecorderState>(
        listener: _handleVideoRecorderState,
        builder: (context, videoRecorderState) {
          final String? statusText =
              videoRecorderState is VideoProcessing
                  ? 'Please wait. The Video is being processed in background'
                  : null;

          return SafeArea(
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Column(
                children: [
                  // ── Camera Preview + Overlay ──
                  Expanded(
                    flex: 4,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            // Camera preview
                            Positioned.fill(
                              child: AspectRatio(
                                aspectRatio: _cameraController!.value.aspectRatio,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),

                            // Speedometer gauge overlay
                            BlocBuilder<GaugeCustomizationBloc, GaugeCustomizationState>(
                              builder: (context, gaugeCustomizationState) {
                                final config = gaugeCustomizationState.customization;
                                final sizeFactor = config.sizeFactor ?? 1;
                                // sizeFactor=1 → 80px base. User can scale up (e.g. sizeFactor=3 → 120px).
                                final double gaugeWidth = 80.0 * sizeFactor;
                                final placement = config.placement ?? GaugePlacement.topRight;
                                // Use the Stack's constraints (camera viewport), not MediaQuery
                                final viewportSize = Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );

                                return BlocBuilder<SpeedometerBloc, SpeedometerState>(
                                  builder: (context, speedometerState) {
                                    double currentSpeed = config.isMetric == true
                                      ? speedometerState.speedKmh
                                      : speedometerState.speedMph;

                                    return placement.buildPositioned(
                                      gaugeSize: gaugeWidth,
                                      screenSize: viewportSize,
                                      margin: 20,
                                      child: SpeedometerOverlay3(
                                        speed: currentSpeed,
                                        maxSpeed: 240,
                                        size: gaugeWidth,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // ── Processing Status Banner ──
                  if (statusText?.isNotEmpty ?? false)
                    Container(
                      width: double.infinity,
                      color: Colors.yellow,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        statusText!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // ── Control Bar ──
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Flip camera (hidden while recording/processing)
                          _buildFlipCameraButton(videoRecorderState),

                          // Record / Stop button
                          _buildRecordButton(context, videoRecorderState),

                          // Settings button
                          _buildSettingsButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Extracted UI builders
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildFlipCameraButton(VideoRecorderState state) {
    final bool isActive =
        !(state is VideoProcessing || state is VideoRecording);

    if (!isActive) {
      return const SizedBox(width: 48, height: 48);
    }

    return IconButton(
      icon: const Icon(Icons.flip_camera_android),
      color: Colors.white,
      iconSize: 32,
      onPressed: () {
        HapticFeedback.mediumImpact();
        AnalyticsService().trackEvent(
          AnalyticsEvents.flipCamera,
          properties: {
            "previousOrientation":
                _currentCameraIndex % 2 == 0 ? "FRONT" : "BACK",
            "newOrientation": _currentCameraIndex % 2 == 0 ? "BACK" : "FRONT",
            "previousOrientationIndex": _currentCameraIndex,
            "newOrientationIndex": (_currentCameraIndex + 1) % 2,
          },
        );
        _initializeCamera((_currentCameraIndex + 1) % 2);
      },
    );
  }

  Widget _buildRecordButton(
    BuildContext contextWithBloc,
    VideoRecorderState state,
  ) {
    final bool isRecording = state is VideoRecording;
    final bool isProcessing = state is VideoProcessing;

    return FloatingActionButton(
      backgroundColor: isRecording ? Colors.red : Colors.white,
      onPressed: () {
        if (state is VideoProcessing) {
          AnalyticsService().trackEvent(
            AnalyticsEvents.recordButtonPressedWhileProcessing,
            properties: {"progress": state.progress},
          );
        } else {
          HapticFeedback.mediumImpact();
          AnalyticsService().trackEvent(
            isRecording
                ? AnalyticsEvents.recordingStopped
                : AnalyticsEvents.recordingStarted,
            properties: {
              "cameraOrientation":
                  _currentCameraIndex % 2 == 0 ? "BACK" : "FRONT",
              "cameraOrientationIndex": _currentCameraIndex,
              "gaugeState":
                  contextWithBloc
                      .read<OverlayGaugeConfigurationBloc>()
                      .state
                      .toJson(),
            },
          );
          _toggleRecording(contextWithBloc);
        }
      },
      child:
          isProcessing
              ? const CupertinoActivityIndicator(color: Colors.red)
              : Icon(
                isRecording ? Icons.stop : Icons.videocam,
                color: isRecording ? Colors.white : Colors.black,
              ),
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      icon: const Icon(Icons.settings),
      color: Colors.white,
      iconSize: 32,
      onPressed: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customize',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  Text(
                    'Good News! You will be able to customize these after you have recorded your video. Go to Labs Page for more options.',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(child: GaugeSettingsScreen2()),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Bloc listener handler
  // ─────────────────────────────────────────────────────────────────────

  void _handleVideoRecorderState(
    BuildContext context,
    VideoRecorderState videoRecorderState,
  ) {
    if (videoRecorderState is VideoProcessed) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 1500));
        try {
          final galService = getIt<GalService>();
          await galService.saveVideoToGallery(
            videoRecorderState.finalVideoPath,
            albumName: 'Speedometer Videos',
          );
        } catch (e) {
          debugPrint('Error saving video to gallery: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving video to gallery: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        try {
          Future.delayed(const Duration(seconds: 1), () {
            if (context.mounted) {
              context.read<FilesBloc>().add(RefreshFiles());
            }
          });
          if (context.mounted) {
            showVideoSuccessDialog(context, videoRecorderState.finalVideoPath);
          }
        } catch (e) {
          debugPrint('Error showing video success dialog: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please check your File in the Files Tab.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    } else if (videoRecorderState is VideoProcessingError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showVideoErrorDialog(context, videoRecorderState.message);
      });
    } else if (videoRecorderState is VideoJobSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Recording saved! ${videoRecorderState.positionDataPoints} GPS points captured. Go to Jobs tab to build video with speedometer overlay.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Jobs',
                textColor: Colors.white,
                onPressed: () {
                  AppTabState.updateCurrentTab(3);
                },
              ),
            ),
          );
          context.read<VideoRecorderBloc>().add(ResetRecorder());
        }
      });
    }
  }
}


// ═══════════════════════════════════════════════════════════════════════
// Dialogs
// ═══════════════════════════════════════════════════════════════════════

/// Shows a success dialog after video processing is complete
void showVideoSuccessDialog(BuildContext context, String finalVideoPath) {
  final videoFile = File(finalVideoPath);

  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade800,
              Colors.indigo.shade900,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recording Complete',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your video is ready to view and share!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your video has been saved:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.videocam,
                          color: Colors.greenAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Video with Speedometer',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                path.basename(finalVideoPath),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              FutureBuilder<int>(
                                future: videoFile.length(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data! > 0) {
                                    final size = snapshot.data! / (1024 * 1024);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '${size.toStringAsFixed(2)} MB',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Share prompt
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          color: Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Share your video with friends and family to show off your speed data!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Play Video'),
                          onPressed: () async {
                            AnalyticsService().trackEvent(AnalyticsEvents.playRecordedVideo,
                                properties: {
                                  "finalVideoPath": finalVideoPath,
                                  "videoSize": await videoFile.length()
                                }
                            );
                            final result = await OpenFile.open(finalVideoPath);
                            debugPrint('OpenFile result: ${result.type}, ${result.message}');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'Share Video',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            AnalyticsService().trackEvent(AnalyticsEvents.shareRecordedVideo,
                              properties: {
                                "finalVideoPath": finalVideoPath,
                                "videoSize": await videoFile.length()
                              }
                            );
                            Get.back();
                            try {
                              await Share.shareXFiles(
                                [XFile(finalVideoPath)],
                                  text: 'Check out my driving data captured with Speedometer app!'
                              );
                            } catch (e) {
                              debugPrint('Error sharing: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error sharing video: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Close button at the bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.7),
                ),
                onPressed: () => Get.back(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

/// Shows an error dialog when video processing fails
void showVideoErrorDialog(BuildContext context, String errorMessage) {
  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade800,
              Colors.deepPurple.shade900,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Processing Error',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'There was a problem processing your video',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error details:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Helpful tips
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: Colors.blue,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Troubleshooting Tips',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Make sure you have enough storage space\n'
                          '• Try recording a shorter video\n'
                          '• Restart the app and try again',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Try Again',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Get.back();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Close button at the bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.7),
                ),
                onPressed: () => Get.back(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}
