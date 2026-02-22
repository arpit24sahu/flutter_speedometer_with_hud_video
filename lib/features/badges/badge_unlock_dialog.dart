import 'package:flutter/material.dart';
import 'package:speedometer/features/analytics/events/analytics_events.dart';
import 'package:speedometer/features/analytics/services/analytics_service.dart';
import 'dart:math' as math;
import 'badge_model.dart';

/// Compact, animated dialog shown when a badge is unlocked.
class BadgeUnlockDialog extends StatefulWidget {
  final AppBadge badge;
  final VoidCallback? onViewBadges;

  const BadgeUnlockDialog({
    super.key,
    required this.badge,
    this.onViewBadges,
  });

  @override
  State<BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<BadgeUnlockDialog>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _confettiController;
  late AnimationController _glowController;

  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _iconBounceAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    // --- Entry animation (scale + fade) ---
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    // Icon has a separate bounce on top of the scale
    _iconBounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.75, curve: Curves.easeOut),
    ));

    // --- Confetti burst ---
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // --- Glow pulse ---
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _glowAnim = Tween<double>(begin: 0.15, end: 0.4).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Fire animations
    _entryController.forward();
    _confettiController.forward();
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _confettiController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.badge.color;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 44),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main content column
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // === Badge icon with confetti & glow ===
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow ring
                          AnimatedBuilder(
                            animation: _glowAnim,
                            builder:
                                (_, __) => Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: badgeColor.withOpacity(
                                          _glowAnim.value,
                                        ),
                                        blurRadius: 24,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                          // Confetti particles
                          _ConfettiBurst(
                            controller: _confettiController,
                            color: badgeColor,
                          ),
                          // Icon with bounce
                          AnimatedBuilder(
                            animation: _iconBounceAnim,
                            builder:
                                (_, child) => Transform.scale(
                                  scale: _iconBounceAnim.value,
                                  child: child,
                                ),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    badgeColor.withOpacity(0.25),
                                    badgeColor.withOpacity(0.08),
                                  ],
                                ),
                                border: Border.all(
                                  color: badgeColor.withOpacity(0.5),
                                  width: 2.5,
                                ),
                              ),
                              child: Icon(
                                widget.badge.icon,
                                size: 38,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // === "Badge Unlocked!" ===
                    const Text(
                      '🎉 Badge Unlocked!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // === Badge name ===
                    Text(
                      widget.badge.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    // === Description ===
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.badge.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // === "View my badges" button ===
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onViewBadges?.call();
                        },
                        icon: const Icon(Icons.stars_rounded, size: 18),
                        label: const Text(
                          'View my badges',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: badgeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // === Close (X) button at top-right ===
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      AnalyticsService().trackEvent(
                        AnalyticsEvents.badgeUnlockedDialogDismissed,
                        properties: {
                          AnalyticsParams.badgeId: widget.badge.id.name,
                          AnalyticsParams.badgeName: widget.badge.name,
                        },
                      );
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Confetti burst widget — subtle colored dots
// ─────────────────────────────────────────────
class _ConfettiBurst extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _ConfettiBurst({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return CustomPaint(
          size: const Size(140, 140),
          painter: _ConfettiPainter(
            progress: controller.value,
            baseColor: color,
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  static final _rng = math.Random(42);
  static final List<_Particle> _particles = List.generate(16, (i) {
    final r = _rng;
    return _Particle(
      angle: r.nextDouble() * 2 * math.pi,
      speed: 28 + r.nextDouble() * 32,
      size: 2.5 + r.nextDouble() * 3.0,
      colorIndex: r.nextInt(5),
      rotationSpeed: (r.nextDouble() - 0.5) * 6,
    );
  });

  _ConfettiPainter({required this.progress, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final colors = [
      baseColor,
      baseColor.withRed((baseColor.red + 40).clamp(0, 255)),
      Colors.amber,
      Colors.white,
      baseColor.withBlue((baseColor.blue + 60).clamp(0, 255)),
    ];

    for (final p in _particles) {
      final dist = p.speed * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final x = cx + math.cos(p.angle) * dist;
      final y = cy + math.sin(p.angle) * dist;

      final paint =
          Paint()
            ..color = colors[p.colorIndex].withOpacity(opacity * 0.85)
            ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * progress * math.pi);

      // Mix of circles and small rectangles for confetti look
      if (p.colorIndex.isEven) {
        canvas.drawCircle(Offset.zero, p.size * (0.6 + 0.4 * progress), paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.6,
              height: p.size * 0.9,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final int colorIndex;
  final double rotationSpeed;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.colorIndex,
    required this.rotationSpeed,
  });
}
