import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:speedometer/core/analytics/analytics_tracker.dart';
import 'package:speedometer/core/services/location_service.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/files/bloc/files_bloc.dart';
import 'package:speedometer/features/labs/presentation/labs_screen.dart';
import 'package:speedometer/core/services/camera_state_service.dart';
import 'package:speedometer/presentation/screens/camera_screen.dart';
import 'package:speedometer/features/dashcam/presentation/pages/dashcam_home_page.dart';
import 'package:speedometer/services/app_update_service.dart';
import 'package:speedometer/services/deeplink_service.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../features/badges/badge_service.dart';

import 'package:speedometer/services/tutorial_service.dart';
import 'package:speedometer/core/dialogs/dialog_manager.dart';
import 'package:speedometer/core/dialogs/app_dialog_item.dart';
import 'package:speedometer/features/tutorial/presentation/welcome_tutorial_dialog.dart';

import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';
import 'package:speedometer/features/premium/widgets/premium_feature_gate.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/speedometer/bloc/speedometer_bloc.dart';
import '../../features/speedometer/bloc/speedometer_event.dart';
import '../../features/speedometer/bloc/speedometer_state.dart';
import '../bloc/settings/settings_bloc.dart';
import '../bloc/settings/settings_state.dart';
import '../widgets/analog_speedometer.dart';
import '../widgets/analog_speedometer_2.dart';

enum AppTab { speedometer, camera, dashcam, labs }

class AppTabState {
  AppTabState._();

  static final ValueNotifier<AppTab> currentTab = ValueNotifier(
    AppTab.speedometer,
  );
  static AppTab? previousTab;

  static void updateCurrentTab(AppTab newTab) {
    if (currentTab.value == newTab) return;

    previousTab = currentTab.value;
    currentTab.value = newTab;
  }

  static String tabName(AppTab tab) {
    switch (tab) {
      case AppTab.speedometer:
        return 'speedometer';
      case AppTab.camera:
        return 'camera';
      case AppTab.dashcam:
        return 'dashcam';
      case AppTab.labs:
        return 'labs';
    }
  }
}

abstract class TabVisibilityAware {
  void onTabVisible();
  void onTabInvisible();
}

// ---------------------------------------------------------------------------
// Particle model
// ---------------------------------------------------------------------------

class _Particle {
  double x, y, vx, vy, radius, opacity, life, maxLife;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.opacity,
    required this.life,
    required this.maxLife,
  });

  void update() {
    x += vx;
    y += vy;
    life -= 0.004;
    vy -= 0.01;
    opacity = (life / maxLife).clamp(0, 1);
  }

  bool get isDead => life <= 0;
}

