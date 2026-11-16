import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_tab.dart';
import 'package:tidara_smartclock/features/focus_timer/focus_timer_tab.dart';
import 'package:tidara_smartclock/features/shell/dawn_awakening_overlay.dart';
import 'package:tidara_smartclock/features/shell/floating_dock.dart';
import 'package:tidara_smartclock/features/shell/top_status_bar.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/features/world_clock/world_clock_tab.dart';
import 'package:tidara_smartclock/models/horological_models.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCity = kWorldCities.firstWhere((c) => c.name == 'Bengaluru');
  final ephem = CircadianEphemeris.compute(
    rawLat: testCity.lat,
    rawLon: testCity.lon,
    utcNow: DateTime.utc(2026, 6, 21, 6, 0),
    cityOffsetMinutes: testCity.stdOffsetMinutes,
  );

  const testAlarm = AlarmRhythm(
    id: 'alarm-test-1',
    title: 'Solar Awakening',
    weekdays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    soundMeta: 'Soft gong | 15m gradual dawn light',
    useCustomAudio: false,
    enabled: true,
    wakeMinutes24: 330,
  );

  for (final isDark in [false, true]) {
    final themeName = isDark ? 'Dark Theme' : 'Light Theme';
    final palette = TidaraPalette(isDark: isDark);

    group('Layout Snapshot — $themeName', () {
      testWidgets('SmartAlarmTab button dimensions, radius and typography', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 330,
                alarms: const [testAlarm],
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
        );
        await tester.pumpAndSettle();

        // 1. Delete Alarm IconButton
        final deleteFinder = find.byTooltip('Delete alarm');
        expect(deleteFinder, findsOneWidget);
        final deleteSize = tester.getSize(deleteFinder);
        expect(deleteSize.width, greaterThanOrEqualTo(40.0));
        expect(deleteSize.height, greaterThanOrEqualTo(40.0));

        // 2. Add Custom Alarm Button (Dashed RRect)
        final addCustomFinder = find.text('Add Custom Alarm');
        expect(addCustomFinder, findsOneWidget);
        final addCustomText = tester.widget<Text>(addCustomFinder);
        expect(addCustomText.style?.fontSize, 12.5);
        expect(addCustomText.style?.fontWeight, FontWeight.w600);

        final addCustomContainer = find.ancestor(
          of: addCustomFinder,
          matching: find.byType(Container),
        );
        expect(addCustomContainer, findsWidgets);
        final addCustomSize = tester.getSize(addCustomContainer.first);
        expect(addCustomSize.height, equals(48.0));
        expect(addCustomSize.width, greaterThan(300.0));

        // 3. Optimal Sleep Window Card
        final sleepCardFinder = find.text('Optimal Sleep Window');
        expect(sleepCardFinder, findsOneWidget);
        final sleepCardText = tester.widget<Text>(sleepCardFinder);
        expect(sleepCardText.style?.fontWeight, FontWeight.w600);

        // 4. Arm Dawn Rhythm Button when no alarms present
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 330,
                alarms: const [], // empty alarms to show Arm CTA
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
        );
        await tester.pumpAndSettle();

        final armTextFinder = find.textContaining('Set ');
        expect(armTextFinder, findsOneWidget);
        final armBtnFinder = find.ancestor(
          of: armTextFinder,
          matching: find.byWidgetPredicate(
            (w) => w is ElevatedButton || w is GlassButton,
          ),
        );
        expect(armBtnFinder, findsOneWidget);
        final armSize = tester.getSize(armBtnFinder);
        expect(armSize.height, greaterThanOrEqualTo(36.0));
        expect(armSize.width, greaterThan(180.0));
      });

      testWidgets('ChronometerTab button dimensions, radius and typography', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final elapsedNotifier = ValueNotifier<int>(42180);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: ChronometerTab(
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
        );
        await tester.pumpAndSettle();

        // 1. Reset 00:00 Chip
        final resetChipFinder = find.text('Reset 00:00');
        expect(resetChipFinder, findsOneWidget);
        final resetChipText = tester.widget<Text>(resetChipFinder);
        expect(resetChipText.style?.fontSize, 11.5);
        expect(resetChipText.style?.fontWeight, FontWeight.w600);

        // 2. Lap / Reset 72x72 Circular Button
        final lapBtnTextFinder = find.text('Reset');
        expect(lapBtnTextFinder, findsOneWidget);
        final lapBtnContainer = find.ancestor(
          of: lapBtnTextFinder,
          matching: find.byType(Container),
        );
        expect(lapBtnContainer, findsWidgets);
        final lapSize = tester.getSize(lapBtnContainer.first);
        expect(lapSize.width, equals(72.0));
        expect(lapSize.height, equals(72.0));

        // 3. Start / Resume 72x72 Circular Button
        final startBtnTextFinder = find.text('Resume');
        expect(startBtnTextFinder, findsOneWidget);
        final startBtnContainer = find.ancestor(
          of: startBtnTextFinder,
          matching: find.byType(Container),
        );
        expect(startBtnContainer, findsWidgets);
        final startSize = tester.getSize(startBtnContainer.first);
        expect(startSize.width, equals(72.0));
        expect(startSize.height, equals(72.0));

        // Verify typography on circular buttons
        final startText = tester.widget<Text>(startBtnTextFinder);
        expect(startText.style?.fontSize, 13.0);
        expect(startText.style?.fontWeight, FontWeight.w600);
      });

      testWidgets('FocusTimerTab button dimensions, radius and typography', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final remSecNotifier = ValueNotifier<double>(1440.0);
        final progressNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: FocusTimerTab(
                palette: palette,
                activePresetId: '24m',
                customTotalSec: null,
                focusRunning: true,
                completedGhatikas: 0,
                hourglassFlipCount: 0,
                activeSoundscapeId: 'cedar',
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
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Tune Button (Custom Duration 32x32)
        final tuneFinder = find.byIcon(Icons.tune_rounded);
        expect(tuneFinder, findsOneWidget);
        final tuneContainer = find.ancestor(
          of: tuneFinder,
          matching: find.byType(Container),
        );
        expect(tuneContainer, findsWidgets);
        final tuneSize = tester.getSize(tuneContainer.first);
        expect(tuneSize.width, equals(32.0));
        expect(tuneSize.height, equals(32.0));

        // 2. Flip Button (Reset Hourglass 32x32)
        final flipFinder = find.byIcon(Icons.replay);
        expect(flipFinder, findsOneWidget);
        final flipContainer = find.ancestor(
          of: flipFinder,
          matching: find.byType(Container),
        );
        expect(flipContainer, findsWidgets);
        final flipSize = tester.getSize(flipContainer.first);
        expect(flipSize.width, equals(32.0));
        expect(flipSize.height, equals(32.0));

        // 3. Preset chips (12m, 24m, 48m, etc.)
        final chip24Finder = find.text('24m (Focus)');
        expect(chip24Finder, findsOneWidget);
        final chip24Text = tester.widget<Text>(chip24Finder);
        expect(chip24Text.style?.fontSize, 12.0);
        expect(chip24Text.style?.fontWeight, FontWeight.w600);

        final chip12Finder = find.text('12m');
        expect(chip12Finder, findsOneWidget);
        final chip12Text = tester.widget<Text>(chip12Finder);
        expect(chip12Text.style?.fontSize, 12.0);

        // 4. CTA Button (Start Focus / Pause / Resume Focus)
        final ctaFinder = find.text('Pause');
        expect(ctaFinder, findsOneWidget);
        final ctaElevated = find.ancestor(
          of: ctaFinder,
          matching: find.byWidgetPredicate(
            (w) => w is ElevatedButton || w is GlassButton,
          ),
        );
        expect(ctaElevated, findsOneWidget);
        final ctaSize = tester.getSize(ctaElevated);
        expect(ctaSize.height, equals(52.0));
        expect(ctaSize.width, greaterThan(300.0));

        final ctaTextWidget = tester.widget<Text>(ctaFinder);
        expect(ctaTextWidget.style?.fontSize, 14.0);
        expect(ctaTextWidget.style?.fontWeight, FontWeight.w600);

        // 5. Soundscape Row Browse Button
        final browseFinder = find.text('Browse');
        expect(browseFinder, findsOneWidget);
        final browseText = tester.widget<Text>(browseFinder);
        expect(browseText.style?.fontSize, 11.0);
        expect(browseText.style?.fontWeight, FontWeight.w600);

        // 6. Soundscape Row Change Button
        final changeFinder = find.text('Change');
        expect(changeFinder, findsOneWidget);
        final changeText = tester.widget<Text>(changeFinder);
        expect(changeText.style?.fontSize, 12.0);
        expect(changeText.style?.fontWeight, FontWeight.w600);
      });

      testWidgets('WorldClockTab button dimensions, radius and typography', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final nowNotifier = ValueNotifier<DateTime>(
          DateTime.utc(2026, 6, 21, 12, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: WorldClockTab(
                palette: palette,
                ephem: ephem,
                selectedCity: testCity,
                pinnedCityIds: const ['city_london', 'city_tokyo'],
                nowNotifier: nowNotifier,
                use24HourFormat: false,
                onSelectCity: (_) {},
                onTogglePinCity: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Search Bar Field / Container
        final searchBarFinder = find.byType(TextField);
        expect(searchBarFinder, findsOneWidget);

        // 2. Online Open-Meteo Search Button
        final onlineSearchFinder = find.byTooltip(
          'Search any world city online (Open-Meteo)',
        );
        expect(onlineSearchFinder, findsOneWidget);
        final searchIconSize = tester.getSize(onlineSearchFinder);
        expect(searchIconSize.width, greaterThanOrEqualTo(32.0));
        expect(searchIconSize.height, greaterThanOrEqualTo(32.0));
      });

      testWidgets('TopStatusBar and FloatingDock controls', (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final nowNotifier = ValueNotifier<DateTime>(
          DateTime.utc(2026, 6, 21, 12, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  TopStatusBar(
                    palette: palette,
                    nowNotifier: nowNotifier,
                    use24HourFormat: false,
                    activeTabIndex: 0,
                    isChronoRunning: true,
                    isFocusRunning: true,
                    isMuted: false,
                    themePreference: 'light',
                    showSettingsModal: false,
                    onSelectTab: (_) {},
                    onToggleTheme: () {},
                    onToggleMute: () {},
                    onToggleSettings: () {},
                  ),
                  const Spacer(),
                  FloatingDock(
                    palette: palette,
                    activeTabIndex: 0,
                    hasActiveAlarms: true,
                    isChronoRunning: false,
                    isFocusRunning: false,
                    onSelectTab: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top Status Bar: Theme, Mute, Settings IconButtons
        expect(find.byTooltip('Switch Theme (LIGHT)'), findsOneWidget);
        expect(
          find.byTooltip('Mute UI/Ambient (Alarms still ring)'),
          findsOneWidget,
        );
        expect(
          find.byTooltip('Settings, Permissions & Vedic Guide'),
          findsOneWidget,
        );

        // Chrono and Focus chips in TopStatusBar
        final chronoChipFinder = find.text(' Chrono');
        expect(chronoChipFinder, findsOneWidget);
        final focusChipFinder = find.text(' Focus');
        expect(focusChipFinder, findsOneWidget);

        // FloatingDock dimensions
        final dockFinder = find.byType(FloatingDock);
        expect(dockFinder, findsOneWidget);
        final dockContainer = find.descendant(
          of: dockFinder,
          matching: find.byType(Container),
        );
        expect(dockContainer, findsWidgets);
        final dockSize = tester.getSize(dockContainer.first);
        expect(dockSize.width, equals(280.0));
        expect(dockSize.height, equals(64.0));
      });

      testWidgets('DawnAwakeningOverlay action buttons', (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final nowNotifier = ValueNotifier<DateTime>(
          DateTime.utc(2026, 6, 21, 5, 30),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: Stack(
                children: [
                  DawnAwakeningOverlay(
                    palette: palette,
                    ringingAlarm: const {
                      'time': '05:30 AM',
                      'title': 'Solar Awakening',
                      'soundMeta': 'Singing bowl & gradual swell',
                      'isPreview': false,
                    },
                    nowNotifier: nowNotifier,
                    onDismiss: ({required snoozeMinutes}) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Snooze Button
        final snoozeFinder = find.text('Snooze 12 minutes');
        expect(snoozeFinder, findsOneWidget);

        // 2. Dismiss Button
        final dismissFinder = find.text('Dismiss Alarm');
        expect(dismissFinder, findsOneWidget);
      });
    });
  }
}
