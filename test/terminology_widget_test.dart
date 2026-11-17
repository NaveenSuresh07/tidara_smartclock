import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_tab.dart';
import 'package:tidara_smartclock/features/focus_timer/focus_timer_tab.dart';
import 'package:tidara_smartclock/features/shared/custom_audio_selection_sheet.dart';
import 'package:tidara_smartclock/features/shell/dawn_awakening_overlay.dart';
import 'package:tidara_smartclock/features/shell/settings_modal.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/features/smart_alarm/tactile_alarm_sheets.dart';
import 'package:tidara_smartclock/features/world_clock/world_clock_tab.dart';
import 'package:tidara_smartclock/models/horological_models.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

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

  const List<String> forbiddenUiTerms = [
    'Ardha',
    'Pratah',
    'Yantra',
    'Brahma',
    'Ghatika',
    'VEDIC HOROLOGY GLOSSARY',
    'CIRCADIAN HOROLOGY GLOSSARY',
    'Settings & Vedic Guide',
    'Settings & Horological Guide',
    'Vedic Tanpura',
    'hardware-backed',
    'never leaves secure hardware',
    'StrongBox',
    'Secure Element',
    '100% unbreakable',
    'military grade',
  ];

  void assertNoForbiddenTerms(WidgetTester tester) {
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    for (final textWidget in textWidgets) {
      final rendered =
          textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
      for (final forbidden in forbiddenUiTerms) {
        expect(
          rendered.toLowerCase().contains(forbidden.toLowerCase()),
          isFalse,
          reason:
              'Rendered text contains forbidden term "$forbidden": "$rendered"',
        );
      }
    }
  }

  group('Plain-Language Terminology Compliance Tests', () {
    testWidgets(
      'SettingsAndGlossaryModal contains no archaic or forbidden terms',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

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

                    onToggle24Hour: (_) {},
                    onToggleHighContrast: (_) {},
                    onSelectAlarmHomeCity: (_) {},
                    onClose: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Settings & Guide'), findsOneWidget);
        expect(find.text('TIME & FOCUS GUIDE'), findsOneWidget);
        assertNoForbiddenTerms(tester);
      },
    );

    testWidgets(
      'TactileAlarmBottomSheet contains modernised circadian presets',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TactileAlarmBottomSheet(
                palette: palette,
                defaultWakeMinutes: 330,
                sunriseMinutesFromMidnight: ephem.sunriseLocalMinutes,
                sunsetMinutesFromMidnight: ephem.sunsetLocalMinutes,
                editingAlarm: null,
                customMusicName: null,
                onSelectPhoneMusic: () async => null,
                onSave: (_) {},
                onDelete: (_) {},
                onTriggerDawnPreview: (_) {},
              ),
            ),
          ),
        );

        // Verify modern horological presets are visible
        expect(find.text('Optimal Dawn Window'), findsOneWidget);
        expect(find.text('Dawn Awakening'), findsOneWidget);
        expect(find.text('Solar Sunrise'), findsOneWidget);
        expect(find.text('Dusk Reflection'), findsOneWidget);

        assertNoForbiddenTerms(tester);
      },
    );

    testWidgets('FocusTimerTab contains modern acoustic soundscape titles', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTimerTab(
              palette: palette,
              activePresetId: 'deep_flow',
              customTotalSec: 1500,
              focusRunning: false,
              completedGhatikas: 2,
              hourglassFlipCount: 0,
              activeSoundscapeId: 'tanpura',
              customMusicName: null,
              focusProgressNotifier: ValueNotifier<double>(0.5),
              focusRemainingSecNotifier: ValueNotifier<double>(750.0),
              effectiveFocusTotalSec: 1500,
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

      expect(find.text('Harmonic Tanpura & Monsoon Rain'), findsOneWidget);
      assertNoForbiddenTerms(tester);
    });

    testWidgets('SmartAlarmTab renders without forbidden terminology', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      const testAlarm = AlarmRhythm(
        id: 'alarm-test',
        title: 'Pre-Dawn Meditation',
        weekdays: ['Mon', 'Tue'],
        soundMeta: 'Soft gong',
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
              canScheduleExact: true,
              onOpenExactAlarmSettings: () {},
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

      expect(find.text('Pre-Dawn Meditation'), findsOneWidget);
      assertNoForbiddenTerms(tester);
    });

    testWidgets('WorldClockTab renders without forbidden terminology', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldClockTab(
              palette: palette,
              ephem: ephem,
              selectedCity: testCity,
              pinnedCityIds: [testCity.id],
              nowNotifier: ValueNotifier<DateTime>(DateTime(2026, 6, 21, 6, 0)),
              use24HourFormat: false,
              onSelectCity: (_) {},
              onTogglePinCity: (_) {},
            ),
          ),
        ),
      );

      assertNoForbiddenTerms(tester);
    });

    testWidgets(
      'DawnAwakeningOverlay renders with plain labels and no forbidden terminology',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  DawnAwakeningOverlay(
                    palette: palette,
                    nowNotifier: ValueNotifier<DateTime>(
                      DateTime(2026, 6, 21, 6, 0),
                    ),
                    ringingAlarm: const {
                      'id': 'alarm-1',
                      'title': 'Solar Awakening',
                      'time': '06:00 AM',
                      'soundMeta': 'Gentle Gong',
                    },
                    onDismiss: ({required int snoozeMinutes}) {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Snooze 12 minutes'), findsOneWidget);
        expect(find.text('Dismiss Alarm'), findsOneWidget);
        assertNoForbiddenTerms(tester);
      },
    );

    testWidgets(
      'CustomAudioSelectionSheet renders without forbidden terminology',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.tidara.smartclock/native_bridge'),
              (MethodCall call) async {
                if (call.method == 'listDeviceAudio') {
                  return [];
                }
                return null;
              },
            );

        await tester.binding.setSurfaceSize(const Size(412, 915));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => GlassButton.primary(
                  label: 'Open',
                  onPressed: () =>
                      showCustomAudioSelectionSheet(ctx, palette: palette),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        assertNoForbiddenTerms(tester);
      },
    );

    testWidgets('ChronometerTab renders without forbidden terminology', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChronometerTab(
              palette: palette,
              chronoElapsedMsNotifier: ValueNotifier<int>(65430),
              isRunning: false,
              laps: const [],
              onToggleChrono: () {},
              onLapOrReset: () {},
              onResetChrono: () {},
            ),
          ),
        ),
      );

      assertNoForbiddenTerms(tester);
    });
  });
}
