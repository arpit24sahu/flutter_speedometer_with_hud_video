import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bloc/dashcam_bloc.dart';
import 'dashcam_page.dart';
import 'dashcam_settings_page.dart';
import 'recordings_gallery_page.dart';
import 'insufficient_storage_page.dart';
import '../../../../core/analytics/analytics_tracker.dart';
import '../../../../core/analytics/analytics_events.dart';
import '../../domain/usecases/manage_storage_usecase.dart';

class DashcamHomePage extends StatefulWidget {
  const DashcamHomePage({super.key});

  @override
  State<DashcamHomePage> createState() => _DashcamHomePageState();
}

class _DashcamHomePageState extends State<DashcamHomePage> with SingleTickerProviderStateMixin {
  late final DashcamBloc _bloc;
  bool _isCheckingStorage = false;
  
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  late final Animation<double> _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
  );

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.instance<DashcamBloc>();
    _bloc.add(LoadDashcamSettings());
    AnalyticsTracker().trackScreen(screenName: 'DashcamHomePage', screenClass: 'DashcamHomePage');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Disk Space Gating ─────────────────────────────────────────

  Future<void> _onCameraButtonTapped() async {
    if (_isCheckingStorage) return;
    setState(() => _isCheckingStorage = true);

    try {
      final manageStorage = GetIt.instance<ManageStorageUseCase>();
      final result = await manageStorage.getGlobalFreeSpaceGb();

      double freeSpaceGb = 0.0;
      if (result.isSuccess) {
        freeSpaceGb = result.value;
      }

      // Log the disk space check event
      AnalyticsTracker().log(
        AnalyticsEvents.dashcam_disk_space_checked,
        params: {
          AnalyticsParams.freeDiskSpaceGb: freeSpaceGb.toStringAsFixed(2),
        },
      );

      if (!mounted) return;

      if (freeSpaceGb < 2.0) {
        // BLOCK: Insufficient storage
        AnalyticsTracker().log(
          AnalyticsEvents.dashcam_insufficient_storage_shown,
          params: {
            AnalyticsParams.freeDiskSpaceGb: freeSpaceGb.toStringAsFixed(2),
          },
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InsufficientStoragePage(freeSpaceGb: freeSpaceGb),
          ),
        );
      } else if (freeSpaceGb < 10.0) {
        // CAUTION: Low storage warning with bypass
        AnalyticsTracker().log(
          AnalyticsEvents.dashcam_storage_caution_shown,
          params: {
            AnalyticsParams.freeDiskSpaceGb: freeSpaceGb.toStringAsFixed(2),
          },
        );
        _showLowStorageCautionDialog(freeSpaceGb);
      } else {
        // PROCEED: Enough storage
        _openCamera(freeSpaceGb);
      }
    } catch (e) {
      debugPrint('[DashcamHomePage] Storage check error: $e');
      // On error, let the user proceed — don't block on a failed check
      if (mounted) _openCamera(0.0);
    } finally {
      if (mounted) {
        setState(() => _isCheckingStorage = false);
      }
    }
  }

  void _openCamera(double freeSpaceGb) {
    AnalyticsTracker().log(
      AnalyticsEvents.dashcam_camera_opened,
      params: {AnalyticsParams.freeDiskSpaceGb: freeSpaceGb.toStringAsFixed(2)},
    );
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DashcamPage()),
    );
  }

  void _showLowStorageCautionDialog(double freeSpaceGb) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor:
              theme.brightness == Brightness.dark
                  ? const Color(0xFF1A1A2E)
                  : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber.shade700,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Low Storage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Free space badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.shade700.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sd_storage_rounded,
                      color: Colors.amber.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${freeSpaceGb.toStringAsFixed(1)} GB available',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We recommend maintaining at least 10 GB of free storage before '
                'using the dashcam. Running low on space during recording may cause '
                'video corruption or device slowdowns.',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Go Back',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                AnalyticsTracker().log(
                  AnalyticsEvents.dashcam_storage_caution_bypassed,
                  params: {
                    AnalyticsParams.freeDiskSpaceGb: freeSpaceGb
                        .toStringAsFixed(2),
                  },
                );
                _openCamera(freeSpaceGb);
              },
              child: Text(
                'I understand, proceed anyway',
                style: TextStyle(
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Feedback Email ────────────────────────────────────────────

  Future<void> _openFeedbackEmail() async {
    AnalyticsTracker().log(AnalyticsEvents.dashcam_feedback_tapped);
    final uri = Uri(
      scheme: 'mailto',
      path: 'rptsahu1@gmail.com',
      queryParameters: {
        'subject': 'Dashcam Feedback — TurboGauge',
        'body':
            'Hi Team,\n\nI\'d like to share the following feedback about the Dashcam feature:\n\n',
      },
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[DashcamHomePage] Could not launch email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        // titleSpacing: 8,
        // toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: Text(
          'Dashcam',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          //   // fontFamily: 'Outfit',
          //   // fontSize: 24,
          //   // fontWeight: FontWeight.w700,
          //   color: theme.colorScheme.onSurface,
          //   // letterSpacing: -0.5,
          ),
        ),
        actions: [
          _buildModernIconButtonAction(
            context,
            icon: Icons.settings_rounded,
            label: 'Settings',
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DashcamSettingsPage()),
            ),
          ),
          _buildModernIconButtonAction(
            context,
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordingsGalleryPage()),
            ),
          ),
          if(false) Container(
            // margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF343a40) // gunmetal
                  : const Color(0xFFe9ecef), // platinum
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModernIconButtonAction(
                  context,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DashcamSettingsPage()),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                ),
                _buildModernIconButtonAction(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecordingsGalleryPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocBuilder<DashcamBloc, DashcamState>(
        bloc: _bloc,
        builder: (context, state) {
          return SafeArea(
            child: Center(
              child: Column(
                children: [
                  if(false) const SizedBox(height: 20),

                  if(false) Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF343a40) // gunmetal
                          : const Color(0xFFe9ecef), // platinum
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                        width: 1,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModernTabAction(
                              context,
                              icon: Icons.settings_rounded,
                              label: 'Settings',
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DashcamSettingsPage()),
                              ),
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                          ),
                          Expanded(
                            child: _buildModernTabAction(
                              context,
                              icon: Icons.photo_library_rounded,
                              label: 'Gallery',
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RecordingsGalleryPage()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isCheckingStorage ? null : _onCameraButtonTapped,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return RepaintBoundary(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer pulsing halo
                                    Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withValues(alpha: 0.1 * (2.2 - _pulseAnimation.value)),
                                        ),
                                      ),
                                    ),
                                    // Inner pulsing halo
                                    Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withValues(alpha: 0.2 * (2.2 - _pulseAnimation.value)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                          // Core solid button
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child:
                                  _isCheckingStorage
                                      ? const SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.videocam_rounded,
                                        size: 42,
                                        color: Colors.white,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tap to Start Dashcam',
                    style: TextStyle(fontFamily: 'Outfit',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mount your phone securely and ensure a clear view of the road before starting.',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // ── Quick Toggle Row ──────────────────────────
                  ClipRRect(
                    child: Container(
                      // margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF343a40) // gunmetal
                            : const Color(0xFFe9ecef), // platinum
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Row(
                          children: [
                            // Mic toggle
                            Expanded(
                              child: _QuickToggleButton(
                                icon:
                                    state.enableMic
                                        ? Icons.mic_rounded
                                        : Icons.mic_off_rounded,
                                label: 'Audio',
                                isSelected: state.enableMic,
                                isDark: isDark,
                                onTap: () => _bloc.add(ToggleMic()),
                              ),
                            ),
                            VerticalDivider(
                              width: 3,
                              thickness: 3,
                              color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                            ),
                            // const SizedBox(width: 10),
                            // GPS toggle
                            Expanded(
                              child: _QuickToggleButton(
                                icon:
                                    state.enableGps
                                        ? Icons.location_on_rounded
                                        : Icons.location_off_rounded,
                                label: 'GPS',
                                isSelected: state.enableGps,
                                isDark: isDark,
                                onTap: () => _bloc.add(ToggleGps()),
                              ),
                            ),
                            VerticalDivider(
                              width: 3,
                              thickness: 3,
                              color: isDark ? const Color(0xFF6c757d) : const Color(0xFFced4da),
                            ),
                            // const SizedBox(width: 10),
                            // Speed-unit toggle (cycles between km/h ↔ mph)
                            Expanded(
                              child: _QuickToggleButton(
                                icon: Icons.speed_rounded,
                                label: state.speedUnit,
                                isSelected:
                                    true, // always active, just shows current unit
                                isDark: isDark,
                                onTap: () {
                                  final next = state.speedUnit == 'km/h' ? 'mph' : 'km/h';
                                  _bloc.add(UpdateSpeedUnit(next));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Experimental Feature Banner ──────────────────
                  GestureDetector(
                    onTap: _openFeedbackEmail,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                          ? Colors.amber.shade900.withValues(alpha: 0.2)
                          : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(0),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: isDark
                                ? Colors.amber.shade700.withValues(alpha: 0.4)
                                : Colors.amber.shade300,
                            width: 1,
                          )
                        ),

                        // border: Border.all(
                        //
                        // ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.science_rounded,
                                size: 20,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Experimental Feature',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The dashcam is currently in beta. Some features may behave unexpectedly. '
                            'We\'d love to hear your feedback to make it better! Tap here to submit feedback. 📩',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          if(false) const SizedBox(height: 10),
                          if(false) GestureDetector(
                            onTap: _openFeedbackEmail,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mail_outline_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Send us feedback or feature requests',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildModernTabAction(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required bool isDark,
      }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernIconButtonAction(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required bool isDark,
      }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Icon(
          icon,
          // size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Compact toggle button with icon on top, label below.
/// Tap to select/unselect. Visually adapts to theme.
class _QuickToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor =
        isSelected
            ? (isDark
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : theme.colorScheme.primary.withValues(alpha: 0.1))
            : (isDark ? const Color(0xFF2A2D32) : const Color(0xFFE8EAED));

    final borderColor =
        isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.4)
            : (isDark ? const Color(0xFF4A4D52) : const Color(0xFFD0D3D8));

    final iconColor =
        isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    final labelColor =
        isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: (){
        onTap();
        HapticFeedback.mediumImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          // borderRadius: BorderRadius.circular(16),
          // border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
