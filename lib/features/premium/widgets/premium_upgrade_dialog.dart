import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';

import '../bloc/premium_bloc.dart';

class PremiumUpgradeDialog extends StatefulWidget {
  const PremiumUpgradeDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const PremiumUpgradeDialog(),
    );
  }

  @override
  PremiumUpgradeDialogState createState() => PremiumUpgradeDialogState();
}

class PremiumUpgradeDialogState extends State<PremiumUpgradeDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _premiumFeatures = [
    {
      'title': 'Custom Gauge Placement',
      'description': 'Place your speedometer anywhere on screen',
      'icon': Icons.touch_app,
      'color': Colors.blue,
    },
    {
      'title': 'No Watermark',
      'description': 'Remove the TurboGauge watermark',
      'icon': Icons.water_drop_outlined,
      'color': Colors.purple,
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    
    _animationController.forward();
    
    // Auto-scroll through features
    Future.delayed(Duration(seconds: 1), () {
      _startAutoScroll();
    });
  }
  
  void _startAutoScroll() {
    Future.delayed(Duration(seconds: 3), () {
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
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E1E2C),
                        Color(0xFF2D2D44),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(context),
                      SizedBox(height: 16),
                      _buildFeatureHighlight(context),
                      SizedBox(height: 16),
                      _buildFeaturesList(context),
                      SizedBox(height: 24),
                      _buildActionButtons(context),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
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
        Icon(
          Icons.speed,
          color: Colors.amber,
          size: 32,
        ),
        SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4, 
          runSpacing: 0, 
          children: [
            Text(
              "TURBOGAUGE",
              style: TextStyle(
                fontFamily: 'RacingSansOne',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 6,
                    color: Colors.amber.withOpacity(0.7),
                  ),
                ],
              ),
            ),
            Text(
              "PRO",
              style: TextStyle(
                fontFamily: 'RacingSansOne',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      Colors.amber,
                      Colors.deepOrange,
                    ],
                  ).createShader(Rect.fromLTWH(0, 0, 100, 50)),
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 2,
                    color: Colors.deepOrange.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          "Unlock premium features for your speedometer",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        SizedBox(height: 12),
        if(false) Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_outlined,
                size: 18,
                color: Colors.amber,
              ),
              SizedBox(width: 6),
              Text(
                "ONE-TIME PURCHASE • LIFETIME ACCESS",
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureHighlight(BuildContext context) {
    final feature = _premiumFeatures[_currentIndex];
    
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_currentIndex),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: feature['color'].withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: feature['color'].withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: feature['color'].withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                feature['icon'],
                color: feature['color'],
                size: 28,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature['title'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    feature['description'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
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

  Widget _buildFeaturesList(BuildContext context) {
    return Container(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _premiumFeatures.length,
          (index) => Container(
            width: 10,
            height: 10,
            margin: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentIndex == index
                  ? _premiumFeatures[index]['color']
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return BlocConsumer<PremiumBloc, PremiumState>(
      listener: (context, state) {
        if (state is PremiumPurchaseSuccess) {
          Navigator.of(context).pop(true);
        } else if (state is PremiumPurchaseFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is PremiumLoading;
        
        return Column(
          children: [
            Text(
              "One-time payment • No subscriptions",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () => context.read<PremiumBloc>().add(PurchasePremium()),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
                shadowColor: Colors.amber.withOpacity(0.5),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'UPGRADE NOW',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.bolt,
                          color: Colors.black,
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Buy once, use forever. No recurring charges.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green.shade300,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Maybe later',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 4),
            TextButton(
              onPressed: () => context.read<PremiumBloc>().add(RestorePurchases()),
              child: Text(
                'Restore Purchases',
                style: TextStyle(
                  color: Colors.amber.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
