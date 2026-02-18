import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// A premium export-progress dialog shaped like a video frame.
///
/// • The dialog shows the video thumbnail behind a dark scrim.
/// • A thick rounded-rect border acts as the progress indicator —
///   the colored portion grows clockwise as progress increases.
/// • Listens to a [Stream<double>] (0.0 → 1.0) via [StreamBuilder].
/// • Not barrier-dismissible — if the user tries to pop, a warning
///   snack bar is shown instead.
class ExportProgressDialog extends StatelessWidget {
  /// Stream that emits progress values from 0.0 to 1.0.
  final Stream<double> progressStream;

  /// Optional path to a thumbnail image file.
  final String? thumbnailPath;

  /// Accent color used for the "completed" portion of the border.
  final Color accentColor;

  const ExportProgressDialog({
    super.key,
    required this.progressStream,
    this.thumbnailPath,
    this.accentColor = Colors.blueAccent,
  });

  /// Show the dialog on the given [context].
  ///
  /// Returns the [Future] from [showDialog] so callers can await dismissal.
  static Future<void> show(
    BuildContext context, {
    required Stream<double> progressStream,
    String? thumbnailPath,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => ExportProgressDialog(
        progressStream: progressStream,
        thumbnailPath: thumbnailPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use PopScope (Flutter 3.12+) to intercept the back button.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please wait for the export to finish. '
                      'Do not close this page.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.grey[850],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: StreamBuilder<double>(
          stream: progressStream,
          initialData: 0.0,
          builder: (context, snapshot) {
            final progress = (snapshot.data ?? 0.0).clamp(0.0, 1.0);

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CustomPaint(
                    painter: _BorderProgressPainter(
                      progress: progress,
                      activeColor: accentColor,
                      inactiveColor: Colors.grey[700]!,
                      borderWidth: 5.0,
                      borderRadius: 24.0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        // fit: StackFit.expand,
                        children: [
                          // ── Layer 1: Thumbnail ──
                          if (thumbnailPath != null)
                            Image.file(
                              File(thumbnailPath!),
                              fit: BoxFit.cover,
                            )
                          else
                            Container(color: Colors.grey[500]),

                          // ── Layer 2: Dark overlay ──
                          // Container(
                          //   color: Colors.black.withValues(alpha: 0.22),
                          // ),

                          // ── Layer 3: Text content ──
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Percentage
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: progress,
                                  ),
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  builder: (_, value, __) {
                                    return Text(
                                      '${(value * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        height: 1,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Title
                                const Text(
                                  'Exporting your video',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle / warning
                                Text(
                                  'Do not close this page or your app',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Mini linear bar for additional clarity
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER — draws a rounded-rect border as a progress indicator.
// The "completed" arc is painted in [activeColor], the rest in [inactiveColor].
// Progress goes clockwise starting from the top-center.
// ────────────────────────────────────────────────────────────────────────────

class _BorderProgressPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color activeColor;
  final Color inactiveColor;
  final double borderWidth;
  final double borderRadius;

  _BorderProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.borderWidth = 5.0,
    this.borderRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // ── Inactive (grey) background track ──
    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final path = Path()..addRRect(rrect);
    canvas.drawPath(path, bgPaint);

    if (progress <= 0) return;

    // ── Active (colored) progress ──
    // We compute the total perimeter of the rounded rect,
    // then use PathMetrics to extract the portion corresponding
    // to `progress`.

    final totalLength = _rrectPerimeter(rrect);
    final drawLength = totalLength * progress.clamp(0.0, 1.0);

    // We want to start from the top-center, but Path.addRRect starts
    // from the top-left corner. We need to offset by half the top edge
    // width plus one corner arc.
    //
    // RRect topology (addRRect starts at top-left after the TL corner arc):
    //   TL-arc  → top edge → TR-arc → right edge → BR-arc → bottom edge →
    //   BL-arc  → left edge
    //
    // To start at top-center we offset by half the top edge length.
    final topEdge = rrect.width - rrect.trRadiusX - rrect.tlRadiusX;
    final startOffset = topEdge / 2;

    final metrics = path.computeMetrics().first;

    // Draw progress starting from the computed offset
    _drawProgressArc(canvas, metrics, totalLength, startOffset, drawLength);
  }

  void _drawProgressArc(
    Canvas canvas,
    PathMetric metric,
    double totalLength,
    double startOffset,
    double drawLength,
  ) {
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    double remaining = drawLength;
    double offset = startOffset;

    // Handle wrapping around the perimeter
    while (remaining > 0) {
      final end = offset + remaining;
      if (end <= totalLength) {
        final segment = metric.extractPath(offset, end);
        canvas.drawPath(segment, activePaint);
        remaining = 0;
      } else {
        // Draw to the end, then wrap around from 0
        final segment = metric.extractPath(offset, totalLength);
        canvas.drawPath(segment, activePaint);
        remaining -= (totalLength - offset);
        offset = 0;
      }
    }
  }

  double _rrectPerimeter(RRect rrect) {
    // Approximate: 4 straight edges + 4 quarter-circle arcs
    final topEdge = rrect.width - rrect.trRadiusX - rrect.tlRadiusX;
    final bottomEdge = rrect.width - rrect.brRadiusX - rrect.blRadiusX;
    final leftEdge = rrect.height - rrect.tlRadiusY - rrect.blRadiusY;
    final rightEdge = rrect.height - rrect.trRadiusY - rrect.brRadiusY;

    final straightTotal = topEdge + bottomEdge + leftEdge + rightEdge;

    // Quarter-circle arc length ≈ π/2 * r
    final arcs = (pi / 2) *
        (rrect.tlRadiusX +
            rrect.trRadiusX +
            rrect.brRadiusX +
            rrect.blRadiusX);

    return straightTotal + arcs;
  }

  @override
  bool shouldRepaint(_BorderProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
