import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/files/bloc/files_bloc.dart';
import 'package:speedometer/features/labs/presentation/labs_screen.dart';
import 'package:speedometer/core/services/camera_state_service.dart';
import 'package:speedometer/presentation/screens/camera_screen.dart';
import 'package:speedometer/services/app_update_service.dart';
import 'package:speedometer/services/deeplink_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../features/badges/badge_service.dart';

import 'package:speedometer/services/tutorial_service.dart';
import 'package:speedometer/core/dialogs/dialog_manager.dart';
import 'package:speedometer/core/dialogs/app_dialog_item.dart';
import 'package:speedometer/features/tutorial/presentation/welcome_tutorial_dialog.dart';

class AppTabState {
  AppTabState._();

  static final ValueNotifier<int> currentTabIndex = ValueNotifier(0);
  static int previousTabIndex = -1;

  static void updateCurrentTab(int newIndex) {
    if (currentTabIndex.value == newIndex) return;

    previousTabIndex = currentTabIndex.value;
    currentTabIndex.value = newIndex;
  }

  static String tabName(int index){
    switch(index) {
      case 0: return 'camera';
      // case 1: return 'speedometer';
    //   case 1: return 'files';
    // // case 3: return 'Settings';
    //   case 2: return 'jobs';
      case 1: return 'labs';
      default: return 'camera';
    }
  }
}

abstract class TabVisibilityAware {
  void onTabVisible();
  void onTabInvisible();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final CameraStateService _cameraState = CameraStateService();
  final List<GlobalKey> _screenKeys = [
    GlobalKey(),
    // GlobalKey(),
    // GlobalKey(),
    GlobalKey(),
  ];

  final GlobalKey _recordTabKey = GlobalKey();
  final GlobalKey _labsTabKey = GlobalKey();


  List<Widget> _screens() => [
    CameraScreen(key: _screenKeys[0]),
    // SpeedometerScreen(key: _screenKeys[1],),
    // FilesScreen(key: _screenKeys[1],),
    // const SettingsScreen(),
    // JobsScreen(key: _screenKeys[2]),
    LabsScreen(key: _screenKeys[1]),
  ];

  String screenName(int index){
    switch(index) {
      case 0: return 'Camera';
      // case 1: return 'Speedometer';
      // case 1: return 'Files';
    // case 3: return 'Settings';
    //   case 2: return 'Jobs';
      case 1: return 'Labs';
      default: return 'Camera';
    }
  }

  void _onItemTapped(int index) async {
    if(_selectedIndex == index) return;

    // Block tab switching while recording
    if (_cameraState.shouldBlockTabSwitch) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot switch tabs while recording'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    AnalyticsService().trackEvent(
        AnalyticsEvents.tabPress,
        properties: {
          "tab": screenName(index),
          "tabIndex": index,
          "previousTab": screenName(_selectedIndex),
          "previousTabIndex": _selectedIndex
        }
    );
    AppTabState.updateCurrentTab(index);
    _notifyInvisible(_selectedIndex);
    _notifyVisible(index);

    setState(() {
      _selectedIndex = index;
    });

    // if(_selectedIndex == 3) {
    //   DateTime startTime = DateTime.now();
    //   print("Starting creating video: ${startTime.toIso8601String()}");
    //   String finalPath = await createSpeedometerVideo("https://i.ibb.co/whLrrLNy/image.png", data);
    //   print("Done Creating video: ${DateTime.now().toIso8601String()}");
    //   print("Time taken: ${DateTime.now().difference(startTime).inMilliseconds}");
    //   File file = File(finalPath);
    //   print("Final Path: ${finalPath} ${await file.exists()}");
    //   FileStat stat = await file.stat();
    //   print("Stats: ${stat.size}");
    //   print("Final KK: ${await file.length()}");
    //
    //   final result = await OpenFile.open(finalPath);
    //   debugPrint('OpenFile result: ${result.type}, ${result.message}');
    //
    //   // final result = await Share.shareXFiles(
    //   //     [XFile(finalPath)],
    //   //     text: 'Check out my driving data captured with Speedometer app!'
    //   // );
    //   // debugPrint('ShareFile result: ${result.status}');
    //
    //
    // }

