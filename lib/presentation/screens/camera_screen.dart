import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path; // Add this import
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speedometer/core/services/camera_service.dart';
import 'package:speedometer/di/injection_container.dart';
import 'package:speedometer/presentation/bloc/overlay_gauge_configuration_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_bloc.dart';
import 'package:speedometer/presentation/bloc/settings/settings_state.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_bloc.dart';
import 'package:speedometer/presentation/bloc/speedometer/speedometer_state.dart';
import 'package:speedometer/presentation/widgets/digital_speedometer_overlay.dart';
import 'package:speedometer/utils.dart';
// import 'package:screen_recorder/screen_recorder.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/screen_record_service.dart';
import '../../core/services/screen_recorder.dart';
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
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _lastVideoPath;
  final CameraService _cameraService = getIt<CameraService>();
  late final ScreenRecordService _screenRecordService;
  final ScreenRecorderController _screenRecorderController = ScreenRecorderController(
    pixelRatio: 1
  );
  // bool _isScreenRecording = false;
  // Create a key for the speedometer widget
  final GlobalKey _speedometerKey = GlobalKey();
  WidgetRecorderService? _widgetRecorder;




  @override
  void initState() {
    super.initState();
    _screenRecordService = ScreenRecordServiceImpl();
    _screenRecordService.initialize();
    _initializeCamera();
  }

  Future<void> _stopRecording() async {
    final path = await _screenRecordService.stopRecording();
    if (path != null) {
      debugPrint('GIF saved to: $path');
      // You can now use the path to display, share, or manage the file
    }
  }

  Future<void> _startRecording() async {
    await _screenRecordService.startRecording();
    // Update UI
  }

  Future<void> _initializeCamera() async {
    final cameras = await _cameraService.getAvailableCameras();
    if (cameras.isEmpty) {
      // Show error if no cameras available
      return;
    }

    // Use the first camera (usually back camera)
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      // Initialize widget recorder service
      _widgetRecorder = WidgetRecorderService(
        widgetKey: _speedometerKey,
        cameraController: _controller!,
      );
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
    // _screenRecorderController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // Toggle recording of both camera and widget
  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _widgetRecorder == null) {
      return;
    }

    if (_isRecording) {
      setState(() {
        _isProcessing = true;
      });

      try {
        // Stop recording and get file paths
        final result = await _widgetRecorder!.stopRecording(
          context.read<OverlayGaugeConfigurationBloc>().state.gaugePlacement,
          context.read<OverlayGaugeConfigurationBloc>().state.gaugeRelativeSize,
        );

        setState(() {
          _isRecording = false;
          _isProcessing = false;
          _lastVideoPath = result['cameraVideoPath'];
        });
        // Show results to user
        _showRecordingResults(
            // result['cameraVideoPath'] ?? 'Error',
            // result['widgetVideoPath'] ?? 'Error',
          result['finalVideoPath'] ?? 'Error'
        );
      } catch (e) {
        debugPrint('Error stopping recording: $e');
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }
    } else {
      try {
        // Start recording
        await _widgetRecorder!.startRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        debugPrint('Error starting recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not start recording: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  Future<void> _showRecordingResults(String finalVideoPath) async {
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
              // Header with animation
              Container(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 36,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recording Complete',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
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

              // Video file info
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
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
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
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
                          Icon(
                            Icons.videocam,
                            color: Colors.greenAccent,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Video with Speedometer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
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
                                  future: await videoFile.exists() ? videoFile.length() : Future.value(0),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data! > 0) {
                                      final size = snapshot.data! / (1024 * 1024);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${size.toStringAsFixed(2)} MB',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.greenAccent,
                                          ),
                                        ),
                                      );
                                    }
                                    return SizedBox.shrink();
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
                      margin: EdgeInsets.symmetric(vertical: 16),
                      padding: EdgeInsets.all(16),
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
                          Icon(
                            Icons.lightbulb,
                            color: Colors.amber,
                            size: 24,
                          ),
                          SizedBox(width: 12),
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
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(Icons.play_circle_outline),
                            label: Text('Play Video'),
                            onPressed: () async {
                              final result = await OpenFile.open(finalVideoPath);
                              print('OpenFile result: ${result.type}, ${result.message}');
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(Icons.share),
                            label: Text(
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
                                print('Error sharing: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error sharing video: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
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
                padding: EdgeInsets.only(bottom: 20, top: 10),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: () => Get.back(),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _toggleCameraRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      try {
        final XFile file = await _controller!.stopVideoRecording();

        final newPath = await _getVideoFilePath();
        final newFile = File(newPath);
        await newFile.writeAsBytes(await file.readAsBytes());

        setState(() {
          _isRecording = false;
          _lastVideoPath = file.path; // Store the file path
        });
        print("------------ New Path: $newPath");
        _showFileActionsDialog(newPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video saved to ${newPath}'),
              duration: Duration(seconds: 10),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => _openVideo(XFile(newPath)),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error stopping recording: $e');
      }
    } else {
      try {
        await _controller!.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        debugPrint('Error starting recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not start recording: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  Future<void> _toggleScreenRecording() async {
    print('[Screen Recording] Toggle called. Recording state: $_isRecording');
    
    if (_isRecording) {
      try {
        print('[Screen Recording] Attempting to stop recording...');
        
        _screenRecorderController.stop();
        setState(() {
          _isRecording = false;
          _isProcessing = true;
        });
        print('[Screen Recording] Recording stopped successfully');
        
        print('[Screen Recording] Exporting as GIF...');
        final List<int>? gif = await _screenRecorderController.exporter.exportGif();
        
        if (gif != null) {
          print('[Screen Recording] GIF exported successfully. Size: ${gif.length} bytes');
          
          // Save the GIF to file
          final newPath = await _getGifFilePath();
          print('[Screen Recording] Saving GIF to: $newPath');
          
          final newFile = File(newPath);
          await newFile.writeAsBytes(gif);
          print('[Screen Recording] GIF saved successfully');
          
          setState(() {
            _isProcessing = false;
            _lastVideoPath = newPath;
          });
          
          print('[Screen Recording] Showing file actions dialog...');
          _showFileActionsDialog(newPath);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('GIF saved to $newPath'),
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () => _openFile(newPath),
                ),
              ),
            );
          }
        } else {
          print('[Screen Recording] ERROR: Failed to export GIF (null value returned)');
        }
      } catch (e) {
        print('[Screen Recording] ERROR during stop recording: $e');
        debugPrint('Error stopping recording: $e');
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }
    } else {
      try {
        print('[Screen Recording] Attempting to start recording...');
        
        _screenRecorderController.start();
        print('[Screen Recording] Recording started successfully');
        
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print('[Screen Recording] ERROR during start recording: $e');
        debugPrint('Error starting recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not start recording: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    print('[Screen Recording] Toggle function completed');
  }
  
  Future<String> _getGifFilePath() async {
    final String directoryPath = await getDownloadsPath();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.join(directoryPath, 'recording_$timestamp.gif');
  }

  Future<void> _openFile(String path) async {
    try {
      OpenResult result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        Get.snackbar(
          'Error',
          result.message ?? 'Could not open file',
          colorText: Colors.black,
          backgroundColor: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

    static void _showFileActionsDialog(String filePath) {
    // print("Apple");
    Get.defaultDialog(
      title: 'File Saved',
      titleStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The file has been saved at the path:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            Card(
              color: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  filePath,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, color: Colors.black,
                      fontWeight: FontWeight.bold
                  ),
                  softWrap: true,
                  overflow: TextOverflow.clip, // Prevents truncation with ellipsis
                  maxLines: null, // Allows infinite lines for full wrapping
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.open_in_new, color: Colors.white),
                  label: Text('Open File'),
                  onPressed: () async {
                    // Get.back(); // Close dialog
                    OpenResult result = await OpenFile.open(filePath);
                    if (result.type != ResultType.done) {
                      Get.snackbar(
                          'Error',
                          result.message,
                          colorText: Colors.black,
                          backgroundColor: Colors.white
                      );
                    }
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.share, color: Colors.white),
                  label: Text('Share File'),
                  onPressed: () {
                    Get.back(); // Close dialog
                    Share.shareXFiles([XFile(filePath)], text: 'Expense Report');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      radius: 10.0,
    );

    // print("Banana");
  }

  Future<String> _getVideoFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.join(directory.path, 'recording_$timestamp.mp4');
  }


  Future<void> _openVideo(XFile file) async {
    // Add this method to open/share the video
    try {
      final url = Uri.parse(file.path);
      if (!await launchUrl(url)) {
        throw 'Could not open $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
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
                                    child: (_isProcessing)
                                        ? Center(
                                      child: Stack(
                                        children: [
                                          // Black stroke text
                                          Text(
                                            "Processing your Clip...",
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              foreground: Paint()
                                                ..style = PaintingStyle.stroke
                                                ..strokeWidth = 2
                                                ..color = Colors.black,
                                            ),
                                          ),
                                          // White fill text
                                          Text(
                                            "Processing your Clip...",
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                        : null

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
                                  height: MediaQuery.of(context).size.width * state.gaugeRelativeSize,
                                  width: MediaQuery.of(context).size.width * state.gaugeRelativeSize,
                                  // width: 120,
                                  child: RepaintBoundary(
                                    key: _speedometerKey,
                                    child: DigitalSpeedometerOverlay2(
                                        isMetric: settingsState.isMetric,
                                        size: MediaQuery.of(context).size.width * state.gaugeRelativeSize
                                    )
                                    // child: BlocBuilder<SpeedometerBloc, SpeedometerState>(
                                    //   builder: (context, state2) {
                                    //     return DigitalSpeedometerOverlay2(
                                    //       speed: settingsState.isMetric ? state2.speedKmh : state2.speedMph,
                                    //       isMetric: settingsState.isMetric,
                                    //       size: MediaQuery.of(context).size.width * state.gaugeRelativeSize
                                    //     );
                                    //   },
                                    // ),
                                  ),
                                );
                              }
                            ),



                            // Recording indicator
                            // if (_isRecording)
                            //   Positioned(
                            //     top: 40,
                            //     left: 20,
                            //     child: Container(
                            //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            //       decoration: BoxDecoration(
                            //         color: Colors.red.withOpacity(0.7),
                            //         borderRadius: BorderRadius.circular(16),
                            //       ),
                            //       child: Row(
                            //         children: [
                            //           Container(
                            //             width: 12,
                            //             height: 12,
                            //             decoration: const BoxDecoration(
                            //               color: Colors.red,
                            //               shape: BoxShape.circle,
                            //             ),
                            //           ),
                            //           const SizedBox(width: 8),
                            //           const Text(
                            //             'REC',
                            //             style: TextStyle(
                            //               color: Colors.white,
                            //               fontWeight: FontWeight.bold,
                            //             ),
                            //           ),
                            //         ],
                            //       ),
                            //     ),
                            //   ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.white,
                          iconSize: 32,
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        (_isProcessing) ? FloatingActionButton(
                          backgroundColor: Colors.white,
                          // onPressed: _toggleCameraRecording,
                          onPressed: (){},
                          child: SizedBox(
                            height: 32, width: 32,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                            ),
                          ),
                        ) : FloatingActionButton(
                          backgroundColor: _isRecording ? Colors.red : Colors.white,
                          // onPressed: _toggleCameraRecording,
                          onPressed: _toggleRecording,
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.videocam,
                            color: _isRecording ? Colors.white : Colors.black,
                            size: 32,
                          ),
                        ),
                        if (_isRecording)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Text(
                                  'REC',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
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
      },
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