import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/tidara_palette.dart';

/// Static dial ring painter containing the 72 dashed minute/second tick marks.
/// Designed to be isolated in a [RepaintBoundary] so it is rasterized once
/// and not repainted during chronometer hand sweeps.
class StaticChronometerDialRingPainter extends CustomPainter {
  final TidaraPalette palette;

  const StaticChronometerDialRingPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double radius = 114.0;

    final Paint dashPaint = Paint()
      ..color = palette.strokeSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const int count = 72;
    for (int i = 0; i < count; i++) {
      final double startA = (i * 2 * math.pi) / count;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startA,
        math.pi / count,
        false,
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StaticChronometerDialRingPainter oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark ||
      oldDelegate.palette.highContrast != palette.highContrast;
}

/// Dynamic sweep hand painter that repaints every tick without re-rasterizing
/// the stationary 72-segment dial tick ring.
class DynamicChronometerSweepHandPainter extends CustomPainter {
  final int elapsedMs;
  final TidaraPalette palette;

  const DynamicChronometerSweepHandPainter({
    required this.elapsedMs,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double radius = 114.0;

    final double angleRad =
        ((elapsedMs % 60000) / 60000.0) * 2 * math.pi - (math.pi / 2);
    final Offset dotPos = Offset(
      center.dx + radius * math.cos(angleRad),
      center.dy + radius * math.sin(angleRad),
    );

    canvas.drawCircle(
      dotPos,
      9.0,
      Paint()..color = palette.accentPrimary.withValues(alpha: 0.25),
    );
    canvas.drawCircle(dotPos, 5.0, Paint()..color = palette.accentPrimary);
    canvas.drawCircle(
      dotPos,
      5.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(
    covariant DynamicChronometerSweepHandPainter oldDelegate,
  ) =>
      oldDelegate.elapsedMs != elapsedMs ||
      oldDelegate.palette.isDark != palette.isDark;
}

/// Unified Chronometer Dial Painter retained for backwards compatibility.
class ChronometerDialPainter extends CustomPainter {
  final int elapsedMs;
  final TidaraPalette palette;

  const ChronometerDialPainter({
    required this.elapsedMs,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    StaticChronometerDialRingPainter(palette: palette).paint(canvas, size);
    DynamicChronometerSweepHandPainter(
      elapsedMs: elapsedMs,
      palette: palette,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant ChronometerDialPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs ||
      oldDelegate.palette.isDark != palette.isDark;
}
