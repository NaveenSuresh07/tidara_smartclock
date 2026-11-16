import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/ephemeris/noaa_ephemeris.dart';
import '../../core/theme/tidara_palette.dart';
import '../../shared/widgets/liquid_glass_components.dart';

// Interactive 180-Degree Circadian Sunrise Arch
class SunriseArcDialWidget extends StatelessWidget {
  final int wakeMinutesFromMidnight;
  final int sunriseMinutesFromMidnight;
  final TidaraPalette palette;
  final bool use24Hour;
  final bool plainLanguage;
  final ValueChanged<int> onChangeWakeMinutes;

  const SunriseArcDialWidget({
    super.key,
    required this.wakeMinutesFromMidnight,
    required this.sunriseMinutesFromMidnight,
    required this.palette,
    required this.use24Hour,
    required this.plainLanguage,
    required this.onChangeWakeMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final int minWake = math.max(180, sunriseMinutesFromMidnight - 140);
    final int maxWake = math.min(600, sunriseMinutesFromMidnight + 110);
    final double normalized =
        ((wakeMinutesFromMidnight - minWake) / (maxWake - minWake)).clamp(
          0.0,
          1.0,
        );

    final String formatted = CircadianEphemeris.formatMinutes12h(
      wakeMinutesFromMidnight,
      use24Hour: use24Hour,
    );
    final List<String> parts = formatted.split(' ');
    final String digits = parts.first;
    final String period = parts.length > 1 ? parts.last : '';

    final int delta = sunriseMinutesFromMidnight - wakeMinutesFromMidnight;
    String phaseLabel;
    if (delta > 0) {
      phaseLabel = 'Pre-Sunrise | ${delta}m before sunrise';
    } else if (delta == 0) {
      phaseLabel = 'Exact Sunrise · 0m at sunrise';
    } else {
      final int afterDelta = delta.abs();
      phaseLabel = 'Post-Sunrise Morning | ${afterDelta}m after sunrise';
    }

    void updateFromPosition(Offset localPos) {
      const Offset arcCenter = Offset(134.0, 118.0);
      final double dx = localPos.dx - arcCenter.dx;
      final double dy = arcCenter.dy - localPos.dy;
      double angle = math.atan2(dy, dx);
      if (angle < 0) angle = dx < 0 ? math.pi : 0.0;
      angle = angle.clamp(0.0, math.pi);
      final double frac = 1.0 - (angle / math.pi);
      final int rawMins =
          ((minWake + frac * (maxWake - minWake)) / 5.0).round() * 5;
      if (rawMins != wakeMinutesFromMidnight) {
        HorologicalAudioEngine.instance.playEscapementClick(
          pitchHz: 980 + frac * 300,
        );
        onChangeWakeMinutes(rawMins);
      }
    }

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 268,
            height: 132,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => updateFromPosition(d.localPosition),
              onPanUpdate: (d) => updateFromPosition(d.localPosition),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: StaticSunriseArcDialPainter(palette: palette),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: DynamicSunriseBeadPainter(
                        normalizedProgress: normalized,
                        palette: palette,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 6,
                        left: 10,
                        right: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GlassButton.iconOnly(
                            icon: Icons.remove,
                            semanticLabel: 'Decrease wake time by 5 minutes',
                            tooltip: '-5m',
                            onPressed: () {
                              final int next = math.max(
                                minWake,
                                wakeMinutesFromMidnight - 5,
                              );
                              HorologicalAudioEngine.instance
                                  .playEscapementClick(pitchHz: 940);
                              onChangeWakeMinutes(next);
                            },
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    digits,
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w600,
                                      height: 1.0,
                                      color: palette.textPrimary,
                                      fontFeatures: const [
                                        ui.FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  if (period.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      period,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GlassButton.iconOnly(
                            icon: Icons.add,
                            semanticLabel: 'Increase wake time by 5 minutes',
                            tooltip: '+5m',
                            onPressed: () {
                              final int next = math.min(
                                maxWake,
                                wakeMinutesFromMidnight + 5,
                              );
                              HorologicalAudioEngine.instance
                                  .playEscapementClick(pitchHz: 1180);
                              onChangeWakeMinutes(next);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          phaseLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.accentPrimary,
          ),
        ),
      ],
    );
  }
}

/// Static arc painter drawing the background semi-circle, 40 dashed arc divisions,
/// and horizontal dashed baseline. Wrapped in a [RepaintBoundary] to preserve GPU cache.
class StaticSunriseArcDialPainter extends CustomPainter {
  final TidaraPalette palette;

  const StaticSunriseArcDialPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, 118.0);
    const double radius = 112.0;

    final Path fillPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi,
      )
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = palette.surfaceCard.withValues(alpha: 0.32),
    );

    final Paint dashPaint = Paint()
      ..color = palette.strokeSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const int segments = 40;
    for (int i = 0; i < segments; i++) {
      final double startA = math.pi + (i * math.pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startA,
        math.pi / (segments * 1.8),
        false,
        dashPaint,
      );
    }

    for (double x = center.dx - radius; x < center.dx + radius; x += 7) {
      canvas.drawLine(
        Offset(x, center.dy),
        Offset(math.min(x + 3.5, center.dx + radius), center.dy),
        dashPaint..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StaticSunriseArcDialPainter oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark ||
      oldDelegate.palette.highContrast != palette.highContrast;
}

/// Dynamic solar bead cursor painter updated during touch scrubbing without
/// repainting the 40-segment background arch.
class DynamicSunriseBeadPainter extends CustomPainter {
  final double normalizedProgress;
  final TidaraPalette palette;

  const DynamicSunriseBeadPainter({
    required this.normalizedProgress,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, 118.0);
    const double radius = 112.0;

    final double angleRad = math.pi * (1.0 - normalizedProgress);
    final Offset nodePos = Offset(
      center.dx + radius * math.cos(angleRad),
      center.dy - radius * math.sin(angleRad),
    );

    canvas.drawCircle(
      nodePos,
      9.0,
      Paint()..color = palette.accentSolar.withValues(alpha: 0.28),
    );
    canvas.drawCircle(nodePos, 5.5, Paint()..color = palette.accentSolar);
    canvas.drawCircle(
      nodePos,
      5.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant DynamicSunriseBeadPainter oldDelegate) =>
      oldDelegate.normalizedProgress != normalizedProgress ||
      oldDelegate.palette.isDark != palette.isDark;
}

/// Unified SunriseArcPainter retained for backwards compatibility.
class SunriseArcPainter extends CustomPainter {
  final double normalizedProgress;
  final TidaraPalette palette;

  const SunriseArcPainter({
    required this.normalizedProgress,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    StaticSunriseArcDialPainter(palette: palette).paint(canvas, size);
    DynamicSunriseBeadPainter(
      normalizedProgress: normalizedProgress,
      palette: palette,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant SunriseArcPainter oldDelegate) =>
      oldDelegate.normalizedProgress != normalizedProgress ||
      oldDelegate.palette.isDark != palette.isDark;
}
