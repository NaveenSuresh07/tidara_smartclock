import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_tab.dart';
import 'package:tidara_smartclock/features/focus_timer/focus_timer_tab.dart';
import 'package:tidara_smartclock/features/shell/dawn_awakening_overlay.dart';
import 'package:tidara_smartclock/features/shell/settings_modal.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/models/horological_models.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_dial_painter.dart';
import 'package:tidara_smartclock/features/smart_alarm/sunrise_arc_dial.dart';
import 'package:tidara_smartclock/features/world_clock/armillary_globe_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final palette = TidaraPalette(isDark: false);
  final testCity = kWorldCities.firstWhere((c) => c.name == 'Bengaluru');
  final ephem = CircadianEphemeris.compute(
    rawLat: testCity.lat,
    rawLon: testCity.lon,
    utcNow: DateTime.utc(2026, 6, 21, 6, 0),
    cityOffsetMinutes: testCity.stdOffsetMinutes,
  );

  group('SmartAlarmTab Widget Tests', () {
    testWidgets(
      'renders alarm list and exact alarm warning banner when disabled',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        bool openSettingsCalled = false;
        const testAlarm = AlarmRhythm(
          id: 'alarm-1',
          title: 'Dawn Awakening',
          weekdays: ['Mon', 'Tue'],
          soundMeta: 'Tibetan 432Hz',
          useCustomAudio: false,
          enabled: true,
          wakeMinutes24: 330,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 330,
                alarms: const [testAlarm],
                use24HourFormat: false,
                customMusicName: null,
                canScheduleExact: false, // warning banner shown
                onOpenExactAlarmSettings: () => openSettingsCalled = true,
                onWakeMinutesChanged: (_) {},
                onSaveAlarm: (_) {},
                onAddAlarm: (_) {},
                onDeleteAlarm: (_) {},
                onInsertAlarmAt: (_, __) {},
                onToggleAlarm: (_, __, ___) {},
                onTriggerDawnPreview:
                    ({
                      alarmId,
                      title,
                      time,
                      soundMeta,
                      useCustomAudio,
                      isPreview = false,
                    }) {},
                onSelectPhoneMusic: () async => null,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Alarms & Rhythms'), findsOneWidget);
        expect(
          find.text('Exact alarm permission required for precision wakeup.'),
          findsOneWidget,
        );
        expect(find.text('ENABLE'), findsOneWidget);
        expect(find.text('Dawn Awakening'), findsOneWidget);

        await tester.tap(find.text('ENABLE'));
        expect(openSettingsCalled, isTrue);
      },
    );
  });

  group('ChronometerTab Widget Tests', () {
    testWidgets('renders dials and triggers start, stop, lap, and reset', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final elapsedNotifier = ValueNotifier<int>(0);
      bool toggleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChronometerTab(
              palette: palette,
              chronoElapsedMsNotifier: elapsedNotifier,
              isRunning: false,
              laps: const [],
              onToggleChrono: () => toggleCalled = true,
              onLapOrReset: () {},
              onResetChrono: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chronometer'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);

      await tester.tap(find.text('Start'));
      expect(toggleCalled, isTrue);
    });
  });

  group('FocusTimerTab Widget Tests', () {
    testWidgets('renders sculptural hourglass and triggers presets', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final progressNotifier = ValueNotifier<double>(0.25);
      final remainingNotifier = ValueNotifier<double>(18 * 60.0);
      bool toggleCalled = false;
      bool flipCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTimerTab(
              palette: palette,
              activePresetId: '24m',
              customTotalSec: null,
              focusRunning: false,
              completedGhatikas: 2,
              hourglassFlipCount: 1,
              activeSoundscapeId: 'bowl',
              customMusicName: null,
              focusProgressNotifier: progressNotifier,
              focusRemainingSecNotifier: remainingNotifier,
              effectiveFocusTotalSec: 24 * 60,
              onToggleFocus: () => toggleCalled = true,
              onManualHourglassFlip: () => flipCalled = true,
              onSelectPreset: (_) {},
              onPromptCustomDuration: () {},
              onChangeSoundscape: (_) {},
              onBrowseAudio: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Focus & Sand Timer'), findsOneWidget);
      expect(find.text('Resume Focus'), findsOneWidget);

      await tester.tap(find.text('Resume Focus'));
      expect(toggleCalled, isTrue);

      await tester.tap(find.byIcon(Icons.replay));
      expect(flipCalled, isTrue);
    });
  });

  group('SettingsAndGlossaryModal Widget Tests', () {
    testWidgets('renders settings and triggers toggles', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      bool toggled24 = false;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SettingsAndGlossaryModal(
                  palette: palette,
                  alarmEphem: ephem,
                  alarmHomeCity: testCity,
                  use24HourFormat: false,
                  highContrastMode: false,
                  onToggle24Hour: (v) => toggled24 = v,
                  onToggleHighContrast: (_) {},
                  onSelectAlarmHomeCity: (_) {},
                  onClose: () => closed = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settings & Guide'), findsOneWidget);
      expect(find.text('24-Hour Time Format'), findsOneWidget);
      expect(find.text('Plain-Language Labels'), findsNothing);

      final switch24 = find.byType(Switch).first;
      await tester.tap(switch24);
      expect(toggled24, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });
  });

  group('DawnAwakeningOverlay Widget Tests', () {
    testWidgets('renders alarm overlay and triggers snooze/dismiss', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      int dismissedSnooze = -1;
      final nowNotifier = ValueNotifier<DateTime>(DateTime.now());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DawnAwakeningOverlay(
                  palette: palette,
                  ringingAlarm: const {
                    'title': 'Solar Dawn Call',
                    'time': '05:30 AM',
                    'soundMeta': 'Tibetan Bell 432Hz',
                  },
                  nowNotifier: nowNotifier,
                  onDismiss: ({required snoozeMinutes}) =>
                      dismissedSnooze = snoozeMinutes,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Solar Dawn Call'), findsOneWidget);
      expect(find.text('Dismiss Alarm'), findsOneWidget);
      expect(find.text('Snooze 12 minutes'), findsOneWidget);

      await tester.tap(find.text('Dismiss Alarm'));
      expect(dismissedSnooze, 0);
    });
  });
  group('Phase 9 — Pure Presentation & RepaintBoundary Architecture', () {
    testWidgets('SmartAlarmTab delegates alarm tap to onOpenAlarmSheet', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      AlarmRhythm? sheetAlarm;
      bool sheetOpened = false;

      const testAlarm = AlarmRhythm(
        id: 'alarm-arch-test',
        title: 'Architectural Review Alarm',
        weekdays: ['Mon', 'Fri'],
        soundMeta: 'Pure Sine 432Hz',
        useCustomAudio: false,
        enabled: true,
        wakeMinutes24: 360,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartAlarmTab(
              palette: palette,
              alarmEphem: ephem,
              alarmHomeCity: testCity,
              wakeMinutes: 360,
              alarms: const [testAlarm],
              use24HourFormat: true,
              customMusicName: null,
              onWakeMinutesChanged: (_) {},
              onSaveAlarm: (_) {},
              onAddAlarm: (_) {},
              onDeleteAlarm: (_) {},
              onInsertAlarmAt: (_, __) {},
              onToggleAlarm: (_, __, ___) {},
              onTriggerDawnPreview:
                  ({
                    alarmId,
                    title,
                    time,
                    soundMeta,
                    useCustomAudio,
                    isPreview = false,
                  }) {},
              onSelectPhoneMusic: () async => null,
              onOpenAlarmSheet: (ctx, {editingAlarm}) {
                sheetOpened = true;
                sheetAlarm = editingAlarm;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the alarm card
      await tester.tap(find.text('Architectural Review Alarm'));
      await tester.pumpAndSettle();

      expect(sheetOpened, isTrue);
      expect(sheetAlarm, isNotNull);
      expect(sheetAlarm!.id, 'alarm-arch-test');

      // Tap on the Add Custom button
      sheetOpened = false;
      sheetAlarm = null;
      await tester.tap(find.text('Add Custom Alarm'));
      await tester.pumpAndSettle();

      expect(sheetOpened, isTrue);
      expect(sheetAlarm, isNull);
    });

    testWidgets(
      'ChronometerTab isolates static dial ticks and sweep hand in RepaintBoundaries',
      (tester) async {
        final elapsedNotifier = ValueNotifier<int>(12500);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChronometerTab(
                palette: palette,
                chronoElapsedMsNotifier: elapsedNotifier,
                isRunning: true,
                laps: const [],
                onToggleChrono: () {},
                onLapOrReset: () {},
                onResetChrono: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify presence of isolated RepaintBoundary layers
        final repaintBoundaries = find.byType(RepaintBoundary);
        expect(repaintBoundaries, findsWidgets);

        // Verify CustomPaint uses separated painters
        final staticPainterFinder = find.byWidgetPredicate(
          (w) =>
              w is CustomPaint && w.painter is StaticChronometerDialRingPainter,
        );
        final dynamicPainterFinder = find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is DynamicChronometerSweepHandPainter,
        );

        expect(staticPainterFinder, findsOneWidget);
        expect(dynamicPainterFinder, findsOneWidget);
      },
    );

    testWidgets(
      'SunriseArcDialWidget isolates static arch and dynamic bead in RepaintBoundaries',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SunriseArcDialWidget(
                wakeMinutesFromMidnight: 330,
                sunriseMinutesFromMidnight: 360,
                palette: palette,
                use24Hour: true,
                onChangeWakeMinutes: (_) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final staticArcFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is StaticSunriseArcDialPainter,
        );
        final dynamicBeadFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DynamicSunriseBeadPainter,
        );

        expect(staticArcFinder, findsOneWidget);
        expect(dynamicBeadFinder, findsOneWidget);
      },
    );

    test('Painters properly implement shouldRepaint lifecycle caching', () {
      final pDark = TidaraPalette(isDark: true);
      final pLight = TidaraPalette(isDark: false);

      final staticRing1 = StaticChronometerDialRingPainter(palette: pDark);
      final staticRing2 = StaticChronometerDialRingPainter(palette: pDark);
      final staticRingDiff = StaticChronometerDialRingPainter(palette: pLight);

      expect(staticRing1.shouldRepaint(staticRing2), isFalse);
      expect(staticRing1.shouldRepaint(staticRingDiff), isTrue);

      final dynamicSweep1 = DynamicChronometerSweepHandPainter(
        elapsedMs: 1000,
        palette: pDark,
      );
      final dynamicSweep2 = DynamicChronometerSweepHandPainter(
        elapsedMs: 1000,
        palette: pDark,
      );
      final dynamicSweepTick = DynamicChronometerSweepHandPainter(
        elapsedMs: 1016,
        palette: pDark,
      );

      expect(dynamicSweep1.shouldRepaint(dynamicSweep2), isFalse);
      expect(dynamicSweep1.shouldRepaint(dynamicSweepTick), isTrue);

      final staticArc1 = StaticSunriseArcDialPainter(palette: pDark);
      final staticArc2 = StaticSunriseArcDialPainter(palette: pDark);
      expect(staticArc1.shouldRepaint(staticArc2), isFalse);

      final dynamicBead1 = DynamicSunriseBeadPainter(
        normalizedProgress: 0.5,
        palette: pDark,
      );
      final dynamicBead2 = DynamicSunriseBeadPainter(
        normalizedProgress: 0.5,
        palette: pDark,
      );
      final dynamicBeadScrubbed = DynamicSunriseBeadPainter(
        normalizedProgress: 0.6,
        palette: pDark,
      );
      expect(dynamicBead1.shouldRepaint(dynamicBead2), isFalse);
      expect(dynamicBead1.shouldRepaint(dynamicBeadScrubbed), isTrue);

      final staticGlobe1 = StaticArmillaryCelestialFramePainter(isDark: true);
      final staticGlobe2 = StaticArmillaryCelestialFramePainter(isDark: true);
      final staticGlobeDiff = StaticArmillaryCelestialFramePainter(
        isDark: false,
      );
      expect(staticGlobe1.shouldRepaint(staticGlobe2), isFalse);
      expect(staticGlobe1.shouldRepaint(staticGlobeDiff), isTrue);
    });
  });
}
