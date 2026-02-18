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
      barrierColor: Colors.black38,
      builder: (_) => ExportProgressDialog(
        progressStream: progressStream,
        thumbnailPath: thumbnailPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please wait for the export to finish.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.black87,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ── Background blur ──
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),

            Center(
              child: StreamBuilder<double>(
                stream: progressStream,
                initialData: 0.0,
                builder: (context, snapshot) {
                  final progress = (snapshot.data ?? 0.0).clamp(0.01, 0.99);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: AspectRatio(
                      aspectRatio: 9/16,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return CustomPaint(
                            size: constraints.biggest,
                            painter: _BorderProgressPainter(
                              progress: progress,
                              activeColor: Colors.amber,
                              inactiveColor: Colors.grey.shade800,
                              borderWidth: 6,
                              borderRadius: 24,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: ClipRRect(
                                borderRadius:
                                BorderRadius.circular(24),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // ── Thumbnail ──
                                    if (thumbnailPath != null)
                                      Image.file(
                                        File(thumbnailPath!),
                                        fit: BoxFit.cover,
                                      )
                                    else
                                      Container(
                                          color: Colors.grey.shade700),

                                    // ── Dark overlay ──
                                    Container(
                                      color: Colors.black
                                          .withOpacity(0.35),
                                    ),

                                    // ── Content ──
                                    Center(
                                      child: Column(
                                        mainAxisSize:
                                        MainAxisSize.min,
                                        children: [
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(
                                              begin: 0,
                                              end: progress,
                                            ),
                                            duration: const Duration(
                                                milliseconds: 300),
                                            builder:
                                                (_, value, __) {
                                              return Text(
                                                '${(value * 100).toInt()}%',
                                                style:
                                                const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 48,
                                                  fontWeight:
                                                  FontWeight.w800,
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            "Exporting Video",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight:
                                              FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: 160,
                                            child:
                                            LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 5,
                                              backgroundColor:
                                              Colors.white
                                                  .withOpacity(
                                                  0.1),
                                              valueColor:
                                              AlwaysStoppedAnimation(
                                                  accentColor),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
