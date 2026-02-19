import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'package:speedometer/services/scheduled_notification_service.dart';

import '../bloc/premium_bloc.dart';

// ─── Data model for a feature row ────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

// ─── Dialog ──────────────────────────────────────────────────────────────────

class PremiumUpgradeDialog2 extends StatefulWidget {
  final String source;

  const PremiumUpgradeDialog2({super.key, required this.source});

  /// Show the premium upgrade as a modal bottom sheet.
  ///
  /// [source] identifies where this dialog was triggered from
  /// (e.g. 'labs_banner', 'feature_gate').
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
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => PremiumUpgradeDialog2(source: source),
    );

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
  State<PremiumUpgradeDialog2> createState() => _PremiumUpgradeDialog2State();
}

class _PremiumUpgradeDialog2State extends State<PremiumUpgradeDialog2>
    with SingleTickerProviderStateMixin {
  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  // ── RevenueCat price ───────────────────────────────────────────────────────
  String? _priceString;       // e.g. "$4.99"
  bool _priceLoading = true;
  bool _priceError = false;

  // ── Feature list ───────────────────────────────────────────────────────────
  static const List<_Feature> _features = [
    _Feature(
      icon: Icons.videocam_outlined,
      color: Color(0xFFEF9A9A),
      title: 'Unlimited Recordings',
      description: 'Record and share as many drives as you want',
    ),
    _Feature(
      icon: Icons.water_drop_outlined,
      color: Color(0xFFCE93D8),
      title: 'No Watermark',
      description: 'Clean recordings without the TurboGauge watermark',
    ),
    _Feature(
      icon: Icons.block_flipped,
      color: Color(0xFF4FC3F7),
      title: 'No Ads',
      description: 'Enjoy a completely interruption-free experience',
    ),
    _Feature(
      icon: Icons.touch_app_outlined,
      color: Color(0xFF80DEEA),
      title: 'Unlimited Exports',
      description: 'Export as many times as you want',
    ),
    _Feature(
      icon: Icons.color_lens_outlined,
      color: Color(0xFFFFB74D),
      title: 'Multiple Themes',
      description: 'Unlock all exclusive gauge design themes',
    ),
    _Feature(
      icon: Icons.support_agent_outlined,
      color: Color(0xFFA5D6A7),
      title: 'Priority Support',
      description: 'Get faster responses from our support team',
    ),
  ];

  // ── RevenueCat product ID ──────────────────────────────────────────────────
  // Adjust this to match your actual entitlement / offering ID.
  static const String _offeringIdentifier = 'default';

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );

    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn),
    );

    _animCtrl.forward();
    _fetchPrice();
  }

  Future<void> _fetchPrice() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(_offeringIdentifier)
          ?? offerings.current;

      if (offering == null) throw Exception('No offering found');

      // Take the first available package – adjust logic to target a specific
      // package if needed (e.g. PackageType.lifetime / PackageType.annual).
      final package = offering.availablePackages.firstOrNull;
      if (package == null) throw Exception('No packages in offering');

      if (!mounted) return;
      setState(() {
        _priceString = package.storeProduct.priceString;
        _priceLoading = false;
        _priceError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _priceLoading = false;
        _priceError = true;
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(
            0,
            MediaQuery.of(context).size.height * 0.25 * _slideAnim.value,
          ),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: _buildSheet(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheet(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B1B2E),
            Color(0xFF252540),
            Color(0xFF1A1A30),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildFeaturesGrid(),
                  const SizedBox(height: 18),
                  _buildPriceBadge(),
                  const SizedBox(height: 20),
                  _buildActionButtons(context),
                  SizedBox(height: bottomPadding + 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Handle bar ─────────────────────────────────────────────────────────────

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Icon halo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.amber.withOpacity(0.25),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.35),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(Icons.speed_rounded, color: Colors.amber, size: 34),
        ),
        const SizedBox(height: 10),
        // Title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _brandText('TURBOGAUGE', Colors.white),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.amber, Color(0xFFFF6F00)],
              ).createShader(bounds),
              child: _brandText('PRO', Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Everything you need. Once. Forever.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Text _brandText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'RacingSansOne',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 2,
        shadows: const [
          Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black45),
        ],
      ),
    );
  }

  // ── Features grid ──────────────────────────────────────────────────────────

  Widget _buildFeaturesGrid() {
    // Build 2-column grid of feature rows
    final rows = <Widget>[];

    for (int i = 0; i < _features.length; i += 2) {
      final left = _features[i];
      final right = (i + 1 < _features.length) ? _features[i + 1] : null;

      rows.add(
        Row(
          children: [
            Expanded(child: _buildFeatureCell(left)),
            const SizedBox(width: 10),
            Expanded(child: right != null ? _buildFeatureCell(right) : const SizedBox()),
          ],
        ),
      );

      if (i + 2 < _features.length) {
        rows.add(const SizedBox(height: 10));
      }
    }

    return Column(children: rows);
  }

  Widget _buildFeatureCell(_Feature feature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            feature.color.withOpacity(0.12),
            feature.color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: feature.color.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(feature.icon, color: feature.color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Price badge ────────────────────────────────────────────────────────────

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.12),
            Colors.deepOrange.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: badge label
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: Colors.amber.shade300),
              const SizedBox(width: 6),
              Text(
                'ONE-TIME PURCHASE\nLIFETIME ACCESS',
                style: TextStyle(
                  color: Colors.amber.shade200,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.4,
                ),
              ),
            ],
          ),
          // Right: price
          _buildPriceWidget(),
        ],
      ),
    );
  }

  Widget _buildPriceWidget() {
    if (_priceLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.amber.shade300,
        ),
      );
    }

    if (_priceError || _priceString == null) {
      // Gracefully degrade – show nothing rather than breaking the UI.
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _priceString!,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          'one-time',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return BlocConsumer<PremiumBloc, PremiumState>(
      listener: (context, state) {
        if (state is PremiumPurchaseSuccess) {
          ScheduledNotificationService().cancelPremiumUpgradeReminder();
          Navigator.of(context).pop(true);
        } else if (state is PremiumPurchaseFailure) {
          _showErrorSnackBar(context, state.message);
        } else if (state is PremiumRestoreSuccess) {
          ScheduledNotificationService().cancelPremiumUpgradeReminder();
          Navigator.of(context).pop(true);
        }
        // else if (state is PremiumRestoreFailure) {
        //   _showErrorSnackBar(context, state.message);
        // }
      },
      builder: (context, state) {
        final isLoading = state is PremiumLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Primary CTA
            _buildCtaButton(context, isLoading),
            const SizedBox(height: 6),
            Text(
              'Buy once, use forever. No subscriptions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green.shade300,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            // Secondary row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTextBtn(
                  label: 'Maybe later',
                  color: Colors.white.withOpacity(0.45),
                  onTap: () => Navigator.of(context).pop(false),
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.white12,
                ),
                _buildTextBtn(
                  label: 'Restore Purchases',
                  color: Colors.amber.withOpacity(0.75),
                  onTap: isLoading
                      ? null
                      : () {
                    AnalyticsService().trackEvent(
                      AnalyticsEvents.premiumRestoreClicked,
                    );
                    context.read<PremiumBloc>().add(RestorePurchases());
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCtaButton(BuildContext context, bool isLoading) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
          AnalyticsService().trackEvent(
            AnalyticsEvents.premiumUpgradeButtonClicked,
          );
          context.read<PremiumBloc>().add(PurchasePremium());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          disabledBackgroundColor: Colors.amber.withOpacity(0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 10,
          shadowColor: Colors.amber.withOpacity(0.45),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Colors.black,
            strokeWidth: 2.5,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 6),
            Text(
              _priceString != null
                  ? 'UPGRADE TO PRO – $_priceString'
                  : 'UPGRADE TO PRO',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBtn({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}