import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_tab.dart';
import 'package:tidara_smartclock/features/focus_timer/focus_timer_tab.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/features/world_clock/world_clock_tab.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCity = kWorldCities.firstWhere((c) => c.name == 'Bengaluru');
  final ephem = CircadianEphemeris.compute(
    rawLat: testCity.lat,
    rawLon: testCity.lon,
    utcNow: DateTime.utc(2026, 6, 21, 6, 0),
    cityOffsetMinutes: testCity.stdOffsetMinutes,
  );

  const testAlarms = [
    AlarmRhythm(
      id: 'alarm-1',
      title: 'Solar Awakening',
      weekdays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      soundMeta: 'Soft gong | 15m gradual dawn light',
      useCustomAudio: false,
      enabled: true,
      wakeMinutes24: 330, // 05:30 AM
    ),
    AlarmRhythm(
      id: 'alarm-2',
      title: 'Pre-Dawn Meditation',
      weekdays: ['Every day'],
      soundMeta: 'Vedic Chants | Dynamic Volume',
      useCustomAudio: false,
      enabled: false,
      wakeMinutes24: 285, // 04:45 AM
    ),
  ];

  group('Screen Golden Tests (host platform: Windows)', () {
    testWidgets('Alarms & Rhythms - Light Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 330,
                alarms: testAlarms,
                use24HourFormat: false,
                plainLanguageVedic: false,
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
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/alarms_rhythms_light.png'),
      );
    });

    testWidgets('Alarms & Rhythms - Dark Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: true);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 330,
                alarms: testAlarms,
                use24HourFormat: false,
                plainLanguageVedic: false,
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
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/alarms_rhythms_dark.png'),
      );
    });

    testWidgets('World Clock - Light Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      final nowNotifier = ValueNotifier<DateTime>(
        DateTime.utc(2026, 6, 21, 11, 34), // 5:04 PM IST
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: WorldClockTab(
                palette: palette,
                ephem: ephem,
                selectedCity: testCity,
                pinnedCityIds: const ['tokyo', 'dubai'],
                customCities: const [],
                nowNotifier: nowNotifier,
                use24HourFormat: false,
                onSelectCity: (_) {},
                onTogglePinCity: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/world_clock_light.png'),
      );
    });

    testWidgets('World Clock - Dark Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: true);
      final nowNotifier = ValueNotifier<DateTime>(
        DateTime.utc(2026, 6, 21, 11, 34),
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: WorldClockTab(
                palette: palette,
                ephem: ephem,
                selectedCity: testCity,
                pinnedCityIds: const ['tokyo', 'dubai'],
                customCities: const [],
                nowNotifier: nowNotifier,
                use24HourFormat: false,
                onSelectCity: (_) {},
                onTogglePinCity: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/world_clock_dark.png'),
      );
    });

    testWidgets('Chronometer - Light Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      final elapsedNotifier = ValueNotifier<int>(42180);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ChronometerTab(
                  palette: palette,
                  chronoElapsedMsNotifier: elapsedNotifier,
                  isRunning: false,
                  laps: const [
                    ChronoLap(
                      id: 1,
                      number: 'Lap 01',
                      durationMs: 12000,
                      formatted: '00:12.00',
                    ),
                  ],
                  onToggleChrono: () {},
                  onLapOrReset: () {},
                  onResetChrono: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/chronometer_light.png'),
      );
    });

    testWidgets('Chronometer - Dark Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: true);
      final elapsedNotifier = ValueNotifier<int>(42180);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ChronometerTab(
                  palette: palette,
                  chronoElapsedMsNotifier: elapsedNotifier,
                  isRunning: false,
                  laps: const [
                    ChronoLap(
                      id: 1,
                      number: 'Lap 01',
                      durationMs: 12000,
                      formatted: '00:12.00',
                    ),
                  ],
                  onToggleChrono: () {},
                  onLapOrReset: () {},
                  onResetChrono: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/chronometer_dark.png'),
      );
    });

    testWidgets('Focus Timer - Light Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      final remSecNotifier = ValueNotifier<double>(1440.0);
      final progressNotifier = ValueNotifier<double>(0.0);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FocusTimerTab(
                  palette: palette,
                  activePresetId: '24m',
                  customTotalSec: null,
                  focusRunning: false,
                  completedGhatikas: 0,
                  hourglassFlipCount: 0,
                  activeSoundscapeId: 'bowl',
                  customMusicName: null,
                  focusProgressNotifier: progressNotifier,
                  focusRemainingSecNotifier: remSecNotifier,
                  effectiveFocusTotalSec: 1440,
                  onToggleFocus: () {},
                  onManualHourglassFlip: () {},
                  onSelectPreset: (_) {},
                  onPromptCustomDuration: () {},
                  onChangeSoundscape: (_) {},
                  onBrowseAudio: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/focus_timer_light.png'),
      );
    });

    testWidgets('Focus Timer - Dark Mode Golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: true);
      final remSecNotifier = ValueNotifier<double>(1440.0);
      final progressNotifier = ValueNotifier<double>(0.0);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FocusTimerTab(
                  palette: palette,
                  activePresetId: '24m',
                  customTotalSec: null,
                  focusRunning: false,
                  completedGhatikas: 0,
                  hourglassFlipCount: 0,
                  activeSoundscapeId: 'bowl',
                  customMusicName: null,
                  focusProgressNotifier: progressNotifier,
                  focusRemainingSecNotifier: remSecNotifier,
                  effectiveFocusTotalSec: 1440,
                  onToggleFocus: () {},
                  onManualHourglassFlip: () {},
                  onSelectPreset: (_) {},
                  onPromptCustomDuration: () {},
                  onChangeSoundscape: (_) {},
                  onBrowseAudio: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/screens/focus_timer_dark.png'),
      );
    });
  });
}