    if(_selectedIndex == 2) {
      context.read<FilesBloc>().add(RefreshFiles());
    }
  }

  // Debounce to prevent duplicate lifecycle events from rapid
  // activity transitions (e.g. ffmpeg-kit selectDocument loop).
  DateTime? _lastLifecycleEventTime;
  AppLifecycleState? _lastLifecycleState;
  static const _lifecycleDebounceMs = 2000;
  final badgeService = BadgeService();



  Future<void> _checkTutorial() async {
    final tutorialService = TutorialService();
    await tutorialService.init();

    if (tutorialService.shouldShowWelcomeTutorial) {
      AnalyticsService().trackEvent(AnalyticsEvents.welcomeTutorialShown);
      DialogManager().showDialog(
        AppDialogItem(
          dialogWidget: const WelcomeTutorialDialog(),
          barrierDismissible: false,
          priority: 0,
        ),
      );
    } else {
      // If tutorial already shown, trigger tab specific checks (if any legacy things remain, though we will remove them)
      _triggerTabTutorial(_selectedIndex);
    }
  }

  void _triggerTabTutorial(int index) {
    if (index < 0 || index >= _screenKeys.length) return;
    final state = _screenKeys[index].currentState;
    if (state is TabVisibilityAware) {
      (state as TabVisibilityAware).onTabVisible();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    badgeService.initialize();
    // Run checks after first frame when navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService().checkForUpdate();
      DeeplinkService().processPendingDeeplinks();
      _checkTutorial();
    });

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Debounce: ignore if same state fired within threshold
    final now = DateTime.now();
    if (_lastLifecycleState == state &&
        _lastLifecycleEventTime != null &&
        now.difference(_lastLifecycleEventTime!).inMilliseconds <
            _lifecycleDebounceMs) {
      return;
    }
    _lastLifecycleState = state;
    _lastLifecycleEventTime = now;

    AnalyticsService().trackAppLifeCycle(state);

    // Forward to CameraScreen for speedometer start/stop
    if (_selectedIndex == 0) {
      final cameraState = _screenKeys[0].currentState;
      if (cameraState is TabVisibilityAware) {
        if (state == AppLifecycleState.resumed) {
          (cameraState as TabVisibilityAware).onTabVisible();
        } else if (state == AppLifecycleState.paused) {
          (cameraState as TabVisibilityAware).onTabInvisible();
        }
      }
    }
  }

  void _notifyVisible(int index) {
    if (index < 0 || index >= _screenKeys.length) return;

    final state = _screenKeys[index].currentState;
    if (state is TabVisibilityAware) {
      (state as TabVisibilityAware).onTabVisible();
    }
  }

  void _notifyInvisible(int index) {
    if (index < 0 || index >= _screenKeys.length) return;

    final state = _screenKeys[index].currentState;
    if (state is TabVisibilityAware) {
      (state as TabVisibilityAware).onTabInvisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation(context);
      },
      child: ChangeNotifierProvider(
        create: (_) => BadgeService()..initialize(),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: IndexedStack(index: _selectedIndex, children: _screens())),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
            items: [
              BottomNavigationBarItem(
                icon: KeyedSubtree(
                  key: _recordTabKey,
                  child: const Icon(Icons.videocam),
                ),
                label: 'Record',
              ),
              BottomNavigationBarItem(
                icon: KeyedSubtree(
                  key: _labsTabKey,
                  child: const Icon(Icons.science),
                ),
                label: 'Labs',
              ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    AnalyticsService().trackEvent(AnalyticsEvents.closeAppDialogOpened);
    AnalyticsService().flush();

    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Exit Application',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to close the app?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  AnalyticsService().trackEvent(
                    AnalyticsEvents.closeAppNoSelected,
                  );
                  AnalyticsService().flush(); // Flush on interaction
                  AnalyticsService().trackEvent(
                    AnalyticsEvents.closeAppDialogDismissed,
                  );
                  Navigator.of(context).pop(false);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  AnalyticsService().trackEvent(
                    AnalyticsEvents.closeAppYesSelected,
                  );
                  // We will flush in the main flow before closing
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'Exit',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );

    if (shouldClose == true) {
      if (!context.mounted) return;
      LocationService().disposeTracking();

      // Show loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
      );

      // Clean up resources if needed
      // Most BLoCs close automatically or can be closed here if needed.
      // For example:
      // context.read<SpeedometerBloc>().add(StopSpeedTracking()); // handled in CameraScreen/SpeedometerScreen dispose usually

      // Flush analytics
      AnalyticsService().flush();

      // Wait for 200ms
      await Future.delayed(const Duration(milliseconds: 200));

      // Close app
      SystemNavigator.pop();
    }
  }
}


