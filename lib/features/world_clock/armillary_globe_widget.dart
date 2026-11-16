import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../models/horological_models.dart';

// 3D Orthographic Armillary Globe Widget & CustomPainter
class ArmillaryGlobeWidget extends StatefulWidget {
  final WorldCity selectedCity;
  final ValueChanged<WorldCity> onSelectCity;
  final bool isCompact;
  final int solarMinutesOffset;
  final ValueChanged<int> onChangeSolarOffset;
  final int baseCityMinutes;
  final bool isDark;

  const ArmillaryGlobeWidget({
    super.key,
    required this.selectedCity,
    required this.onSelectCity,
    required this.isCompact,
    required this.solarMinutesOffset,
    required this.onChangeSolarOffset,
    required this.baseCityMinutes,
    required this.isDark,
  });

  @override
  State<ArmillaryGlobeWidget> createState() => _ArmillaryGlobeWidgetState();
}

class _ArmillaryGlobeWidgetState extends State<ArmillaryGlobeWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _globeTicker;
  late double _currentRotY;
  late double _slerpStartRotY;
  late double _slerpTargetRotY;
  int _slerpStartTimeMs = 0;
  bool _isSlerping = false;
  bool _isDraggingGlobe = false;
  String? _draggingCelestial; // 'sun' or 'moon'
  double _velocity = 0.0;

  double _targetRotForLon(double lon) => -lon * math.pi / 180.0;

  @override
  void initState() {
    super.initState();
    _currentRotY = _targetRotForLon(widget.selectedCity.lon);
    _slerpStartRotY = _currentRotY;
    _slerpTargetRotY = _currentRotY;

    _globeTicker = createTicker((_) {
      if (_isDraggingGlobe) return;
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_isSlerping) {
        final double t = ((nowMs - _slerpStartTimeMs) / 620.0).clamp(0.0, 1.0);
        final double eased = 1.0 - math.pow(1.0 - t, 4).toDouble();
        setState(() {
          _currentRotY =
              _slerpStartRotY + (_slerpTargetRotY - _slerpStartRotY) * eased;
          if (t >= 1.0) {
            _isSlerping = false;
            _globeTicker.stop();
          }
        });
      } else if (_velocity.abs() > 0.0003) {
        setState(() {
          _currentRotY += _velocity;
          _velocity *= 0.92;
          if (_velocity.abs() <= 0.0003) {
            _velocity = 0.0;
            _globeTicker.stop();
          }
        });
      } else {
        _globeTicker.stop();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ArmillaryGlobeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCity.id != widget.selectedCity.id) {
      _slerpStartRotY = _currentRotY;
      final double rawTarget = _targetRotForLon(widget.selectedCity.lon);
      final double diff = math.atan2(
        math.sin(rawTarget - _currentRotY),
        math.cos(rawTarget - _currentRotY),
      );
      _slerpTargetRotY = _currentRotY + diff;
      _slerpStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      _isSlerping = true;
      _velocity = 0.0;
      if (!_globeTicker.isActive) _globeTicker.start();
    }
  }

  @override
  void dispose() {
    _globeTicker.dispose();
    super.dispose();
  }

  List<double> _latLonTo3D(double lat, double lon, double rotY) {
    final double latRad = lat * math.pi / 180.0;
    final double lonRad = (lon * math.pi / 180.0) + rotY;
    final double x0 = math.cos(latRad) * math.sin(lonRad);
    final double y0 = math.sin(latRad);
    final double z0 = math.cos(latRad) * math.cos(lonRad);

    const double tilt = 12.5 * math.pi / 180.0;
    final double x = x0 * math.cos(tilt) - y0 * math.sin(tilt);
    final double y = x0 * math.sin(tilt) + y0 * math.cos(tilt);
    return [x, y, z0];
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.isCompact ? 220.0 : 284.0;
    final double globeRadius = size * (130.0 / 284.0);
    final Offset center = Offset(size / 2, size / 2);

    final int effectiveMins =
        ((widget.baseCityMinutes + widget.solarMinutesOffset) % 1440 + 1440) %
        1440;
    final double sunAngleRad =
        ((184.0 + ((effectiveMins - 1024) / 1440.0) * 360.0) *
            math.pi /
            180.0) +
        (_currentRotY - _targetRotForLon(widget.selectedCity.lon));
    final double moonAngleRad = sunAngleRad + (160.0 * math.pi / 180.0);

    final List<double> active3D = _latLonTo3D(
      widget.selectedCity.lat,
      widget.selectedCity.lon,
      _currentRotY,
    );
    final Offset? activeCityPos = active3D[2] >= 0.08
        ? Offset(
            center.dx + active3D[0] * globeRadius,
            center.dy - active3D[1] * globeRadius,
          )
        : null;

    return Semantics(
      label:
          'Interactive 3D Armillary Globe centered on ${widget.selectedCity.name}. Drag horizontally to rotate or tap a city pin.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final Offset tap = details.localPosition;
          WorldCity? nearest;
          double bestDist = 26.0;
          for (final city in kWorldCities) {
            final List<double> v = _latLonTo3D(
              city.lat,
              city.lon,
              _currentRotY,
            );
            if (v[2] < 0.12) continue;
            final Offset pt = Offset(
              center.dx + v[0] * globeRadius,
              center.dy - v[1] * globeRadius,
            );
            final double d = (tap - pt).distance;
            if (d < bestDist) {
              bestDist = d;
              nearest = city;
            }
          }
          if (nearest != null) {
            HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1260);
            widget.onSelectCity(nearest);
          }
        },
        onPanStart: (details) {
          final Offset pos = details.localPosition;
          final double orbitR = size / 2 - 2.0;
          final Offset sunPos = Offset(
            center.dx + orbitR * math.cos(sunAngleRad),
            center.dy + orbitR * math.sin(sunAngleRad),
          );
          final Offset moonPos = Offset(
            center.dx + orbitR * math.cos(moonAngleRad),
            center.dy + orbitR * math.sin(moonAngleRad),
          );

          if ((pos - sunPos).distance < 26.0) {
            _draggingCelestial = 'sun';
            return;
          }
          if ((pos - moonPos).distance < 26.0) {
            _draggingCelestial = 'moon';
            return;
          }

          _draggingCelestial = null;
          _isDraggingGlobe = true;
          _isSlerping = false;
          _velocity = 0.0;
          _globeTicker.stop();
        },
        onPanUpdate: (details) {
          if (_draggingCelestial != null) {
            final Offset d = details.localPosition - center;
            double deg = math.atan2(d.dy, d.dx) * 180.0 / math.pi;
            if (_draggingCelestial == 'moon') deg -= 160.0;
            final double targetMins = ((deg - 184.0) / 360.0) * 1440.0 + 1024.0;
            final int nextOff =
                (((targetMins - widget.baseCityMinutes) / 5.0).round() * 5);
            widget.onChangeSolarOffset(nextOff);
            return;
          }
          setState(() {
            _currentRotY += details.delta.dx * 0.012;
            _velocity = details.delta.dx * 0.006;
          });
        },
        onPanEnd: (details) {
          if (_draggingCelestial != null) {
            _draggingCelestial = null;
            return;
          }
          _isDraggingGlobe = false;
          final double vx = details.velocity.pixelsPerSecond.dx;
          _velocity = (vx * 0.000045).clamp(-0.08, 0.08);
          if (_velocity.abs() > 0.0003 && !_globeTicker.isActive) {
            _globeTicker.start();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: StaticArmillaryCelestialFramePainter(
                      isDark: widget.isDark,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: DynamicArmillaryGlobePainter(
                      rotationY: _currentRotY,
                      selectedCity: widget.selectedCity,
                      sunAngleRad: sunAngleRad,
                      moonAngleRad: moonAngleRad,
                      isDark: widget.isDark,
                    ),
                  ),
                ),
              ),
              if (activeCityPos != null)
                Positioned(
                  left: (activeCityPos.dx - 78.0).clamp(8.0, size - 168.0),
                  top: (activeCityPos.dy - 36.0).clamp(12.0, size - 42.0),
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF282420)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: widget.isDark
                            ? Border.all(color: const Color(0xFF3B352F))
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.selectedCity.name} | ${widget.selectedCity.tzCode} (GMT ${widget.selectedCity.gmtOffset})',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? const Color(0xFFF4F0E8)
                              : const Color(0xFF1C1917),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static outer celestial ring painter rasterized once on GPU and isolated in a [RepaintBoundary].
