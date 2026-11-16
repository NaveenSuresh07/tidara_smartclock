import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/theme/tidara_palette.dart';

class SandGrainParticle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;
  bool bounced = false;
  double alpha = 1.0;

  SandGrainParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
  });
}

class SculpturalHourglassWidget extends StatefulWidget {
  final ValueListenable<double> progressListenable;
  final bool isRunning;
  final int flipGeneration;
  final TidaraPalette palette;
  final VoidCallback onManualFlip;

  const SculpturalHourglassWidget({
    super.key,
    required this.progressListenable,
    required this.isRunning,
    required this.flipGeneration,
    required this.palette,
    required this.onManualFlip,
  });

  @override
  State<SculpturalHourglassWidget> createState() =>
      _SculpturalHourglassWidgetState();
}

class _SculpturalHourglassWidgetState extends State<SculpturalHourglassWidget>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late Animation<double> _rotationAnim;
  late final Ticker _particleTicker;
  final List<SandGrainParticle> _particles = [];
  final math.Random _rng = math.Random();
  double _innerCounterRad = 0.0;
  double _dashPhase = 0.0;
  int _lastSpawnMs = 0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    final double initRad = widget.flipGeneration * math.pi;
    _rotationAnim = Tween<double>(begin: initRad, end: initRad).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeOutCubic),
    );
    _innerCounterRad = -initRad;

    _particleTicker = createTicker((elapsed) {
      if (!widget.isRunning) {
        if (_particles.isNotEmpty) {
          setState(() => _particles.clear());
        }
        return;
      }
      final int nowMs = elapsed.inMilliseconds;
      final double p = widget.progressListenable.value.clamp(0.0, 1.0);
      final double bottomAcc = math.pow(p, 0.92).toDouble();
      final double lowerCrestY = 138.0 - bottomAcc * 46.0;

      if (p < 0.998 && nowMs - _lastSpawnMs > 30) {
        _lastSpawnMs = nowMs;
        _particles.add(
          SandGrainParticle(
            x: 48.0 + (_rng.nextDouble() - 0.5) * 1.5,
            y: 72.0,
            vx: (_rng.nextDouble() - 0.5) * 0.16,
            vy: 0.9 + _rng.nextDouble() * 0.4,
            radius: 1.15 + _rng.nextDouble() * 0.35,
            color: _rng.nextDouble() > 0.35
                ? const Color(0xFFC24C27)
                : const Color(0xFFE58A38),
          ),
        );
      }

      for (int i = _particles.length - 1; i >= 0; i--) {
        final g = _particles[i];
        g.vy += 0.095;
        g.x += g.vx;
        g.y += g.vy;
        if (!g.bounced && g.y >= lowerCrestY) {
          g.y = lowerCrestY;
          g.vy = -g.vy * 0.25;
          g.vx = (_rng.nextDouble() - 0.5) * 1.3;
          g.bounced = true;
        } else if (g.bounced) {
          g.alpha -= 0.09;
        }
        if (g.alpha <= 0 || g.y > 137.5) {
          _particles.removeAt(i);
        }
      }

      setState(() {
        _dashPhase = (_dashPhase + 0.65) % 10.0;
      });
    });

    if (widget.isRunning) {
      _particleTicker.start();
    }
  }

  @override
  void didUpdateWidget(covariant SculpturalHourglassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_particleTicker.isActive) {
      _particleTicker.start();
    } else if (!widget.isRunning && _particleTicker.isActive) {
      _particleTicker.stop();
      _particles.clear();
    }

    if (oldWidget.flipGeneration != widget.flipGeneration) {
      final double startRad = _rotationAnim.value;
      final double endRad = widget.flipGeneration * math.pi;
      _rotationAnim = Tween<double>(begin: startRad, end: endRad).animate(
        CurvedAnimation(parent: _flipController, curve: Curves.easeOutCubic),
      );
      _flipController.forward(from: 0.0);
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) {
          setState(() {
            _innerCounterRad = -endRad;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _particleTicker.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sculptural Hourglass. Tap to reset timer with undo.',
      child: GestureDetector(
        onTap: widget.onManualFlip,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _flipController,
            widget.progressListenable,
          ]),
          builder: (context, _) {
            return Transform.rotate(
              angle: _rotationAnim.value,
              child: Transform.rotate(
                angle: _innerCounterRad,
                child: SizedBox(
                  width: 96,
                  height: 144,
                  child: CustomPaint(
                    painter: HourglassVesselPainter(
                      progress: widget.progressListenable.value,
                      isRunning: widget.isRunning,
                      particles: _particles,
                      dashPhase: _dashPhase,
                      palette: widget.palette,
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

class HourglassVesselPainter extends CustomPainter {
  final double progress;
  final bool isRunning;
  final List<SandGrainParticle> particles;
  final double dashPhase;
  final TidaraPalette palette;

  const HourglassVesselPainter({
    required this.progress,
    required this.isRunning,
    required this.particles,
    required this.dashPhase,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path upperBulb = Path()
      ..moveTo(8, 6)
      ..cubicTo(8, 44, 43, 64, 45, 72)
      ..lineTo(51, 72)
      ..cubicTo(53, 64, 88, 44, 88, 6)
      ..close();

    final Path lowerBulb = Path()
      ..moveTo(45, 72)
      ..cubicTo(43, 80, 8, 100, 8, 138)
      ..lineTo(88, 138)
      ..cubicTo(88, 100, 53, 80, 51, 72)
      ..close();

    final Paint glassFill = Paint()
      ..color = Colors.white.withValues(alpha: palette.isDark ? 0.05 : 0.22);
    final Paint glassStroke = Paint()
      ..color = palette.strokeSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(upperBulb, glassFill);
    canvas.drawPath(lowerBulb, glassFill);

    final double p = progress.clamp(0.0, 1.0);
    final double topRem = math.pow(math.max(0.0, 1.0 - p), 0.85).toDouble();
    final double botAcc = math.pow(p, 0.92).toDouble();

    final double topSurfaceY = 72.0 - topRem * 54.0;
    final double funnelDepth = (isRunning && topRem > 0.04)
        ? math.min(9.0, topRem * 11.0)
        : 0.0;

    final double lowerEdgeY = 138.0 - botAcc * 30.0;
    final double lowerCrestY = 138.0 - botAcc * 46.0;

    final Paint sandPaint = Paint()..color = palette.accentSolar;

    if (topRem > 0.002) {
      canvas.save();
      canvas.clipPath(upperBulb);
      final Path topSand = Path()
        ..moveTo(4, topSurfaceY)
        ..quadraticBezierTo(48, topSurfaceY + funnelDepth, 92, topSurfaceY)
        ..lineTo(92, 73)
        ..lineTo(4, 73)
        ..close();
      canvas.drawPath(topSand, sandPaint);
      canvas.restore();
    }

    if (isRunning && p < 0.998 && topRem > 0.002) {
      final Paint streamPaint = Paint()
        ..color = palette.accentPrimary
        ..strokeWidth = 2.0;
      for (
        double y = 72.0 + (dashPhase % 5.0);
        y < math.max(73.0, lowerCrestY + 2.0);
        y += 5.0
      ) {
        canvas.drawLine(
          Offset(48, y),
          Offset(48, math.min(y + 3.0, lowerCrestY + 2.0)),
          streamPaint,
        );
      }
    }

    if (botAcc > 0.002) {
      canvas.save();
      canvas.clipPath(lowerBulb);
      final Path botSand = Path()
        ..moveTo(4, lowerEdgeY)
        ..quadraticBezierTo(48, lowerCrestY, 92, lowerEdgeY)
        ..lineTo(92, 140)
        ..lineTo(4, 140)
        ..close();
      canvas.drawPath(botSand, sandPaint);
      canvas.restore();
    }

    for (final g in particles) {
      canvas.drawCircle(
        Offset(g.x, g.y),
        g.radius,
        Paint()..color = g.color.withValues(alpha: g.alpha.clamp(0.0, 1.0)),
      );
    }

    canvas.drawPath(upperBulb, glassStroke);
    canvas.drawPath(lowerBulb, glassStroke);

    final Paint capPaint = Paint()..color = palette.strokeSubtle;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 0, 88, 6),
        const Radius.circular(3),
      ),
      capPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 138, 88, 6),
        const Radius.circular(3),
      ),
      capPaint,
    );
  }

  @override
  bool shouldRepaint(covariant HourglassVesselPainter oldDelegate) => true;
}