Future<String> createSpeedometerVideo(
  String imageUrl,
  Map<int, int> timeToSpeed,
) async {
  print('[SpeedoVideo] Started');

  if (timeToSpeed.isEmpty) {
    print('[SpeedoVideo] timeToSpeed is empty, exiting');
    return '';
  }

  print('[SpeedoVideo] Downloading base image');
  final response = await http.get(Uri.parse(imageUrl));
  if (response.statusCode != 200) {
    print('[SpeedoVideo] Image download failed: ${response.statusCode}');
    throw Exception('Failed to download image');
  }

  final bytes = response.bodyBytes;
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final ui.Image baseImage = frame.image;

  final double size = baseImage.width.toDouble();
  if (baseImage.height != baseImage.width) {
    print('[SpeedoVideo] Image is not square');
    throw Exception('Image must be square');
  }

  print('[SpeedoVideo] Base image loaded: ${baseImage.width}x${baseImage.height}');

  final dir = await getTemporaryDirectory();
  final String tempDirPath = dir.path;
  print('[SpeedoVideo] Temp directory: $tempDirPath');

  final times = timeToSpeed.keys.toList()..sort();
  final double totalSeconds = times.last.toDouble();

  const int fps = 2;
  final int numFrames = (totalSeconds * fps).toInt() + 1;

  print('[SpeedoVideo] Total duration: ${totalSeconds.toStringAsFixed(2)}s');
  print('[SpeedoVideo] FPS: $fps | Frames: $numFrames');

  const double minSpeed = 0.0;
  const double maxSpeed = 240.0;
  const double minAngle = 4.1887902047863905;
  const double maxAngle = 1.0471975511965976;
  const double sweepRad = minAngle - maxAngle;

  double getSpeedAt(double t) {
    if (t <= times.first.toDouble()) return timeToSpeed[times.first]!.toDouble();
    if (t >= times.last.toDouble()) return timeToSpeed[times.last]!.toDouble();

    int i = 1;
    while (i < times.length && t > times[i].toDouble()) {
      i++;
    }

    final double prevTime = times[i - 1].toDouble();
    final double nextTime = times[i].toDouble();
    final double frac = (t - prevTime) / (nextTime - prevTime);

    return timeToSpeed[times[i - 1]]! +
        frac * (timeToSpeed[times[i]]! - timeToSpeed[times[i - 1]]!);
  }

  print('[SpeedoVideo] Generating frames...');
  for (int frameIndex = 1; frameIndex <= numFrames; frameIndex++) {
    if (frameIndex % 30 == 0 || frameIndex == 1) {
      print('[SpeedoVideo] Frame $frameIndex / $numFrames');
    }

    final double t = (frameIndex - 1) / fps.toDouble();
    final double speed = getSpeedAt(t);
    final double fraction =
    ((speed - minSpeed) / (maxSpeed - minSpeed)).clamp(0.0, 1.0);
    final double angle = minAngle - fraction * sweepRad;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, size, size),
    );

    canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());

    final double cx = size / 2;
    final double cy = size / 2;
    final double length = size * 0.4;

    final needleX = cx + length * math.cos(angle);
    final needleY = cy - length * math.sin(angle);

    final paint =
        ui.Paint()
          ..color = const ui.Color.fromARGB(255, 255, 0, 0)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 5;

    canvas.drawLine(ui.Offset(cx, cy), ui.Offset(needleX, needleY), paint);

    // Draw the current speed number slightly below the center
    final textStyle = ui.TextStyle(
      color: const ui.Color.fromARGB(255, 0, 0, 0), // black text
      fontSize: size * 0.06, // ~6% of image width — adjust 0.05–0.08 as needed
      fontWeight: ui.FontWeight.bold,
      height: 1.0,
    );

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );

    final builder =
        ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(textStyle)
          ..addText('${speed.toInt()}');

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: size));

    final textX = cx - paragraph.width / 2;
    final textY = cy + size * 0.1 - paragraph.height / 2;
    canvas.drawParagraph(paragraph, ui.Offset(textX, textY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final framePath =
        '$tempDirPath/frame_${frameIndex.toString().padLeft(6, '0')}.png';

    File(framePath).writeAsBytesSync(byteData!.buffer.asUint8List());

    picture.dispose();
    img.dispose();
    print("Generating: ${frameIndex}");
  }

  print('[SpeedoVideo] Frame generation completed');

  final String outputPath =
      '$tempDirPath/output_${DateTime.now().millisecondsSinceEpoch}.mp4';
  final command = [
    '-framerate',
    '$fps',
    '-i',
    '$tempDirPath/frame_%06d.png',
    '-c:v',
    'mpeg4',
    '-q:v',
    '5',
    '-preset',
    'ultrafast',
    outputPath,
  ].join(' ');

  print('[SpeedoVideo] Running FFmpeg');
  print('[SpeedoVideo] Command: $command');

  try {
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();

    print('[SpeedoVideo] FFmpeg return code: $rc');

    if (rc?.isValueSuccess() ?? false) {
      print('[SpeedoVideo] Video created successfully: $outputPath');
      return outputPath;
    } else {
      print('[SpeedoVideo] FFmpeg failed');
      return '';
    }
  } catch (e) {
    print('[SpeedoVideo] FFmpeg exception: $e');
    return '';
  }
}

Map<int, int> data = {
  0: 65,
  1: 70,
  2: 65,
  3: 20,
  4: 55,
  5: 50,
  6: 25,
  7: 40,
  8: 35,
  9: 130,
  10: 25,
  11: 70,
  12: 150,
  13: 120,
  14: 75,
  15: 30,
  16: 35,
  17: 40,
  18: 125,
  19: 50,
  20: 55,
};
