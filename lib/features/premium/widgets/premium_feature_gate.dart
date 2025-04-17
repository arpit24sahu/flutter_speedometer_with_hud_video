import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/premium_bloc.dart';

class PremiumFeatureGate extends StatelessWidget {
  final Widget premiumContent;
  final Widget freeContent;
  final VoidCallback? onUpgradePressed;

  const PremiumFeatureGate({
    super.key,
    required this.premiumContent,
    required this.freeContent,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PremiumBloc, PremiumState>(
      builder: (context, state) {
        if (state is PremiumActive) {
          return premiumContent;
        } else {
          return freeContent;
        }
      },
    );
  }
}
