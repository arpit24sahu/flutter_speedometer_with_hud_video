import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'badge_model.dart';

/// Dialog shown when a badge is unlocked
class BadgeUnlockDialog extends StatefulWidget {
  final AppBadge badge;

  const BadgeUnlockDialog({
    super.key,
    required this.badge,
  });

  @override
  State<BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.badge.color.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Confetti effect
            Stack(
              alignment: Alignment.center,
              children: [
                _buildConfetti(),
                
                // Animated badge icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            widget.badge.color.withOpacity(0.3),
                            widget.badge.color.withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.badge.color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.badge.icon,
                          size: 60,
                          color: widget.badge.color,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Badge unlocked text
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const Text(
                    '🎉 Badge Unlocked! 🎉',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.badge.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.badge.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.badge.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Tier and level info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoChip(
                        'Tier ${widget.badge.tier}',
                        Icons.stars,
                        widget.badge.color,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        'Level ${widget.badge.level}',
                        Icons.trending_up,
                        widget.badge.color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.badge.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        children: List.generate(20, (index) {
          final random = math.Random(index);
          final angle = random.nextDouble() * 2 * math.pi;
          final distance = 60 + random.nextDouble() * 40;
          final x = math.cos(angle) * distance;
          final y = math.sin(angle) * distance;
          final size = 4 + random.nextDouble() * 4;
          final colors = [
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.yellow,
            Colors.purple,
            Colors.orange,
          ];

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final opacity = (1 - _controller.value).clamp(0.0, 1.0);
              return Positioned(
                left: 100 + x * _controller.value,
                top: 100 + y * _controller.value,
                child: Transform.rotate(
                  angle: _controller.value * 4 * math.pi,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: colors[random.nextInt(colors.length)],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
