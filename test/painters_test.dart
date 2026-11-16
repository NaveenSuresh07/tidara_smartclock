import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_dial_painter.dart';
import 'package:tidara_smartclock/features/focus_timer/sculptural_hourglass_widget.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/features/smart_alarm/sunrise_arc_dial.dart';
import 'package:tidara_smartclock/features/world_clock/armillary_globe_widget.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pDark = TidaraPalette(isDark: true);
  final pLight = TidaraPalette(isDark: false);
  final pDarkContrast = TidaraPalette(isDark: true, highContrast: true);
  const size = Size(300, 300);

  group('Chronometer Painters — Painting & Lifecycle Caching', () {
    test('StaticChronometerDialRingPainter paints without errors', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = StaticChronometerDialRingPainter(palette: pDark);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('DynamicChronometerSweepHandPainter paints without errors', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = DynamicChronometerSweepHandPainter(
        elapsedMs: 15420,
        palette: pDark,
      );

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('ChronometerDialPainter paints and caches properly', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter1 = ChronometerDialPainter(elapsedMs: 5000, palette: pDark);
      final painter2 = ChronometerDialPainter(elapsedMs: 5000, palette: pDark);
      final painterDiffTime = ChronometerDialPainter(
        elapsedMs: 6000,
        palette: pDark,
      );
      final painterDiffTheme = ChronometerDialPainter(
        elapsedMs: 5000,
        palette: pLight,
      );

      expect(() => painter1.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painterDiffTime), isTrue);
      expect(painter1.shouldRepaint(painterDiffTheme), isTrue);
    });

    test('Static & Dynamic Chronometer shouldRepaint branches', () {
      final static1 = StaticChronometerDialRingPainter(palette: pDark);
      final staticSame = StaticChronometerDialRingPainter(palette: pDark);
      final staticContrast = StaticChronometerDialRingPainter(
        palette: pDarkContrast,
      );
      final staticLight = StaticChronometerDialRingPainter(palette: pLight);

      expect(static1.shouldRepaint(staticSame), isFalse);
      expect(static1.shouldRepaint(staticContrast), isTrue);
      expect(static1.shouldRepaint(staticLight), isTrue);

      final dynamic1 = DynamicChronometerSweepHandPainter(
        elapsedMs: 100,
        palette: pDark,
      );
      final dynamicSame = DynamicChronometerSweepHandPainter(
        elapsedMs: 100,
        palette: pDark,
      );
      final dynamicTime = DynamicChronometerSweepHandPainter(
        elapsedMs: 200,
        palette: pDark,
      );
      final dynamicTheme = DynamicChronometerSweepHandPainter(
        elapsedMs: 100,
        palette: pLight,
      );

      expect(dynamic1.shouldRepaint(dynamicSame), isFalse);
      expect(dynamic1.shouldRepaint(dynamicTime), isTrue);
      expect(dynamic1.shouldRepaint(dynamicTheme), isTrue);
    });
  });

  group('Sunrise Arc Painters — Painting & Lifecycle Caching', () {
    test('StaticSunriseArcDialPainter paints without errors', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = StaticSunriseArcDialPainter(palette: pDark);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('DynamicSunriseBeadPainter paints without errors', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = DynamicSunriseBeadPainter(
        normalizedProgress: 0.72,
        palette: pDark,
      );

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('SunriseArcPainter paints and caches properly', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter1 = SunriseArcPainter(
        normalizedProgress: 0.5,
        palette: pDark,
      );
      final painter2 = SunriseArcPainter(
        normalizedProgress: 0.5,
        palette: pDark,
      );
      final painterDiffProg = SunriseArcPainter(
        normalizedProgress: 0.6,
        palette: pDark,
      );
      final painterDiffTheme = SunriseArcPainter(
        normalizedProgress: 0.5,
        palette: pLight,
      );

      expect(() => painter1.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painterDiffProg), isTrue);
      expect(painter1.shouldRepaint(painterDiffTheme), isTrue);
    });

    test('Static & Dynamic SunriseArc shouldRepaint branches', () {
      final static1 = StaticSunriseArcDialPainter(palette: pDark);
      final staticSame = StaticSunriseArcDialPainter(palette: pDark);
      final staticContrast = StaticSunriseArcDialPainter(
        palette: pDarkContrast,
      );
      final staticLight = StaticSunriseArcDialPainter(palette: pLight);

      expect(static1.shouldRepaint(staticSame), isFalse);
      expect(static1.shouldRepaint(staticContrast), isTrue);
      expect(static1.shouldRepaint(staticLight), isTrue);

      final dynamic1 = DynamicSunriseBeadPainter(
        normalizedProgress: 0.3,
        palette: pDark,
      );
      final dynamicSame = DynamicSunriseBeadPainter(
        normalizedProgress: 0.3,
        palette: pDark,
      );
      final dynamicProg = DynamicSunriseBeadPainter(
        normalizedProgress: 0.4,
        palette: pDark,
      );
      final dynamicTheme = DynamicSunriseBeadPainter(
        normalizedProgress: 0.3,
        palette: pLight,
      );

      expect(dynamic1.shouldRepaint(dynamicSame), isFalse);
      expect(dynamic1.shouldRepaint(dynamicProg), isTrue);
      expect(dynamic1.shouldRepaint(dynamicTheme), isTrue);
    });
  });

  group('Armillary Globe Painters — Painting & Lifecycle Caching', () {
    final city1 = kWorldCities[0];
    final city2 = kWorldCities[1];

    test('StaticArmillaryCelestialFramePainter paints and caches properly', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painterDark = StaticArmillaryCelestialFramePainter(isDark: true);
      final painterDarkSame = StaticArmillaryCelestialFramePainter(
        isDark: true,
      );
      final painterLight = StaticArmillaryCelestialFramePainter(isDark: false);

      expect(() => painterDark.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();

      expect(painterDark.shouldRepaint(painterDarkSame), isFalse);
      expect(painterDark.shouldRepaint(painterLight), isTrue);
    });

    test(
      'DynamicArmillaryGlobePainter paints and caches properly across all parameters',
      () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter1 = DynamicArmillaryGlobePainter(
          rotationY: 0.5,
          selectedCity: city1,
          sunAngleRad: 1.2,
          moonAngleRad: 3.4,
          isDark: true,
        );

        expect(() => painter1.paint(canvas, size), returnsNormally);
        final picture = recorder.endRecording();
        picture.dispose();

        final painterSame = DynamicArmillaryGlobePainter(
          rotationY: 0.5,
          selectedCity: city1,
          sunAngleRad: 1.2,
          moonAngleRad: 3.4,
          isDark: true,
        );
        final painterDiffRot = DynamicArmillaryGlobePainter(
          rotationY: 0.8,
          selectedCity: city1,
          sunAngleRad: 1.2,
          moonAngleRad: 3.4,
          isDark: true,
        );
        final painterDiffCity = DynamicArmillaryGlobePainter(
          rotationY: 0.5,
          selectedCity: city2,
          sunAngleRad: 1.2,
          moonAngleRad: 3.4,
          isDark: true,
        );
        final painterDiffSun = DynamicArmillaryGlobePainter(
          rotationY: 0.5,
          selectedCity: city1,
          sunAngleRad: 2.0,
          moonAngleRad: 3.4,
          isDark: true,
        );
        final painterDiffMoon = DynamicArmillaryGlobePainter(
          rotationY: 0.5,
          selectedCity: city1,
          sunAngleRad: 1.2,
          moonAngleRad: 4.0,
          isDark: true,
        );
        final painterDiffTheme = DynamicArmillaryGlobePainter(
          rotationY: 0.5,
          selectedCity: city1,
          sunAngleRad: 1.2,
          moonAngleRad: 3.4,
          isDark: false,
        );

        expect(painter1.shouldRepaint(painterSame), isFalse);
        expect(painter1.shouldRepaint(painterDiffRot), isTrue);
        expect(painter1.shouldRepaint(painterDiffCity), isTrue);
        expect(painter1.shouldRepaint(painterDiffSun), isTrue);
        expect(painter1.shouldRepaint(painterDiffMoon), isTrue);
        expect(painter1.shouldRepaint(painterDiffTheme), isTrue);
      },
    );

    test('ArmillaryGlobePainter paints and caches correctly', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter1 = ArmillaryGlobePainter(
        rotationY: 0.0,
        selectedCity: city1,
        sunAngleRad: 0.5,
        moonAngleRad: 2.5,
        isDark: true,
      );

      expect(() => painter1.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();

      final painterSame = ArmillaryGlobePainter(
        rotationY: 0.0,
        selectedCity: city1,
        sunAngleRad: 0.5,
        moonAngleRad: 2.5,
        isDark: true,
      );
      final painterDiff = ArmillaryGlobePainter(
        rotationY: 0.1,
        selectedCity: city1,
        sunAngleRad: 0.5,
        moonAngleRad: 2.5,
        isDark: true,
      );

      expect(painter1.shouldRepaint(painterSame), isFalse);
      expect(painter1.shouldRepaint(painterDiff), isTrue);
    });
  });

  group('DashedRRectPainter & HourglassVesselPainter — Behavioural Tests', () {
    test('DashedRRectPainter paints and checks shouldRepaint branches', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const painter = DashedRRectPainter(
        color: Colors.cyan,
        radius: 12.0,
        strokeWidth: 2.0,
        dashWidth: 6.0,
        dashSpace: 4.0,
      );

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();

      const same = DashedRRectPainter(
        color: Colors.cyan,
        radius: 12.0,
        strokeWidth: 2.0,
        dashWidth: 6.0,
        dashSpace: 4.0,
      );
      const diffColor = DashedRRectPainter(
        color: Colors.red,
        radius: 12.0,
        strokeWidth: 2.0,
      );
      const diffRadius = DashedRRectPainter(
        color: Colors.cyan,
        radius: 16.0,
        strokeWidth: 2.0,
      );
      const diffStroke = DashedRRectPainter(
        color: Colors.cyan,
        radius: 12.0,
        strokeWidth: 3.0,
      );

      expect(painter.shouldRepaint(same), isFalse);
      expect(painter.shouldRepaint(diffColor), isTrue);
      expect(painter.shouldRepaint(diffRadius), isTrue);
      expect(painter.shouldRepaint(diffStroke), isTrue);
    });

    test(
      'HourglassVesselPainter paints across top, streaming, and accumulated states',
      () {
        // 1. Initial full top state (progress = 0.0, stationary)
        final rec1 = ui.PictureRecorder();
        final canvas1 = Canvas(rec1);
        final painterTop = HourglassVesselPainter(
          progress: 0.0,
          isRunning: false,
          particles: const [],
          dashPhase: 0.0,
          palette: pDark,
        );
        expect(() => painterTop.paint(canvas1, size), returnsNormally);
        rec1.endRecording().dispose();

        // 2. Mid-flow streaming state with animated stream & particles (light palette)
        final rec2 = ui.PictureRecorder();
        final canvas2 = Canvas(rec2);
        final particles = [
          SandGrainParticle(
            x: 48,
            y: 90,
            vx: 0.2,
            vy: 1.5,
            radius: 1.5,
            color: Colors.amber,
          )..alpha = 0.8,
          SandGrainParticle(
            x: 50,
            y: 110,
            vx: -0.1,
            vy: 2.0,
            radius: 2.0,
            color: Colors.orange,
          )..alpha = 0.6,
        ];
        final painterStreaming = HourglassVesselPainter(
          progress: 0.5,
          isRunning: true,
          particles: particles,
          dashPhase: 2.5,
          palette: pLight,
        );
        expect(() => painterStreaming.paint(canvas2, size), returnsNormally);
        rec2.endRecording().dispose();

        // 3. Complete bottom-accumulated state (progress = 1.0, stationary)
        final rec3 = ui.PictureRecorder();
        final canvas3 = Canvas(rec3);
        final painterBottom = HourglassVesselPainter(
          progress: 1.0,
          isRunning: false,
          particles: const [],
          dashPhase: 0.0,
          palette: pDark,
        );
        expect(() => painterBottom.paint(canvas3, size), returnsNormally);
        rec3.endRecording().dispose();

        expect(painterTop.shouldRepaint(painterStreaming), isTrue);
      },
    );
  });
}
