import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../bloc/dashcam_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../utils/dashcam_formatters.dart';
import '../../data/datasources/system_monitor_interface.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import '../../../../core/analytics/analytics_tracker.dart';

/// Dashcam recording page — forced landscape for car‑mount usage.
///
/// Orientation lifecycle:
///   initState  → [landscapeRight, landscapeLeft]  (enter landscape)
///   dispose    → [portraitUp]                     (restore for rest of app)
///
/// The iOS Info.plist whitelists portrait + both landscapes so Flutter's
/// setPreferredOrientations can request landscape on this page only.
class DashcamPage extends StatefulWidget {
  const DashcamPage({super.key});

  @override
  State<DashcamPage> createState() => _DashcamPageState();
}

class _DashcamPageState extends State<DashcamPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final DashcamBloc _bloc;
  late final AnimationController _recPulse;
  late final Timer _clockTimer;
  String _time = '';
  String _date = '';
  StreamSubscription<NativeDeviceOrientation>? _orientationSub;
  NativeDeviceOrientation _currentDeviceOrientation = NativeDeviceOrientation.portraitUp;
  int _displayedSpeed = 0;
  bool _showSpeed = true;
  bool _showTimeStamp = true;
  bool _showGps = true;
  bool _lockPortrait = false;
  bool _lockLandscape = false;

  void _showControlsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            Widget toggle({
              required IconData icon,
              required String title,
              String? subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: value
                            ? const Color(0xFF34C759).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18,
                        color: value ? const Color(0xFF34C759) : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500,
                          )),
                          if (subtitle != null)
                            Text(subtitle, style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4), fontSize: 12,
                            )),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: const Color(0xFF34C759),
                      activeTrackColor: const Color(0xFF34C759).withValues(alpha: 0.35),
                      inactiveThumbColor: Colors.grey.shade500,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ],
                ),
              );
            }

            Widget sectionHeader(String title) {
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  )),
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Text('Controls', style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
                      )),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                        ),
                      ),
                    ],
                  ),

                  sectionHeader('OVERLAY'),

                  toggle(
                    icon: Icons.speed_rounded,
                    title: 'Speed',
                    subtitle: 'Speedometer on screen',
                    value: _showSpeed,
                    onChanged: (val) {
                      setState(() => _showSpeed = val);
                      setDialogState(() {});
                    },
                  ),
                  toggle(
                    icon: Icons.access_time_rounded,
                    title: 'Timestamp',
                    subtitle: 'Time & date on screen',
                    value: _showTimeStamp,
                    onChanged: (val) {
                      setState(() => _showTimeStamp = val);
                      setDialogState(() {});
                    },
                  ),
                  toggle(
                    icon: Icons.location_on_rounded,
                    title: 'GPS Coordinates',
                    subtitle: 'Lat / Lng on screen',
                    value: _showGps,
                    onChanged: (val) {
                      setState(() => _showGps = val);
                      setDialogState(() {});
                    },
                  ),

                  sectionHeader('ORIENTATION'),

                  toggle(
                    icon: Icons.stay_current_portrait_rounded,
                    title: 'Lock Portrait',
                    value: _lockPortrait,
                    onChanged: (val) {
                      setState(() {
                        _lockPortrait = val;
                        if (val) _lockLandscape = false;
                      });
                      setDialogState(() {});
                      _applyOrientation(_currentDeviceOrientation);
                    },
                  ),
                  toggle(
                    icon: Icons.stay_current_landscape_rounded,
                    title: 'Lock Landscape',
                    value: _lockLandscape,
                    onChanged: (val) {
                      setState(() {
                        _lockLandscape = val;
                        if (val) _lockPortrait = false;
                      });
                      setDialogState(() {});
                      _applyOrientation(_currentDeviceOrientation);
                    },
                  ),

                  const SizedBox(height: 8),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }

  int _applySpeedHysteresis(double rawSpeed) {
    int target = rawSpeed.round();
    int result = _displayedSpeed;
    
    if ((target - _displayedSpeed).abs() > 1) {
      result = target;
    } else if (target > _displayedSpeed) {
      if (rawSpeed >= target - 0.2) result = target;
    } else if (target < _displayedSpeed) {
      if (rawSpeed <= target + 0.2) result = target;
    }
    
    _displayedSpeed = result;
    return result;
  }

  // ─── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsTracker().trackScreen(screenName: 'DashcamPage', screenClass: 'DashcamPage');

    // Allow both landscape and portrait orientations so the user can mount
    // the phone with any side down. The plist whitelist allows this.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Listen to physical device orientation (bypassing OS rotation lock)
    // and forcefully rotate the Flutter canvas to match.
    _orientationSub = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen((NativeDeviceOrientation orientation) {
      if (!mounted) return;
      
      if (_currentDeviceOrientation != orientation) {
        setState(() {
          _currentDeviceOrientation = orientation;
        });
      }
      
      _applyOrientation(orientation);
    });

    _bloc = GetIt.instance<DashcamBloc>();
    _bloc.add(InitializeDashcam());

    _recPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _tick();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Check location permission after first frame — show Prominent Disclosure
    // dialog if not yet granted (Google Play policy requirement).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationPermission();
    });
  }

  /// Shows Google Play-mandated Prominent Disclosure dialog before requesting
  /// location permission. Handles every edge case:
  ///   - Already granted → no-op
  ///   - Denied → disclosure dialog → app settings
  ///   - Denied forever → direct to app settings
  ///   - GPS service off → prompt to enable
  ///   - Back button → blocked (barrierDismissible + PopScope)
  ///   - Race condition → guarded by _isShowingPermissionDialog
  bool _isShowingPermissionDialog = false;

  Future<void> _ensureLocationPermission() async {
    if (_isShowingPermissionDialog) return; // Re-entrancy guard
    _isShowingPermissionDialog = true;

    try {
      // 1. Check if GPS hardware/service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        await _showLocationServiceDialog();
        return;
      }

      // 2. Check current permission status
      final permission = await Geolocator.checkPermission();

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return; // ✅ Already granted — proceed normally

        case LocationPermission.deniedForever:
          // User previously denied permanently — only app settings can fix this
          if (!mounted) return;
          await _showSettingsRequiredDialog();
          return;

        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          // First time or previously denied — show Prominent Disclosure
          if (!mounted) return;
          await _showProminentDisclosureDialog();
          return;
      }
    } catch (e) {
      debugPrint('[DashcamPage] Location permission check error: $e');
      // On error, safely pop back rather than leaving user in a broken state
      if (mounted) Navigator.of(context).pop();
    } finally {
      _isShowingPermissionDialog = false;
    }
  }

  /// Prominent Disclosure Dialog (Google Play policy requirement).
  /// Explains WHY we need location BEFORE the OS prompt.
  Future<void> _showProminentDisclosureDialog() async {
    final bool? userConsented = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // Block Android back button
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
                  Icon(
                    Icons.shield_rounded,
                    color: Colors.blue.shade400,
                    size: 28,
                  ),
              const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Privacy & Permissions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                    'TurboGauge requires foreground location and camera access to enable the Dashcam feature. This allows the app to record your driving journey and overlay speed data even when the app is in the background.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
              ),
              SizedBox(height: 12),
              Text(
                'Your location data is:',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              _DisclosureBullet(text: 'Stored only on your device'),
              _DisclosureBullet(text: 'Never uploaded to any server'),
                  _DisclosureBullet(
                    text:
                        'Used to record only when you explicitly start a session',
                  ),
              SizedBox(height: 12),
              Text(
                    'You cannot record Dashcam video without these.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Not Now', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
                  child: const Text('Allow Access'),
            ),
          ],
        ),
      ),
    );

    if (userConsented == true) {
      await Geolocator.openAppSettings();
    }
    // Both "Not Now" and "Allow → settings" pop back to DashcamHomePage
    if (mounted) Navigator.of(context).pop();
  }

  /// Shown when user previously denied permanently — only app settings can help.
  Future<void> _showSettingsRequiredDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.orange.shade400, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Location Required',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text(
            'Location permission was previously denied. Please enable it in your device settings to use the dashcam.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Go Back', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Shown when GPS/location service is turned off on the device.
  Future<void> _showLocationServiceDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.gps_off_rounded, color: Colors.red.shade400, size: 28),
              const SizedBox(width: 10),
              const Text(
                'GPS Disabled',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text(
            'Please enable GPS/Location services on your device to use the dashcam.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Go Back', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openLocationSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Enable GPS'),
            ),
          ],
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _applyOrientation(NativeDeviceOrientation orientation) {
    if (!mounted) return;
    
    DeviceOrientation? uiOrientation;
    DeviceOrientation? cameraOrientation;
    
    // Crucial fix: iOS and Android have fundamentally opposite definitions for
    // landscape UI orientations at the OS level. 
    // Android: landscapeLeft = Top on Left.
    // iOS: landscapeLeft = Home Button on Left (which means Top on Right).
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    
    switch (orientation) {
      case NativeDeviceOrientation.landscapeLeft:
        if (isIOS) {
          // iOS needs opposite flutter orientation to render the UI upright.
          uiOrientation = DeviceOrientation.landscapeRight;
        } else {
          uiOrientation = DeviceOrientation.landscapeLeft;
        }
        cameraOrientation = DeviceOrientation.landscapeLeft;
        break;
      case NativeDeviceOrientation.landscapeRight:
        if (isIOS) {
          // iOS needs opposite flutter orientation to render the UI upright.
          uiOrientation = DeviceOrientation.landscapeLeft;
        } else {
          uiOrientation = DeviceOrientation.landscapeRight;
        }
        cameraOrientation = DeviceOrientation.landscapeRight;
        break;
      case NativeDeviceOrientation.portraitUp:
        uiOrientation = DeviceOrientation.portraitUp;
        cameraOrientation = DeviceOrientation.portraitUp;
        break;
      case NativeDeviceOrientation.portraitDown:
        // Force OS to stay in portraitUp because iOS notch phones ignore portraitDown requests.
        // We will manually flip the UI and Camera in the build method using RotatedBox.
        uiOrientation = DeviceOrientation.portraitUp;
        cameraOrientation = DeviceOrientation.portraitDown;
        break;
      case NativeDeviceOrientation.unknown:
        break;
    }

    if (_lockPortrait) {
      // Force UI to stay in portraitUp because iOS notch phones ignore portraitDown requests.
      uiOrientation = DeviceOrientation.portraitUp;
      cameraOrientation = orientation == NativeDeviceOrientation.portraitDown
          ? DeviceOrientation.portraitDown
          : DeviceOrientation.portraitUp;
    } else if (_lockLandscape) {
      // Force UI to landscape
      uiOrientation = isIOS ? DeviceOrientation.landscapeRight : DeviceOrientation.landscapeLeft;
      cameraOrientation = DeviceOrientation.landscapeLeft;
    }

    
    if (uiOrientation != null && cameraOrientation != null) {
      SystemChrome.setPreferredOrientations([uiOrientation]);
      
      final ctrl = _bloc.state.cameraController;
      if (ctrl != null && ctrl.value.isInitialized) {
        try {
          ctrl.lockCaptureOrientation(cameraOrientation);
        } catch (e) {
          debugPrint('[DashcamPage] Failed to lock capture orientation: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer.cancel();
    _orientationSub?.cancel();

    // Restore portrait for the rest of the app
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _recPulse.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Safety net: re-check camera state after returning from background
      _bloc.add(AppLifecycleResumed());
    }
  }

  void _tick() {
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _time = DateFormat('HH:mm:ss').format(now);
      _date = DateFormat('dd MMM yyyy').format(now);
    });
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safePad = MediaQuery.of(context).padding;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    // In native landscape, MediaQuery provides correct landscape safe‑areas.
    final edgeLeft = safePad.left + 16.0;
    final edgeRight = safePad.right + 16.0;
    final edgeTop = safePad.top + 12.0;
    final edgeBottom = safePad.bottom + 12.0;

    return BlocProvider.value(
      value: _bloc,
      child: SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MultiBlocListener(
          listeners: [
            BlocListener<DashcamBloc, DashcamState>(
              listenWhen: (p, c) => p.cameraController != c.cameraController || p.cameraRevision != c.cameraRevision,
              listener: (ctx, st) {
                // When the camera switches (lens cycled, front/back swapped), a new
                // CameraController is created which has lost the hardware orientation lock.
                // We must artificially re-apply the last known physical orientation.
                _applyOrientation(_currentDeviceOrientation);
              },
            ),
            BlocListener<DashcamBloc, DashcamState>(
              listenWhen: (p, c) =>
                  (p.error != c.error && c.error != null) ||
                  (p.isRecording && !c.isRecording && p.status == DashcamStatus.recording),
              listener: (ctx, st) {
                if (st.error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(st.error!.message),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ));
                }

                // When recording finishes successfully or stops due to an error, we close
                // the camera app (navigate back), which disposes the camera securely.
                if (!st.isRecording && !st.status.name.contains('loading')) {
                  // Only auto-pop if the widget is still mounted
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                }
              },
            ),
            BlocListener<DashcamBloc, DashcamState>(
              listenWhen: (p, c) {
                if (c.speedLimit <= 0) return false;
                double pSpeed = p.telemetry?.speedKmh ?? 0.0;
                double cSpeed = c.telemetry?.speedKmh ?? 0.0;
                if (c.speedUnit == 'mph') {
                  pSpeed *= 0.621371;
                  cSpeed *= 0.621371;
                }
                return cSpeed > c.speedLimit && pSpeed <= c.speedLimit;
              },
              listener: (ctx, st) {
                SystemSound.play(SystemSoundType.alert);
              },
            ),
          ],
          child: BlocBuilder<DashcamBloc, DashcamState>(
            builder: (ctx, state) {
            if (state.status == DashcamStatus.initial) {
              return const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              );
            }

            Widget dashcamStack = Stack(
              fit: StackFit.expand,
              children: [
                // Full‑screen camera preview
                _buildPreview(state, isPortrait),

                // Transition loading overlay (Fix Issue 5)
                if (state.status == DashcamStatus.loading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  ),

                // Top bar: back · time/date · GPS
                _buildTopBar(state, edgeLeft, edgeRight, edgeTop, isPortrait),

                // Right status strip: battery, storage, REC
                if (!isPortrait)
                  _buildRightStrip(state, edgeRight, edgeTop, edgeBottom),

                // Bottom row: Speed | Flip·Record·Lens | Temp
                _buildBottomRow(state, edgeBottom, edgeLeft, edgeRight, isPortrait),
              ],
            );

            if (_currentDeviceOrientation == NativeDeviceOrientation.portraitDown) {
              return RotatedBox(quarterTurns: 2, child: dashcamStack);
            }
            return dashcamStack;
          },
        ),
      ),
      ),
    ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CAMERA PREVIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPreview(DashcamState state, bool isPortrait) {
    final ctrl = state.cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(
        child: Text('Camera not available',
            style: TextStyle(color: Colors.white30, fontSize: 13)),
      );
    }

    // The official camera plugin handles its own aspect ratio formatting.
    // If the device is in portrait mode, the plugin internally inverts the aspect ratio.
    double nativeRatio = ctrl.value.aspectRatio;
    final isPortraitMode = MediaQuery.of(context).orientation == Orientation.portrait;
    
    // Convert to portrait aspect ratio if needed
    if (isPortraitMode && nativeRatio > 1.0) {
      nativeRatio = 1.0 / nativeRatio;
    } else if (!isPortraitMode && nativeRatio < 1.0) {
      nativeRatio = 1.0 / nativeRatio;
    }

    return KeyedSubtree(
      key: ValueKey('cam_${state.cameraRevision}'),
      child: Center(
        child: SizedBox.expand(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              // We pass a bounding box with the EXACT aspect ratio the 
              // CameraPreview will adopt internally. This guarantees no stretching.
              child: SizedBox(
                width: nativeRatio * 1000,
                height: 1000,
                child: CameraPreview(ctrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOP BAR — Back · Time/Date · GPS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTopBar(
    DashcamState state,
    double left,
    double right,
    double top,
    bool isPortrait,
  ) {
    final lat = state.telemetry?.lat ?? 0.0;
    final lng = state.telemetry?.lng ?? 0.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.black.withValues(alpha: 0.25),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(left, top, right, 14),
        child: Row(
          crossAxisAlignment: isPortrait ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            // Back button
            _circleBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
              size: 32,
            ),

            // Center: Time · Date / GPS
            Expanded(
              child: isPortrait
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_showTimeStamp) ...[
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _hud(_time, 13, Colors.white, bold: true),
                                  const SizedBox(width: 8),
                                  _hud(_date, 13, Colors.white, bold: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (_showGps) ...[
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_on, color: Colors.white38, size: 11),
                                  const SizedBox(width: 2),
                                  _hud(
                                    '${lat.toStringAsFixed(5)}°N, ${lng.toStringAsFixed(5)}°E',
                                    12,
                                    Colors.white,
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          _hud(state.videoQuality.toUpperCase(), 12, Colors.white70, bold: true),
                        ],
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_showTimeStamp) ...[
                            _hud(_time, 13, Colors.white, bold: true),
                            const SizedBox(width: 8),
                            _hud(_date, 13, Colors.white, bold: true),
                            _hud('  /  ', 13, Colors.white24, bold: true),
                          ],
                          if (_showGps) ...[
                            const Icon(Icons.location_on, color: Colors.white38, size: 11),
                            const SizedBox(width: 2),
                            _hud(
                              '${lat.toStringAsFixed(5)}°N, ${lng.toStringAsFixed(5)}°E',
                              13,
                              Colors.white,
                              bold: true,
                            ),
                            const SizedBox(width: 8),
                            _hud('  /  ', 13, Colors.white24, bold: true),
                            const SizedBox(width: 8),
                          ],
                          _hud(state.videoQuality.toUpperCase(), 13, Colors.white, bold: true),
                        ],
                      ),
                    ),
            ),

            // Right: Battery, Storage
            if (isPortrait)
              Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusRow(
                      icon: _batIcon(state.batteryLevel, state.isCharging),
                      label: '${state.batteryLevel}%',
                      color: state.batteryLevel <= 20 ? Colors.red.shade300 : Colors.white,
                    ),
                  const SizedBox(height: 6),
                  _statusRow(
                    icon: Icons.sd_storage_rounded,
                    label: DashcamFormatters.formatStorageGb(state.remainingStorageGb),
                    color: state.remainingStorageGb < 0.5 ? Colors.red.shade300 : Colors.white,
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _showControlsDialog,
                    child: _statusRow(
                      icon: Icons.tune_rounded,
                      label: 'Controls',
                      color: Colors.blueAccent.shade100,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM ROW — Speed | Flip·Record·Lens | Temp
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomRow(
    DashcamState state,
    double bottom,
    double left,
    double right,
    bool isPortrait,
  ) {
    // Temperature color/label
    final ts = state.thermalState;
    final Color tempColor;
    final String tempLabel;
    switch (ts) {
      case ThermalState.nominal:
        tempColor = Colors.green.shade400;
        tempLabel = 'Cool';
      case ThermalState.fair:
        tempColor = Colors.amber;
        tempLabel = 'Warm';
      case ThermalState.serious:
        tempColor = Colors.orange;
        tempLabel = 'Hot';
      case ThermalState.severe:
      case ThermalState.critical:
        tempColor = Colors.red;
        tempLabel = 'Overheat!';
    }

    return Positioned(
      bottom: bottom + 6,
      left: left,
      right: right,
      child: isPortrait
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Speed and Temp row just above the controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildSpeedometer(state),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.thermostat_rounded, color: tempColor, size: 20),
                              const SizedBox(width: 3),
                              Text(
                                tempLabel,
                                style: TextStyle(
                                  color: tempColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Flip · Record · Lens
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (state.isRecording)
                      Positioned(
                        bottom: 70,
                        child: _buildRecBadge(state),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _controlBtn(
                              icon: Icons.cameraswitch_rounded,
                              label: 'Flip',
                              onTap: state.isRecording
                                  ? null
                                  : () => _bloc.add(SwitchCamera()),
                              disabled: state.isRecording,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        _buildRecordButton(state),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 80,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: (!state.isFrontCamera &&
                                    state.availableLensLabels.length > 1)
                                ? _buildLensCycleButton(state)
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: Speedometer
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildSpeedometer(state),
                  ),
                ),

                // CENTER: Flip · Record · Lens
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (state.isRecording)
                      Positioned(
                        bottom: 70,
                        child: _buildRecBadge(state),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _controlBtn(
                              icon: Icons.cameraswitch_rounded,
                              label: 'Flip',
                              onTap: state.isRecording
                                  ? null
                                  : () => _bloc.add(SwitchCamera()),
                              disabled: state.isRecording,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildRecordButton(state),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: (!state.isFrontCamera &&
                                    state.availableLensLabels.length > 1)
                                ? _buildLensCycleButton(state)
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // RIGHT: Temperature
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.thermostat_rounded, color: tempColor, size: 20),
                          const SizedBox(width: 3),
                          Text(
                            tempLabel,
                            style: TextStyle(
                              color: tempColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RIGHT STATUS STRIP — Battery · Storage · REC
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRightStrip(
    DashcamState state,
    double right,
    double top,
    double bottom,
  ) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: right + 100, // Increased to prevent text overflow
      child: Container(
        decoration: _sideGradient(Alignment.centerRight, Alignment.centerLeft),
        padding: EdgeInsets.fromLTRB(12, top + 10, right, bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _statusRow(
              icon: _batIcon(state.batteryLevel, state.isCharging),
              label: '${state.batteryLevel}%',
              color: state.batteryLevel <= 20 ? Colors.red.shade300 : Colors.white70,
            ),
            const SizedBox(height: 10),
            _statusRow(
              icon: Icons.sd_storage_rounded,
              label: DashcamFormatters.formatStorageGb(state.remainingStorageGb),
              color: state.remainingStorageGb < 0.5
                  ? Colors.red.shade300
                  : Colors.white70,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showControlsDialog,
              child: _statusRow(
                icon: Icons.tune_rounded,
                label: 'Controls',
                color: Colors.blueAccent.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                shadows: const [
                  Shadow(blurRadius: 4, color: Colors.black),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REC BADGE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRecBadge(DashcamState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade800,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade700, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
          ),
          const SizedBox(width: 6),
          _hud(
            'REC ${DashcamFormatters.formatDuration(state.recordingDuration)}',
            12,
            Colors.white,
            bold: true,
          ),
        ],
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════════
  // SPEEDOMETER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSpeedometer(DashcamState state) {
    if (state.collisionAlertEndTime != null &&
        DateTime.now().isBefore(state.collisionAlertEndTime!)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.8),
              blurRadius: 10,
            )
          ],
        ),
        child: const Text(
          'COLLISION\nDETECTED',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            height: 1.1,
          ),
        ),
      );
    }

    if (!_showSpeed) return const SizedBox.shrink();

    double rawSpeed = state.telemetry?.speedKmh ?? 0.0;
    if (state.speedUnit == 'mph') {
      rawSpeed = rawSpeed * 0.621371;
    }

    final displaySpeed = _applySpeedHysteresis(rawSpeed);

    bool isOverLimit = state.speedLimit > 0 && displaySpeed > state.speedLimit;
    Color speedColor = isOverLimit ? Colors.red : Colors.white;
    double speedSize = isOverLimit ? 60 : 40;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: speedColor,
              fontSize: speedSize,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              height: 1,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
            ),
            child: Text(displaySpeed.toString()),
          ),
          const SizedBox(width: 3),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _hud(state.speedUnit, 10, speedColor.withValues(alpha: 0.54)),
          ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════
  // LENS CYCLE BUTTON
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLensCycleButton(DashcamState state) {
    if (state.availableLensLabels.isEmpty) return const SizedBox.shrink();
    
    return _controlBtn(
      icon: Icons.camera_rounded, // Aperture/lens icon
      label: '', // User requested no text
      onTap: state.isRecording
          ? null
          : () => _bloc.add(CycleLens()),
      disabled: state.isRecording,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RECORD BUTTON
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRecordButton(DashcamState state) {
    return GestureDetector(
      onTap: () {
        if (state.isRecording) {
          _bloc.add(StopRecording());
        } else {
          _bloc.add(StartRecording());
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: state.isRecording ? 22 : 46,
            height: state.isRecording ? 22 : 46,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.rectangle,
              borderRadius: state.isRecording 
                  ? BorderRadius.circular(6) 
                  : BorderRadius.circular(100), // A large radius makes it a perfect circle
              boxShadow: state.isRecording
                  ? [
                      BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 12)
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REUSABLE HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Gradient overlay for the side strips — fades from the edge inward.
  BoxDecoration _sideGradient(Alignment begin, Alignment end) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: [
          Colors.black.withValues(alpha: 0.6),
          Colors.black.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    double size = 36,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black
                  .withValues(alpha: disabled ? 0.2 : 0.4),
            ),
            child: Icon(icon,
                color: disabled ? Colors.white24 : Colors.white, size: 22),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: disabled ? Colors.white24 : Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hud(String text, double size, Color color, {bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontFamily: 'monospace',
        shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
      ),
    );
  }

  IconData _batIcon(int level, bool charging) {
    if (charging) return Icons.battery_charging_full;
    if (level > 80) return Icons.battery_full;
    if (level > 50) return Icons.battery_5_bar;
    if (level > 20) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }
}

/// Bullet-point row used in the location Prominent Disclosure dialog.
class _DisclosureBullet extends StatelessWidget {
  final String text;
  const _DisclosureBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Colors.blue, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
