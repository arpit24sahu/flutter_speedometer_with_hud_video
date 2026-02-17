import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speedometer/features/premium/widgets/premium_upgrade_dialog.dart';

import '../bloc/premium_bloc.dart';

/// A widget that conditionally renders content based on premium status.
///
/// Shows [premiumContent] if the user is premium, otherwise shows [freeContent].
///
/// When [showUpgradeCta] is true and the user is not premium, an "Upgrade"
/// button is shown beneath the [freeContent] that opens the premium upgrade
/// bottom sheet.
class PremiumFeatureGate extends StatelessWidget {
  final Widget premiumContent;
  final Widget freeContent;
  final VoidCallback? onUpgradePressed;
  final bool showUpgradeCta;

  const PremiumFeatureGate({
    super.key,
    required this.premiumContent,
    required this.freeContent,
    this.onUpgradePressed,
    this.showUpgradeCta = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PremiumBloc, PremiumState>(
      builder: (context, state) {
        if (state is PremiumActive) {
          return premiumContent;
        } else {
          if (showUpgradeCta) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                freeContent,
                const SizedBox(height: 8),
                _buildUpgradeCta(context),
              ],
            );
          }
          return freeContent;
        }
      },
    );
  }

  Widget _buildUpgradeCta(BuildContext context) {
    return GestureDetector(
      onTap:
          onUpgradePressed ??
          () => PremiumUpgradeDialog.show(context, source: 'feature_gate'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 16, color: Colors.black87),
            SizedBox(width: 4),
            Text(
              'Upgrade to Pro',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
