import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speedometer/core/services/camera_service.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_state.dart';
import 'package:speedometer/presentation/widgets/premium_badge.dart';
import '../../core/services/screen_record_service.dart';
import '../../core/services/screen_recorder.dart';
import '../../packages/gal.dart';
import '../bloc/video_recorder_bloc.dart';
import '../widgets/digital_speedometer_overlay2.dart';
import '../widgets/video_recorder_service.dart';
import 'gauge_settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  // bool _isProcessing = false;
  // String? _lastVideoPath;
  final CameraService _cameraService = getIt<CameraService>();
  late final ScreenRecordService _screenRecordService;
  final ScreenRecorderController _screenRecorderController = ScreenRecorderController(
    pixelRatio: 1
  );
  final GlobalKey _speedometerKey = GlobalKey();

  bool _isPermissionGranted = false;
  bool _checkingPermissions = true;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _screenRecordService = ScreenRecordServiceImpl();
    _screenRecordService.initialize();
    _checkPermissionsAndInit();
  }

  Future<void> _checkPermissionsAndInit() async {
    setState(() {
      _checkingPermissions = true;
    });

    final granted = await _permissionCheck();

    setState(() {
      _isPermissionGranted = granted;
      _checkingPermissions = false;
    });

    if (granted) {
      _initializeCamera(_currentCameraIndex);
    }
  }

  Future<bool> _permissionCheck() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.camera,
          Permission.microphone,
          Permission.location,
        ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    return allGranted;
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    final List<CameraDescription> cameras = await _cameraService.getAvailableCameras();
    int index = 0;
    print("Camera Desc");
    for(var x in cameras){
      print("Camera ${index++}: ${x.name} ${x.lensDirection} ${x.sensorOrientation}");
    }
    if (cameras.isEmpty) {
      return;
    }

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );
    _currentCameraIndex = cameraIndex;

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _screenRecordService.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording(BuildContext contextWithBloc) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not initialized'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Safety check for mounted state
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
  //
  // Future<void> _showRecordingResults(String finalVideoPath) async {
  //   final videoFile = File(finalVideoPath);
  //
  //   Get.dialog(
  //     Dialog(
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(16),
  //       ),
  //       elevation: 8,
  //       backgroundColor: Colors.transparent,
  //       child: Container(
  //         decoration: BoxDecoration(
  //           gradient: LinearGradient(
  //             begin: Alignment.topLeft,
  //             end: Alignment.bottomRight,
  //             colors: [
  //               Colors.blue.shade800,
  //               Colors.indigo.shade900,
  //             ],
  //           ),
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.3),
  //               blurRadius: 16,
  //               spreadRadius: 2,
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Container(
  //               padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
  //               decoration: BoxDecoration(
  //                 color: Colors.black.withOpacity(0.2),
  //                 borderRadius: BorderRadius.only(
  //                   topLeft: Radius.circular(16),
  //                   topRight: Radius.circular(16),
  //                 ),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Icon(
  //                     Icons.check_circle,
  //                     color: Colors.greenAccent,
  //                     size: 36,
  //                   ),
  //                   SizedBox(width: 16),
  //                   Expanded(
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Text(
  //                           'Recording Complete',
  //                           style: TextStyle(
  //                             fontSize: 22,
  //                             fontWeight: FontWeight.bold,
  //                             color: Colors.white,
  //                           ),
  //                         ),
  //                         SizedBox(height: 4),
  //                         Text(
  //                           'Your video is ready to view and share!',
  //                           style: TextStyle(
  //                             fontSize: 14,
  //                             color: Colors.white.withOpacity(0.8),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //
  //             Container(
  //               width: double.infinity,
  //               padding: EdgeInsets.all(20),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     'Your video has been saved:',
  //                     style: TextStyle(
  //                       fontSize: 16,
  //                       color: Colors.white.withOpacity(0.9),
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                   SizedBox(height: 12),
  //                   Container(
  //                     padding: EdgeInsets.all(12),
  //                     decoration: BoxDecoration(
  //                       color: Colors.white.withOpacity(0.1),
  //                       borderRadius: BorderRadius.circular(8),
  //                       border: Border.all(
  //                         color: Colors.white.withOpacity(0.2),
  //                         width: 1,
  //                       ),
  //                     ),
  //                     child: Row(
  //                       children: [
  //                         Icon(
  //                           Icons.videocam,
  //                           color: Colors.greenAccent,
  //                           size: 28,
  //                         ),
  //                         SizedBox(width: 12),
  //                         Expanded(
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Text(
  //                                 'Video with Speedometer',
  //                                 style: TextStyle(
  //                                   fontSize: 16,
  //                                   color: Colors.white,
  //                                   fontWeight: FontWeight.bold,
  //                                 ),
  //                               ),
  //                               SizedBox(height: 4),
  //                               Text(
  //                                 path.basename(finalVideoPath),
  //                                 style: TextStyle(
  //                                   fontSize: 13,
  //                                   color: Colors.white.withOpacity(0.7),
  //                                 ),
  //                                 overflow: TextOverflow.ellipsis,
  //                                 maxLines: 1,
  //                               ),
  //                               FutureBuilder<int>(
  //                                 future: videoFile.exists() ? videoFile.length() : Future.value(0),
  //                                 builder: (context, snapshot) {
  //                                   if (snapshot.hasData && snapshot.data! > 0) {
  //                                     final size = snapshot.data! / (1024 * 1024);
  //                                     return Padding(
  //                                       padding: const EdgeInsets.only(top: 4),
  //                                       child: Text(
  //                                         '${size.toStringAsFixed(2)} MB',
  //                                         style: TextStyle(
  //                                           fontSize: 12,
  //                                           color: Colors.greenAccent,
  //                                         ),
  //                                       ),
  //                                     );
  //                                   }
  //                                   return SizedBox.shrink();
  //                                 },
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //
  //                   // Share prompt
  //                   Container(
  //                     margin: EdgeInsets.symmetric(vertical: 16),
  //                     padding: EdgeInsets.all(16),
  //                     decoration: BoxDecoration(
  //                       color: Colors.amber.withOpacity(0.2),
  //                       borderRadius: BorderRadius.circular(8),
  //                       border: Border.all(
  //                         color: Colors.amber.withOpacity(0.4),
  //                         width: 1,
  //                       ),
  //                     ),
  //                     child: Row(
  //                       children: [
  //                         Icon(
  //                           Icons.lightbulb,
  //                           color: Colors.amber,
  //                           size: 24,
  //                         ),
  //                         SizedBox(width: 12),
  //                         Expanded(
  //                           child: Text(
  //                             'Share your video with friends and family to show off your speed data!',
  //                             style: TextStyle(
  //                               fontSize: 14,
  //                               color: Colors.white,
  //                               fontWeight: FontWeight.w500,
  //                             ),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //
  //                   // Action buttons
  //                   SizedBox(height: 10),
  //                   Row(
  //                     children: [
  //                       Expanded(
  //                         child: ElevatedButton.icon(
  //                           style: ElevatedButton.styleFrom(
  //                             backgroundColor: Colors.white.withOpacity(0.2),
  //                             foregroundColor: Colors.white,
  //                             padding: EdgeInsets.symmetric(vertical: 12),
  //                             shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(8),
  //                             ),
  //                           ),
  //                           icon: Icon(Icons.play_circle_outline),
  //                           label: Text('Play Video'),
  //                           onPressed: () async {
  //                             final result = await OpenFile.open(finalVideoPath);
  //                             print('OpenFile result: ${result.type}, ${result.message}');
  //                           },
  //                         ),
  //                       ),
  //                       SizedBox(width: 12),
  //                       Expanded(
  //                         child: ElevatedButton.icon(
  //                           style: ElevatedButton.styleFrom(
  //                             backgroundColor: Colors.greenAccent,
  //                             foregroundColor: Colors.black,
  //                             padding: EdgeInsets.symmetric(vertical: 12),
  //                             elevation: 2,
  //                             shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(8),
  //                             ),
  //                           ),
  //                           icon: Icon(Icons.share),
  //                           label: Text(
  //                             'Share Video',
  //                             style: TextStyle(fontWeight: FontWeight.bold),
  //                           ),
  //                           onPressed: () async {
  //                             Get.back(); // Close dialog
  //                             try {
  //                               await Share.shareXFiles(
  //                                   [XFile(finalVideoPath)],
  //                                   text: 'Check out my driving data captured with Speedometer app!'
  //                               );
  //                             } catch (e) {
  //                               print('Error sharing: $e');
  //                               ScaffoldMessenger.of(context).showSnackBar(
  //                                 SnackBar(
  //                                   content: Text('Error sharing video: $e'),
  //                                   backgroundColor: Colors.red,
  //                                 ),
  //                               );
  //                             }
  //                           },
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //
  //             // Close button at the bottom
  //             Padding(
  //               padding: EdgeInsets.only(bottom: 20, top: 10),
  //               child: TextButton(
  //                 style: TextButton.styleFrom(
  //                   foregroundColor: Colors.white.withOpacity(0.7),
  //                 ),
  //                 onPressed: () => Get.back(),
  //                 child: Text('Close'),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //     barrierDismissible: false,
  //   );
  // }
  //
  // Future<void> _toggleCameraRecording() async {
  //   if (_controller == null || !_controller!.value.isInitialized) {
  //     return;
  //   }
  //
  //   if (_isRecording) {
  //     try {
  //       final XFile file = await _controller!.stopVideoRecording();
  //
  //       final newPath = await _getVideoFilePath();
  //       final newFile = File(newPath);
  //       await newFile.writeAsBytes(await file.readAsBytes());
  //
  //       setState(() {
  //         _isRecording = false;
  //         _lastVideoPath = file.path; // Store the file path
  //       });
  //       print("------------ New Path: $newPath");
  //       _showFileActionsDialog(newPath);
  //
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('Video saved to ${newPath}'),
  //             duration: Duration(seconds: 10),
  //             action: SnackBarAction(
  //               label: 'Open',
  //               onPressed: () => _openVideo(XFile(newPath)),
  //             ),
  //           ),
  //         );
  //       }
  //     } catch (e) {
  //       debugPrint('Error stopping recording: $e');
  //     }
  //   } else {
  //     try {
  //       await _controller!.startVideoRecording();
  //       setState(() {
  //         _isRecording = true;
  //       });
  //     } catch (e) {
  //       debugPrint('Error starting recording: $e');
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('Could not start recording: $e'),
  //             backgroundColor: Colors.red,
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }
  //
  //
  // Future<void> _toggleScreenRecording() async {
  //   print('[Screen Recording] Toggle called. Recording state: $_isRecording');
  //
  //   if (_isRecording) {
  //     try {
  //       print('[Screen Recording] Attempting to stop recording...');
  //
  //       _screenRecorderController.stop();
  //       setState(() {
  //         _isRecording = false;
  //         _isProcessing = true;
  //       });
  //       print('[Screen Recording] Recording stopped successfully');
  //
  //       print('[Screen Recording] Exporting as GIF...');
  //       final List<int>? gif = await _screenRecorderController.exporter.exportGif();
  //
  //       if (gif != null) {
  //         print('[Screen Recording] GIF exported successfully. Size: ${gif.length} bytes');
  //
  //         // Save the GIF to file
  //         final newPath = await _getGifFilePath();
  //         print('[Screen Recording] Saving GIF to: $newPath');
  //
  //         final newFile = File(newPath);
  //         await newFile.writeAsBytes(gif);
  //         print('[Screen Recording] GIF saved successfully');
  //
  //         setState(() {
  //           _isProcessing = false;
  //           _lastVideoPath = newPath;
  //         });
  //
  //         print('[Screen Recording] Showing file actions dialog...');
  //         _showFileActionsDialog(newPath);
  //
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text('GIF saved to $newPath'),
  //               duration: const Duration(seconds: 10),
  //               action: SnackBarAction(
  //                 label: 'Open',
  //                 onPressed: () => _openFile(newPath),
  //               ),
  //             ),
  //           );
  //         }
  //       } else {
  //         print('[Screen Recording] ERROR: Failed to export GIF (null value returned)');
  //       }
  //     } catch (e) {
  //       print('[Screen Recording] ERROR during stop recording: $e');
  //       debugPrint('Error stopping recording: $e');
  //       setState(() {
  //         _isRecording = false;
  //         _isProcessing = false;
  //       });
  //     }
  //   } else {
  //     try {
  //       print('[Screen Recording] Attempting to start recording...');
  //
  //       _screenRecorderController.start();
  //       print('[Screen Recording] Recording started successfully');
  //
  //       setState(() {
  //         _isRecording = true;
  //       });
  //     } catch (e) {
  //       print('[Screen Recording] ERROR during start recording: $e');
  //       debugPrint('Error starting recording: $e');
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('Could not start recording: $e'),
  //             backgroundColor: Colors.red,
  //           ),
  //         );
  //       }
  //     }
  //   }
  //
  //   print('[Screen Recording] Toggle function completed');
  // }
  //

  @override
  Widget build(BuildContext context) {
    if (_checkingPermissions) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 20),
              Text(
                "Verifying Permissions...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isPermissionGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  size: 80,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Permissions Required",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "We need Camera, Microphone, and Location access to record your drive with a speedometer overlay.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checkPermissionsAndInit,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Check Again"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text(
                    "Open App Settings",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return BlocProvider<VideoRecorderBloc>(
      create: (context) => VideoRecorderBloc(
            recorderService: WidgetRecorderService(
              widgetKey: _speedometerKey,
              cameraController: _controller!,
        )
          ),
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return BlocConsumer<VideoRecorderBloc, VideoRecorderState>(
            listener: (context, videoRecorderState){
              if (videoRecorderState is VideoProcessed) {
                // Show success dialog from external function
                WidgetsBinding.instance.addPostFrameCallback((_)async{
                  final galService = getIt<GalService>();
                  await galService.saveVideoToGallery(
                    videoRecorderState.finalVideoPath,
                      albumName: 'Speedometer Videos'
                  );
                  showVideoSuccessDialog(context, videoRecorderState.finalVideoPath);
                });
              } else if (videoRecorderState is VideoProcessingError) {
                // Show error dialog from external function
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showVideoErrorDialog(context, videoRecorderState.message);
                });
              }
            },
            builder: (context, videoRecorderState) {
              print("Emitted State: ${videoRecorderState.runtimeType}");
              String? statusText; Color? statusColor;
              if(videoRecorderState is VideoProcessing){
                statusText = 'Please wait. The Video is being processed in background';
              } else {
                statusText = null;
              }
              // else if(videoRecorderState is VideoProcessed){
              //   statusText = 'Video processed successfully: ${videoRecorderState.finalVideoPath}';
              //   statusColor = Colors.green;
              //   Future.delayed(const Duration(seconds: 2), () {statusText = null;});
              // } else if(videoRecorderState is VideoProcessingError) {
              //   statusText = 'Error processing video: ${videoRecorderState.message}';
              // }
              return SafeArea(
                child: Scaffold(
                  backgroundColor: Colors.black,
                  body: Column(
                    children: [

                      Expanded(
                        flex: 4,
                        child: LayoutBuilder(
                          builder: (context, constraints){
                            return ScreenRecorder(
                              height: constraints.maxHeight,
                              width: constraints.maxWidth,
                              controller: _screenRecorderController,
                              child: Stack(
                                children: [
                                  // Camera preview
                                  Positioned.fill(
                                    child: AspectRatio(
                                      aspectRatio: _controller!.value.aspectRatio,
                                      child: CameraPreview(
                                        _controller!,
                                        // child: (_isProcessing)
                                        //     ? Center(
                                        //   child: Stack(
                                        //     children: [
                                        //       // Black stroke text
                                        //       Text(
                                        //         "Processing your Clip...",
                                        //         style: TextStyle(
                                        //           fontSize: 24,
                                        //           fontWeight: FontWeight.bold,
                                        //           foreground: Paint()
                                        //             ..style = PaintingStyle.stroke
                                        //             ..strokeWidth = 2
                                        //             ..color = Colors.black,
                                        //         ),
                                        //       ),
                                        //       // White fill text
                                        //       Text(
                                        //         "Processing your Clip...",
                                        //         style: TextStyle(
                                        //           fontSize: 24,
                                        //           fontWeight: FontWeight.bold,
                                        //           color: Colors.white,
                                        //         ),
                                        //       ),
                                        //     ],
                                        //   ),
                                        // )
                                        //     : null

                                      ),
                                    ),
                                  ),

                                  // Speedometer overlay
                                  BlocBuilder<OverlayGaugeConfigurationBloc, OverlayGaugeConfigurationState>(
                                    builder: (context, state) {
                                      final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

                                      final position = calculateGaugePosition(
                                        placement: state.gaugePlacement,
                                        gaugeSize: MediaQuery.of(context).size.width * state.gaugeRelativeSize,
                                        screenSize: screenSize,
                                      );
                                      print(position);
                                      // print(position.toString());

                                      return Positioned(
                                        top: position.top>0 ? position.top : null ,
                                        bottom: position.bottom>0 ? position.bottom : null,
                                        left: position.left>0 ? position.left : null,
                                        right: position.right>0 ? position.right : null,
                                        height: MediaQuery.of(context).size.width * state.gaugeRelativeSize + 24,
                                        width: MediaQuery.of(context).size.width * state.gaugeRelativeSize,
                                        // width: 120,
                                        child: Container(
                                          // color: Colors.orange,
                                          child: RepaintBoundary(
                                            key: _speedometerKey,
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: DigitalSpeedometerOverlay2(
                                                      isMetric: settingsState.isMetric,
                                                      size: MediaQuery.of(context).size.width * state.gaugeRelativeSize
                                                  ),
                                                ),
                                                if(state.showLabel) Text(
                                                    "TURBOGAUGE",
                                                    style: TextStyle(
                                                    fontFamily: 'RacingSansOne',
                                                    fontSize: MediaQuery.of(context).size.width * state.gaugeRelativeSize * 0.1,
                                                    fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.6,
                                                      color: state.textColor,
                                                    ),
                                                  ),
                                              ],
                                            )
                                          ),
                                        ),
                                      );
                                      // if(state.showLabel) Text(
                                      //   "TURBOGAUGE",
                                      //   style: TextStyle(
                                      //     fontSize: MediaQuery.of(context).size.width * state.gaugeRelativeSize*0.08,
                                      //     fontWeight: FontWeight.bold,
                                      //     color: state.textColor,
                                      //   ),
                                      // ),
                                    }
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if(statusText?.isNotEmpty??false) Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.yellow,
                              child: Text(statusText ?? '',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if(!(videoRecorderState is VideoProcessing || videoRecorderState is VideoRecording))
                                IconButton(
                                  icon: const Icon(Icons.flip_camera_android),
                                  color: Colors.white,
                                  iconSize: 32,
                                  onPressed: () {
                                    _initializeCamera((_currentCameraIndex+1)%2);
                                    // Navigator.pop(context);
                                  },
                                )
                              else IconButton(
                                icon: const Icon(Icons.flip_camera_android),
                                color: Colors.transparent,
                                iconSize: 32,
                                onPressed: () {
                                  // _initializeCamera((_currentCameraIndex+1)%2);
                                  // Navigator.pop(context);
                                },
                              ),


                              // PremiumBadge(),
                              // Container(width: 10, height: 10,),
                              BlocBuilder<VideoRecorderBloc, VideoRecorderState>(
                                builder: (context, state) {
                                  final bool isRecording = state is VideoRecording;
                                  final bool isProcessing = state is VideoProcessing;
                                  final double processingProgress =
                                      state is VideoProcessing ? state.progress : 0.0;

                                  return FloatingActionButton(
                                    backgroundColor: isRecording ? Colors.red : Colors.white,
                                    onPressed:(){
                                      print("Recording toggled");
                                      if(!isProcessing){
                                        _toggleRecording(context);
                                      } else {
                                        print("Still Processing");
                                      }
                                    },
                                    child: isProcessing
                                            ? CupertinoActivityIndicator(
                                              color: Colors.red,
                                    ) : Icon(
                                            isRecording ? Icons.stop : Icons.videocam,
                                            color: isRecording ? Colors.white : Colors.black,
                                            ),
                                  );
                                },
                              ),
                              if (true)
                                IconButton(
                                  icon: const Icon(Icons.settings),
                                  color: Colors.white,
                                  iconSize: 32,
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) {
                                        return Container(
                                          height: MediaQuery.of(context).size.height * 0.75,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).scaffoldBackgroundColor,
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
                                                    style: Theme.of(context).textTheme.titleLarge,
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () => Navigator.pop(context),
                                                  ),
                                                ],
                                              ),
                                              const Divider(),
                                              const SizedBox(height: 16),
                                              Expanded(
                                                child: GaugeSettingsScreen(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                    if(false) showDialog(
                                        context: context,
                                      builder: (context) => AlertDialog(
                                              title: const Text('Camera Mode'),
                                              content: const Text(
                                                'This mode allows you to record video with a speedometer overlay. '
                                                'The recorded video will include the speed information.\n\n'
                                                'If recording is not available on your device, you can use screen recording '
                                                'to capture this view.',
                                              ),
                                              actions: [
                                                TextButton(
                                            onPressed: () => Navigator.pop(context),
                                                  child: const Text('OK'),
                                                ),
                                              ],
                                            ),
                                      );
                                  },
                                ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
          );
        },
      ),
    );
  }
}


/// Calculates the position values for gauge placement
/// Returns EdgeInsets that can be used with Positioned widget
EdgeInsets calculateGaugePosition({
  required GaugePlacement placement,
  required double gaugeSize,
  required Size screenSize,
  double margin = 20.0,
}) {
  final height = gaugeSize * 0.65;

  switch (placement) {
    case GaugePlacement.topLeft:
      return EdgeInsets.only(top: margin, left: margin);

    case GaugePlacement.topCenter:
      return EdgeInsets.only(
        top: margin,
        left: (screenSize.width - gaugeSize) / 2,
      );

    case GaugePlacement.topRight:
      return EdgeInsets.only(top: margin, right: margin);

    case GaugePlacement.centerLeft:
      return EdgeInsets.only(
        top: (screenSize.height - height) / 2,
        left: margin,
      );

    case GaugePlacement.center:
      return EdgeInsets.only(
        top: (screenSize.height - height) / 2,
        left: (screenSize.width - gaugeSize) / 2,
      );

    case GaugePlacement.centerRight:
      return EdgeInsets.only(
        top: (screenSize.height - height) / 2,
        right: margin,
      );

    case GaugePlacement.bottomLeft:
      return EdgeInsets.only(bottom: margin, left: margin);

    case GaugePlacement.bottomCenter:
      return EdgeInsets.only(
        bottom: margin,
        left: (screenSize.width - gaugeSize) / 2,
      );

    case GaugePlacement.bottomRight:
      return EdgeInsets.only(bottom: margin, right: margin);
  }
}


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
                        Expanded(
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
                            Get.back(); // Close dialog
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
                        Get.back(); // Close dialog
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
