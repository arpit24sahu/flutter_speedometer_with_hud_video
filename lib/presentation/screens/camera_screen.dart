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
                            Positioned(
                              top: 40,
                              right: 20,
                              child: BlocBuilder<SpeedometerBloc, SpeedometerState>(
                                builder: (context, state) {
                                  return DigitalSpeedometerOverlay(
                                    speed: settingsState.isMetric ? state.speedKmh : state.speedMph,
                                    isMetric: settingsState.isMetric,
                                    speedometerColor: settingsState.speedometerColor,
                                  );
                                },
                              ),
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
                          onPressed: _toggleScreenRecording,
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
                          icon: const Icon(Icons.info_outline),
                          color: Colors.white,
                          iconSize: 32,
                          onPressed: () {
                            showDialog(
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