// ---------------------------------------------------------------------------
// Particle painter
// ---------------------------------------------------------------------------

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;

  _ParticlePainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        Paint()
          ..color = color.withOpacity(p.opacity * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------

class HomeScreen2 extends StatefulWidget {
  const HomeScreen2({super.key});

  @override
  State<HomeScreen2> createState() => _HomeScreen2State();
}

class _HomeScreen2State extends State<HomeScreen2>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final CameraStateService _cameraState = CameraStateService();
  final BadgeService _badgeService = BadgeService();
  final math.Random _rng = math.Random();

  // Animations
  late AnimationController _entranceController;
  late AnimationController _particleController;
  late AnimationController _buttonPulseController;
  late AnimationController _bgRotateController;

  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _buttonScale;
  late Animation<double> _bgRotate;

  final List<_Particle> _particles = [];
  Timer? _particleTimer;

  // For tab visibility compatibility
  final GlobalKey _speedometerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _badgeService.initialize();

    // Entrance
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    // Particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Button pulse
    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _buttonScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut),
    );

    // Background rotation
    _bgRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    _bgRotate = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_bgRotateController);

    // Spawn particles
    _particleTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _spawnParticles(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
      AppUpdateService().checkForUpdate();
      DeeplinkService().processPendingDeeplinks();
      _checkTutorial();
      context.read<SpeedometerBloc>().add(StartSpeedTracking());
    });
  }

  void _spawnParticles() {
    if (!mounted) return;
    final count = _rng.nextInt(2) + 1;
    for (int i = 0; i < count; i++) {
      final life = 0.5 + _rng.nextDouble() * 0.5;
      _particles.add(
        _Particle(
          x: _rng.nextDouble(),
          y: 0.85 + _rng.nextDouble() * 0.2,
          vx: (_rng.nextDouble() - 0.5) * 0.003,
          vy: -0.003 - _rng.nextDouble() * 0.004,
          radius: 1.5 + _rng.nextDouble() * 2.5,
          opacity: 0.6 + _rng.nextDouble() * 0.4,
          life: life,
          maxLife: life,
        ),
      );
    }
    _particles.removeWhere((p) {
      p.update();
      return p.isDead || p.y < -0.05;
    });
    if (mounted) setState(() {});
  }

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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceController.dispose();
    _particleController.dispose();
    _buttonPulseController.dispose();
    _bgRotateController.dispose();
    _particleTimer?.cancel();
    context.read<SpeedometerBloc>().add(StopSpeedTracking());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AnalyticsService().trackAppLifeCycle(state);
  }

  void _navigateTo(Widget screen, String name) {
    if (_cameraState.shouldBlockTabSwitch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot navigate while recording'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    AnalyticsService().trackEvent(
      AnalyticsEvents.tabPress,
      properties: {'tab': name},
    );
    if (name == 'Labs') {
      context.read<FilesBloc>().add(RefreshFiles());
    }
    Navigator.push(context, _slideRoute(screen));
  }

  PageRouteBuilder _slideRoute(Widget screen) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder:
        (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
    transitionDuration: const Duration(milliseconds: 380),
  );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirmation(context);
      },
      child: ChangeNotifierProvider(
        create: (_) => BadgeService()..initialize(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) {
              return BlocBuilder<SpeedometerBloc, SpeedometerState>(
                builder: (context, speedState) {
                  final speed =
                      settingsState.isMetric
                          ? speedState.speedKmh
                          : speedState.speedMph;
                  final maxSpeed =
                      settingsState.isMetric
                          ? speedState.maxSpeedKmh
                          : speedState.maxSpeedMph;
                  final distance =
                      settingsState.isMetric
                          ? speedState.distanceKm
                          : speedState.distanceMiles;
                  final unit = settingsState.isMetric ? 'km/h' : 'mph';
                  final distUnit = settingsState.isMetric ? 'km' : 'mi';
                  final accent = settingsState.speedometerColor;

                  return Stack(
                    children: [
                      // Animated background
                      _buildBackground(accent),

                      // Particles
                      // Positioned.fill(
                      //   child: CustomPaint(
                      //     painter: _ParticlePainter(
                      //       particles: List.unmodifiable(_particles),
                      //       color: accent,
                      //     ),
                      //   ),
                      // ),

                      // Main content
                      SafeArea(
                        child: FadeTransition(
                          opacity: _fadeIn,
                          child: SlideTransition(
                            position: _slideUp,
                            child: Column(
                              children: [
                                // Top bar
                                _buildTopBar(accent),

                                const SizedBox(height: 12),

                                // Stats row (Moved above speedometer)
                                _buildStatsRow(
                                  maxSpeed: maxSpeed,
                                  distance: distance,
                                  unit: unit,
                                  distUnit: distUnit,
                                  accent: accent,
                                  speedState: speedState,
                                  settingsState: settingsState,
                                ),

                                // Speedometer
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: AnalogSpeedometer2(
                                      key: _speedometerKey,
                                      speed: speed,
                                      isMetric: settingsState.isMetric,
                                      speedometerColor: accent,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Nav buttons
                                _buildNavButtons(accent),

                                const SizedBox(height: 12),
                                SafeArea(
                                  child: PremiumFeatureGate(
                                    premiumContent: const SizedBox.shrink(),
                                    freeContent: Builder(
                                      builder: (context) {
                                        return GestureDetector(
                                          onTap:
                                              () => PremiumUpgradeDialog.show(
                                            context,
                                            source: 'home_screen_sticky_banner',
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            color: Colors.amber,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 16,
                                            ),
                                            child: const Text.rich(
                                              TextSpan(
                                                children: [

                                                  TextSpan(
                                                    text: 'Your morning coffee ',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '☕ ',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'costs more than ',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'TurboGauge Premium. ',
                                                    style: TextStyle(
                                                      color: Color(0xFF001F3F),
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'Unlock lifetime access before the price goes up.',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // textAlign: TextAlign.center,
                                            )
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom sticky banner
                      if(false) Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: FadeTransition(
                          opacity: _fadeIn,
                          child: SlideTransition(
                            position: _slideUp,
                            child: PremiumFeatureGate(
                              premiumContent: const SizedBox.shrink(),
                              freeContent: Builder(
                                builder: (context) {
                                  return GestureDetector(
                                    onTap:
                                        () => PremiumUpgradeDialog.show(
                                          context,
                                          source: 'home_screen_sticky_banner',
                                        ),
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.amber,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 16,
                                      ),
                                      child: const Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  'Turbogauge premium lifetime is cheaper than your morning coffee. But not for long. ',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'Get yours now',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Background
  // ---------------------------------------------------------------------------

  Widget _buildBackground(Color accent) {
    return AnimatedBuilder(
      animation: _bgRotate,
      builder:
          (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _BackgroundPainter(angle: _bgRotate.value, color: accent),
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------

  Widget _buildTopBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TURBOGAUGE',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Live GPS Tracking',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          PremiumFeatureGate(
            premiumContent: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRO',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            freeContent: Builder(
              builder: (_) => GestureDetector(
                onTap: () => PremiumUpgradeDialog.show(
                  context,
                  source: 'home_screen_top_pro',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber, width: 1),
                  ),
                  child: const Text(
                    'Get PRO',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow({
    required double maxSpeed,
    required double distance,
    required String unit,
    required String distUnit,
    required Color accent,
    required SpeedometerState speedState,
    required SettingsState settingsState,
  }) {
    return StreamBuilder<Position>(
      stream: LocationService().getPositionStream(),
      builder: (context, snapshot) {
        final pos = snapshot.data;
        final altitude = pos?.altitude ?? 0.0;
        final accuracy = pos?.accuracy ?? 0.0;
        final altStr =
            settingsState.isMetric
                ? '${altitude.toStringAsFixed(0)} m'
                : '${(altitude * 3.28084).toStringAsFixed(0)} ft';
        final accStr = '${accuracy.toStringAsFixed(1)} m';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'MAX SPEED',
                      value: maxSpeed.toStringAsFixed(1),
                      unit: unit,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'DISTANCE',
                      value: distance.toStringAsFixed(2),
                      unit: distUnit,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reset button
                  GestureDetector(
                    onTap:
                        () => context.read<SpeedometerBloc>().add(ResetTrip()),
                    child: AnimatedBuilder(
                      animation: _buttonScale,
                      builder:
                          (_, __) => Transform.scale(
                            scale: _buttonScale.value,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: accent.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'RESET',
                                    style: TextStyle(
                                      color: accent.withOpacity(0.7),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'ALTITUDE',
                      value: altStr.split(' ')[0],
                      unit: altStr.split(' ')[1],
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'GPS SIGNAL',
                      value: accStr.split(' ')[0],
                      unit: accStr.split(' ')[1],
                      accent: accent,
                    ),
                  ),
                  const SizedBox(
                    width: 60,
                  ), // Space to align with the reset button gracefully
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Nav buttons
  // ---------------------------------------------------------------------------

  Widget _buildNavButtons(Color accent) {
    final buttons = [
      (
        Icons.videocam_rounded,
        'Camera',
        () => _navigateTo(const CameraScreen(), 'Camera'),
      ),
      (
        Icons.dashboard_customize_rounded,
        'Dashcam',
        () => _navigateTo(const DashcamHomePage(), 'Dashcam'),
      ),
      (
        Icons.science_rounded,
        'Labs',
        () => _navigateTo(const LabsScreen(), 'Labs'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children:
            buttons
                .map(
                  (b) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _NavButton(
                        icon: b.$1,
                        label: b.$2,
                        accent: accent,
                        onTap: b.$3,
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Exit dialog (unchanged logic, restyled)
  // ---------------------------------------------------------------------------

  Future<void> _showExitConfirmation(BuildContext context) async {
    AnalyticsService().trackEvent(AnalyticsEvents.closeAppDialogOpened);
    AnalyticsService().flush();

    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final controller = TextEditingController();
        bool submitted = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final hasText = controller.text.trim().isNotEmpty;
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Close the app?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Any feedback or feature request?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type your feedback here...',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged:
                        (_) => setDialogState(() {
                          if (submitted) submitted = false;
                        }),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child:
                        submitted
                            ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Feedback sent',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                            : TextButton(
                              onPressed:
                                  hasText
                                      ? () {
                                        AnalyticsService().trackEvent(
                                          AnalyticsEvents.feedbackReceived,
                                          properties: {
                                            'feedback_text':
                                                controller.text.trim(),
                                          },
                                        );
                                        AnalyticsService().flush();
                                        controller.clear();
                                        setDialogState(() => submitted = true);
                                      }
                                      : null,
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    hasText
                                        ? Colors.blueAccent
                                        : Colors.grey[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Submit Feedback',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                TextButton(
                  onPressed: () {
                    AnalyticsService().trackEvent(
                      AnalyticsEvents.closeAppDialogDismissed,
                    );
                    AnalyticsService().flush();
                    Navigator.of(dialogContext).pop(false);
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
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text(
                    'Exit',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldClose == true && context.mounted) {
      LocationService().disposeTracking();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
      );
      AnalyticsService().flush();
      await Future.delayed(const Duration(milliseconds: 200));
      SystemNavigator.pop();
    }
  }
}

// ---------------------------------------------------------------------------
// Background painter — subtle rotating conic lines
// ---------------------------------------------------------------------------

class _BackgroundPainter extends CustomPainter {
  final double angle;
  final Color color;

  _BackgroundPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final maxR = size.longestSide * 1.1;

    // Radial lines
    final linePaint =
        Paint()
          ..color = color.withOpacity(0.025)
          ..strokeWidth = 1;

    for (int i = 0; i < 24; i++) {
      final a = angle + i * math.pi / 12;
      canvas.drawLine(
        center,
        Offset(center.dx + maxR * math.cos(a), center.dy + maxR * math.sin(a)),
        linePaint,
      );
    }

    // Two concentric arcs for depth
    for (int r = 1; r <= 3; r++) {
      canvas.drawCircle(
        center,
        size.width * 0.3 * r,
        Paint()
          ..color = color.withOpacity(0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Bottom gradient fade
    final fadePaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
            stops: const [0.5, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fadePaint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.angle != angle || old.color != color;
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: accent.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
        AnalyticsTracker().log(
          "HomeScreen2ButtonPress",
          params: {"button": widget.label.toLowerCase()},
        );
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder:
            (_, __) => Transform.scale(
              scale: _scaleAnim.value,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.accent.withOpacity(0.14),
                        widget.accent.withOpacity(0.04),
                      ],
                    ),
                    border: Border.all(
                      color: widget.accent.withOpacity(0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withOpacity(0.12),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.accent, size: 26),
                      const SizedBox(height: 6),
                      Text(
                        widget.label.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live indicator widget
// ---------------------------------------------------------------------------

class _LiveIndicator extends StatefulWidget {
  final Color color;
  const _LiveIndicator({required this.color});

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blink = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blink,
      builder:
          (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(_blink.value),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(_blink.value * 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  color: widget.color.withOpacity(_blink.value),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
    );
  }
}