class StaticArmillaryCelestialFramePainter extends CustomPainter {
  final bool isDark;

  const StaticArmillaryCelestialFramePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double orbitRadius = size.width / 2 - 2.0;

    final Paint ringPaint = Paint()
      ..color = isDark ? const Color(0xFF332E2A) : const Color(0xFFD9D2C3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const int dashCount = 72;
    for (int i = 0; i < dashCount; i++) {
      final double startA = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: orbitRadius),
        startA,
        (math.pi / dashCount),
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant StaticArmillaryCelestialFramePainter oldDelegate,
  ) => oldDelegate.isDark != isDark;
}

/// Dynamic 3D orthographic globe painter handling rotating continents, graticule,
/// and orbital celestial sun/moon bodies.
class DynamicArmillaryGlobePainter extends CustomPainter {
  final double rotationY;
  final WorldCity selectedCity;
  final double sunAngleRad;
  final double moonAngleRad;
  final bool isDark;

  const DynamicArmillaryGlobePainter({
    required this.rotationY,
    required this.selectedCity,
    required this.sunAngleRad,
    required this.moonAngleRad,
    required this.isDark,
  });

  List<double> _latLonTo3D(double lat, double lon, double rotY) {
    final double latRad = lat * math.pi / 180.0;
    final double lonRad = (lon * math.pi / 180.0) + rotY;
    final double x0 = math.cos(latRad) * math.sin(lonRad);
    final double y0 = math.sin(latRad);
    final double z0 = math.cos(latRad) * math.cos(lonRad);

    const double tilt = 12.5 * math.pi / 180.0;
    final double x = x0 * math.cos(tilt) - y0 * math.sin(tilt);
    final double y = x0 * math.sin(tilt) + y0 * math.cos(tilt);
    return [x, y, z0];
  }

