import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';

/// Rotating text + CTA pairs for the premium banner.
const List<Map<String, String>> _bannerCopy = [
  {
    'text': 'TurboGauge Premium Lifetime is cheaper than your morning coffee.',
    'cta': 'Click to know your benefits',
  },
  {
    'text': 'Unlock ad-free, watermark-free exports forever.',
    'cta': 'See what Pro offers',
  },
  {
    'text': 'One-time purchase. Lifetime access. No subscriptions.',
    'cta': 'Explore Premium',
  },
  {
    'text': 'Get unlimited exports & custom gauge placements.',
    'cta': 'Click to know your benefits',
  },
  {
    'text': 'Remove watermarks and ads with a single purchase.',
    'cta': 'Learn more',
  },
];

/// A slim, full-width banner that nudges free users to check out Premium.
///
/// The [text] and [cta] are randomly picked from [_bannerCopy] on each mount.
/// The entire banner is tappable and opens the [PremiumUpgradeDialog].
class PremiumUpgradeBanner extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final Color ctaColor;
  final String source;

  // PremiumUpgradeBanner({
  //   super.key,
  //   this.backgroundColor = const Color(0xFF1A1A2E),
  //   this.textColor = const Color(0xFFE0E0E0),
  //   this.ctaColor = const Color(0xFFFFD54F),
  //   this.source = 'labs_banner',
  // });

    PremiumUpgradeBanner({
    super.key,
    this.backgroundColor = Colors.yellow,
    this.textColor = Colors.black,
    this.ctaColor = Colors.black,
    this.source = 'labs_banner',
  });

  // Pick a random copy pair once per widget instance.
  late final _copy = _bannerCopy[Random().nextInt(_bannerCopy.length)];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => PremiumUpgradeDialog.show(context, source: source),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(color: ctaColor.withOpacity(0.25), width: 0.5),
            bottom: BorderSide(color: ctaColor.withOpacity(0.25), width: 0.5),
          ),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'TurboGauge Premium: ',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: '${_copy['text']} ',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              TextSpan(
                text: _copy['cta'],
                style: TextStyle(
                  color: ctaColor,
                  fontSize: 11,
                  height: 1.4,
                  decoration: TextDecoration.underline,
                  decorationColor: ctaColor,
                  // fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
