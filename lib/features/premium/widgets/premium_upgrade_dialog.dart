import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';

import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog_2.dart';
import 'package:speedometer/services/scheduled_notification_service.dart';

import '../bloc/premium_bloc.dart';

class PremiumUpgradeDialog extends StatefulWidget {
  final String source;

  const PremiumUpgradeDialog({super.key, required this.source});

  /// Show the premium upgrade as a modal bottom sheet.
  ///
  /// [source] identifies where this dialog was triggered from (e.g. 'labs_banner', 'feature_gate').
  /// Tracks analytics for view/dismiss and schedules an upgrade reminder
  /// if the user dismisses without purchasing.
  static Future<bool?> show(
    BuildContext context, {
    required String source,
  }) async {
    AnalyticsService().trackEvent(
      AnalyticsEvents.premiumUpgradePageViewed,
      properties: {'source': source},
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) => PremiumUpgradeDialog2(source: source),
    );

    // If dismissed without purchasing, schedule a reminder
    if (result == null || result == false) {
      AnalyticsService().trackEvent(
        AnalyticsEvents.premiumUpgradePageClosed,
        properties: {'source': source},
      );
      ScheduledNotificationService().schedulePremiumUpgradeReminder();
    }

    return result;
  }

  @override
  PremiumUpgradeDialogState createState() => PremiumUpgradeDialogState();
}

class PremiumUpgradeDialogState extends State<PremiumUpgradeDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  int _currentIndex = 0;
  final List<Map<String, dynamic>> _premiumFeatures = [
    {
      'title': 'No Ads',
      'description': 'Enjoy an ad-free experience.',
      'icon': Icons.block_flipped,
      'color': Colors.blue,
    },
    {
      'title': 'No Watermark',
      'description': 'Remove the TurboGauge watermark',
      'icon': Icons.water_drop_outlined,
      'color': Colors.purple,
    },
    {
      'title': 'Custom Gauge Placement',
      'description': 'Place your speedometer anywhere on screen',
      'icon': Icons.touch_app,
      'color': Colors.cyan,
    },
    {
      'title': 'Multiple Themes',
      'description': 'Access all gauge design themes',
      'icon': Icons.color_lens,
      'color': Colors.orange,
    },
    {
      'title': 'Unlimited Recordings',
      'description': 'Record and share as many videos as you want',
      'icon': Icons.videocam,
      'color': Colors.red,
    },
    {
      'title': 'Premium Support',
      'description': 'Priority customer support',
      'icon': Icons.support_agent,
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    // Auto-scroll through features
    Future.delayed(const Duration(seconds: 1), () {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _premiumFeatures.length;
      });
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            MediaQuery.of(context).size.height * 0.3 * _slideAnimation.value,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E1E2C),
                    Color(0xFF2D2D44),
                    Color(0xFF1A1A2E),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeader(context),
                          const SizedBox(height: 20),
                          _buildFeatureHighlight(context),
                          const SizedBox(height: 16),
                          _buildFeatureIndicators(context),
                          const SizedBox(height: 20),
                          _buildValueProposition(),
                          const SizedBox(height: 24),
                          _buildActionButtons(context),
                          const SizedBox(height: 16),
                          _buildSafeAreaPadding(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Crown icon with glow
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0x40FFD700), Colors.transparent],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.speed, color: Colors.amber, size: 40),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "TURBOGAUGE",
              style: TextStyle(
                fontFamily: 'RacingSansOne',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                    color: Colors.amber.withOpacity(0.7),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback:
                  (bounds) => const LinearGradient(
                    colors: [Colors.amber, Colors.deepOrange],
                  ).createShader(bounds),
              child: const Text(
                "PRO",
                style: TextStyle(
                  fontFamily: 'RacingSansOne',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Unlock the full power of your speedometer",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureHighlight(BuildContext context) {
    final feature = _premiumFeatures[_currentIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_currentIndex),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (feature['color'] as Color).withOpacity(0.15),
              (feature['color'] as Color).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (feature['color'] as Color).withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (feature['color'] as Color).withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (feature['color'] as Color).withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                feature['icon'] as IconData,
                color: feature['color'] as Color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature['description'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.3,
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

  Widget _buildFeatureIndicators(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _premiumFeatures.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _currentIndex == index ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _currentIndex == index
                      ? _premiumFeatures[index]['color'] as Color
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueProposition() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.15), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined, size: 18, color: Colors.amber.shade300),
          const SizedBox(width: 8),
          Text(
            "ONE-TIME PURCHASE • LIFETIME ACCESS",
            style: TextStyle(
              color: Colors.amber.shade200,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return BlocConsumer<PremiumBloc, PremiumState>(
      listener: (context, state) {
        if (state is PremiumPurchaseSuccess) {
          // Cancel the premium reminder since user purchased
          ScheduledNotificationService().cancelPremiumUpgradeReminder();
          Navigator.of(context).pop(true);
        } else if (state is PremiumPurchaseFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${state.message}'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is PremiumLoading;

        return Column(
          children: [
            // Main CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isLoading
                        ? null
                        : () {
                          AnalyticsService().trackEvent(
                            AnalyticsEvents.premiumUpgradeButtonClicked,
                          );
                          context.read<PremiumBloc>().add(PurchasePremium());
                        },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber,
                  disabledBackgroundColor: Colors.amber.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.amber.withOpacity(0.4),
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'UPGRADE TO PRO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.bolt, color: Colors.black, size: 22),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Buy once, use forever. No recurring charges.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green.shade300,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            // Dismiss + Restore row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Maybe later',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: Colors.white.withOpacity(0.15),
                ),
                TextButton(
                  onPressed: () {
                    AnalyticsService().trackEvent(
                      AnalyticsEvents.premiumRestoreClicked,
                    );
                    context.read<PremiumBloc>().add(RestorePurchases());
                  },
                  child: Text(
                    'Restore Purchases',
                    style: TextStyle(
                      color: Colors.amber.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSafeAreaPadding(BuildContext context) {
    return SizedBox(height: MediaQuery.of(context).padding.bottom + 8);
  }
}