  List<List<double>> _clipPolygonToFrontHemisphere(List<List<double>> pts3D) {
    if (pts3D.isEmpty) return const [];
    final List<List<double>> out = [];
    for (int i = 0; i < pts3D.length; i++) {
      final List<double> cur = pts3D[i];
      final List<double> prev = pts3D[(i - 1 + pts3D.length) % pts3D.length];
      final bool curIn = cur[2] >= 0.0;
      final bool prevIn = prev[2] >= 0.0;

      if (curIn != prevIn) {
        final double t = prev[2] / (prev[2] - cur[2] + 1e-9);
        double ix = prev[0] + (cur[0] - prev[0]) * t;
        double iy = prev[1] + (cur[1] - prev[1]) * t;
        final double norm = math.sqrt(ix * ix + iy * iy);
        if (norm > 1e-6) {
          ix /= norm;
          iy /= norm;
        }
        out.add([ix, iy, 0.0]);
      }
      if (curIn) {
        out.add(cur);
      }
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double orbitRadius = size.width / 2 - 2.0;
    final double globeRadius = size.width * (130.0 / 284.0);

    // 2. Globe ocean sphere base
    canvas.save();
    final Path sphereClip = Path()
      ..addOval(Rect.fromCircle(center: center, radius: globeRadius));
    canvas.clipPath(sphereClip);

    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..color = isDark ? const Color(0xFF1B1815) : const Color(0xFFEFEBE1),
    );

    // 3. Graticule meridians & parallels
    final Paint graticulePaint = Paint()
      ..color = (isDark ? const Color(0xFF5C5346) : const Color(0xFFBAB2A2))
          .withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;

    for (int lon = -180; lon < 180; lon += 30) {
      final Path p = Path();
      bool started = false;
      for (int lat = -80; lat <= 80; lat += 8) {
        final List<double> v = _latLonTo3D(
          lat.toDouble(),
          lon.toDouble(),
          rotationY,
        );
        if (v[2] >= 0) {
          final Offset pt = Offset(
            center.dx + v[0] * globeRadius,
            center.dy - v[1] * globeRadius,
          );
          if (!started) {
            p.moveTo(pt.dx, pt.dy);
            started = true;
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        } else {
          started = false;
        }
      }
      canvas.drawPath(p, graticulePaint);
    }

    for (int lat = -60; lat <= 60; lat += 30) {
      final Path p = Path();
      bool started = false;
      for (int lon = -180; lon <= 180; lon += 8) {
        final List<double> v = _latLonTo3D(
          lat.toDouble(),
          lon.toDouble(),
          rotationY,
        );
        if (v[2] >= 0) {
          final Offset pt = Offset(
            center.dx + v[0] * globeRadius,
            center.dy - v[1] * globeRadius,
          );
          if (!started) {
            p.moveTo(pt.dx, pt.dy);
            started = true;
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        } else {
          started = false;
        }
      }
      canvas.drawPath(p, graticulePaint);
    }

    // 4. 3D Horizon-Clipped Continent Landmasses
    final Paint landFill = Paint()
      ..color = isDark ? const Color(0xFF2D2722) : const Color(0xFFD6CEBF)
      ..style = PaintingStyle.fill;
    final Paint landStroke = Paint()
      ..color = isDark ? const Color(0xFF4A4037) : const Color(0xFFC6BFA9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (final poly in kContinentPolygons) {
      final List<List<double>> dense3D = [];
      for (int i = 0; i < poly.length; i++) {
        final List<double> a = poly[i];
        final List<double> b = poly[(i + 1) % poly.length];
        const int steps = 4;
        for (int s = 0; s < steps; s++) {
          final double t = s / steps;
          final double lon = a[0] + (b[0] - a[0]) * t;
          final double lat = a[1] + (b[1] - a[1]) * t;
          dense3D.add(_latLonTo3D(lat, lon, rotationY));
        }
      }
      final List<List<double>> clipped = _clipPolygonToFrontHemisphere(dense3D);
      if (clipped.length >= 3) {
        final Path path = Path();
        for (int i = 0; i < clipped.length; i++) {
          final Offset pt = Offset(
            center.dx + clipped[i][0] * globeRadius,
            center.dy - clipped[i][1] * globeRadius,
          );
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, landFill);
        canvas.drawPath(path, landStroke);
      }
    }

    // 5. Day/Night Terminator Shading Overlay
    final Offset sunDir2D = Offset(
      math.cos(sunAngleRad),
      math.sin(sunAngleRad),
    );
    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..shader = ui.Gradient.linear(
          center + sunDir2D * globeRadius,
          center - sunDir2D * globeRadius,
          [
            Colors.transparent,
            const Color(0xFF1C1917).withValues(alpha: isDark ? 0.45 : 0.18),
          ],
        ),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      globeRadius,
      Paint()
        ..color = (isDark ? const Color(0xFF4A4037) : const Color(0xFFD9D2C3))
            .withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // 6. Front-hemisphere city pins & decluttered labels (Greedy Z-Depth Collision Avoidance)
    final List<Rect> occupiedLabelRects = [];

    final List<double> active3D = _latLonTo3D(
      selectedCity.lat,
      selectedCity.lon,
      rotationY,
    );
    if (active3D[2] >= 0.08) {
      final Offset activePt = Offset(
        center.dx + active3D[0] * globeRadius,
        center.dy - active3D[1] * globeRadius,
      );
      canvas.drawCircle(
        activePt,
        9.0,
        Paint()..color = const Color(0xFF4A6B53).withValues(alpha: 0.25),
      );
      canvas.drawCircle(activePt, 5.0, Paint()..color = Colors.white);
      canvas.drawCircle(
        activePt,
        2.8,
        Paint()..color = const Color(0xFF4A6B53),
      );

      occupiedLabelRects.add(
        Rect.fromCenter(center: activePt, width: 32, height: 24),
      );
      occupiedLabelRects.add(
        Rect.fromLTWH(activePt.dx - 78.0, activePt.dy - 40.0, 156.0, 28.0),
      );
    }

    final List<Map<String, dynamic>> visiblePassive = [];
    for (final city in kWorldCities) {
      if (city.id == selectedCity.id) continue;
      final List<double> v = _latLonTo3D(city.lat, city.lon, rotationY);
      if (v[2] < 0.12) continue;
      final Offset pt = Offset(
        center.dx + v[0] * globeRadius,
        center.dy - v[1] * globeRadius,
      );
      visiblePassive.add({'city': city, 'pt': pt, 'z': v[2]});
    }
    visiblePassive.sort(
      (a, b) => (b['z'] as double).compareTo(a['z'] as double),
    );

    for (final item in visiblePassive) {
      final WorldCity city = item['city'] as WorldCity;
      final Offset pt = item['pt'] as Offset;
      final double z = item['z'] as double;

      final double dotAlpha = ((z - 0.12) / 0.35).clamp(0.35, 1.0);
      canvas.drawCircle(
        pt,
        2.8,
        Paint()..color = const Color(0xFF8A8378).withValues(alpha: dotAlpha),
      );

      if (z <= 0.28) continue;

      final double textAlpha = ((z - 0.28) / 0.30).clamp(0.0, 1.0);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: city.name,
          style: TextStyle(
            fontSize: 9.0,
            fontWeight: FontWeight.w600,
            color: (isDark ? const Color(0xFFA8A096) : const Color(0xFF6B665E))
                .withValues(alpha: textAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bool placeLeft =
          pt.dx + 6.0 + tp.width > center.dx + globeRadius - 8.0;
      final Offset labelOffset = placeLeft
          ? Offset(pt.dx - 6.0 - tp.width, pt.dy - tp.height / 2)
          : Offset(pt.dx + 5.5, pt.dy - tp.height / 2);

      final Rect candidateRect = Rect.fromLTWH(
        labelOffset.dx - 3.0,
        labelOffset.dy - 2.0,
        tp.width + 6.0,
        tp.height + 4.0,
      );

      final bool hasCollision = occupiedLabelRects.any(
        (r) => r.overlaps(candidateRect),
      );
      if (!hasCollision) {
        occupiedLabelRects.add(candidateRect);
        tp.paint(canvas, labelOffset);
      }
    }

    // 7. Orbiting Sun & Moon nodes along the celestial equator ring
    final Offset sunCenter = Offset(
      center.dx + orbitRadius * math.cos(sunAngleRad),
      center.dy + orbitRadius * math.sin(sunAngleRad),
    );
    canvas.drawCircle(
      sunCenter,
      9.0,
      Paint()..color = const Color(0xFFE58A38).withValues(alpha: 0.32),
    );
    canvas.drawCircle(sunCenter, 6.0, Paint()..color = const Color(0xFFE58A38));
    canvas.drawCircle(
      sunCenter,
      6.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final Offset moonCenter = Offset(
      center.dx + orbitRadius * math.cos(moonAngleRad),
      center.dy + orbitRadius * math.sin(moonAngleRad),
    );
    canvas.drawCircle(
      moonCenter,
      5.0,
      Paint()..color = const Color(0xFF9CA3AF),
    );
    canvas.drawCircle(
      moonCenter,
      5.0,
      Paint()
        ..color = const Color(0xFFD9D2C3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant DynamicArmillaryGlobePainter oldDelegate) {
    return oldDelegate.rotationY != rotationY ||
        oldDelegate.selectedCity.id != selectedCity.id ||
        oldDelegate.sunAngleRad != sunAngleRad ||
        oldDelegate.moonAngleRad != moonAngleRad ||
        oldDelegate.isDark != isDark;
  }
}

/// Unified ArmillaryGlobePainter retained for backwards compatibility.
class ArmillaryGlobePainter extends CustomPainter {
  final double rotationY;
  final WorldCity selectedCity;
  final double sunAngleRad;
  final double moonAngleRad;
  final bool isDark;

  const ArmillaryGlobePainter({
    required this.rotationY,
    required this.selectedCity,
    required this.sunAngleRad,
    required this.moonAngleRad,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    StaticArmillaryCelestialFramePainter(isDark: isDark).paint(canvas, size);
    DynamicArmillaryGlobePainter(
      rotationY: rotationY,
      selectedCity: selectedCity,
      sunAngleRad: sunAngleRad,
      moonAngleRad: moonAngleRad,
      isDark: isDark,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant ArmillaryGlobePainter oldDelegate) {
    return oldDelegate.rotationY != rotationY ||
        oldDelegate.selectedCity.id != selectedCity.id ||
        oldDelegate.sunAngleRad != sunAngleRad ||
        oldDelegate.moonAngleRad != moonAngleRad ||
        oldDelegate.isDark != isDark;
  }
}
