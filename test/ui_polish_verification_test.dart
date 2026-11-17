import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_tab.dart';
import 'package:tidara_smartclock/features/focus_timer/focus_timer_tab.dart';
import 'package:tidara_smartclock/features/shared/custom_audio_selection_sheet.dart';
import 'package:tidara_smartclock/features/shell/settings_modal.dart';
import 'package:tidara_smartclock/features/shell/top_status_bar.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/features/smart_alarm/tactile_alarm_sheets.dart';
import 'package:tidara_smartclock/features/world_clock/world_clock_tab.dart';
import 'package:tidara_smartclock/models/horological_models.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCity = kWorldCities.firstWhere((c) => c.name == 'Bengaluru');
  final testEphem = CircadianEphemeris.compute(
    rawLat: testCity.lat,
    rawLon: testCity.lon,
    utcNow: DateTime.utc(2026, 6, 21, 6, 0),
    cityOffsetMinutes: testCity.stdOffsetMinutes,
  );

  double lumChannel(double c) {
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  double relLum(Color color) {
    return 0.2126 * lumChannel(color.r) +
        0.7152 * lumChannel(color.g) +
        0.0722 * lumChannel(color.b);
  }

  Color compositeOver(Color fg, Color bg) {
    final a = fg.a;
    return Color.from(
      alpha: 1.0,
      red: fg.r * a + bg.r * (1.0 - a),
      green: fg.g * a + bg.g * (1.0 - a),
      blue: fg.b * a + bg.b * (1.0 - a),
    );
  }

  double calcContrast(Color c1, Color c2) {
    final l1 = relLum(c1);
    final l2 = relLum(c2);
    final hi = math.max(l1, l2);
    final lo = math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.tidara.smartclock/native_bridge'),
          (MethodCall call) async {
            if (call.method == 'listDeviceAudio') {
              return [
                {
                  'name': 'Temple_Dawn.wav',
                  'path': '/storage/emulated/0/Music/Temple_Dawn.wav',
                },
              ];
            }
            return null;
          },
        );
  });

  // ==========================================================================
  // 1. ICON CENTERING TESTS
  // ==========================================================================
  group('UI Polish Verification - 1. Icon Centering Tests', () {
    void assertCircularButtonsCentered(
      WidgetTester tester, {
      required String screenName,
    }) {
      final buttonFinders = find.byWidgetPredicate((w) {
        if (w is GlassButton) {
          return w.isCircle || w.variant == GlassButtonVariant.iconOnly;
        }
        return false;
      });

      expect(
        buttonFinders,
        findsWidgets,
        reason: 'Screen $screenName should have circular/icon buttons',
      );

      for (final element in buttonFinders.evaluate()) {
        final buttonWidget = element.widget as GlassButton;
        final iconFinder = find.descendant(
          of: find.byWidget(buttonWidget),
          matching: find.byType(Icon),
        );

        if (iconFinder.evaluate().isNotEmpty) {
          final buttonRect = tester.getRect(find.byWidget(buttonWidget));
          final iconRect = tester.getRect(iconFinder.first);
          final distance = (buttonRect.center - iconRect.center).distance;

          expect(
            distance,
            lessThanOrEqualTo(1.0),
            reason:
                'Icon in circular button "${buttonWidget.semanticLabel ?? "unlabeled"}" '
                'on $screenName must be centered. Button center: ${buttonRect.center}, '
                'Icon center: ${iconRect.center}, distance: $distance',
          );
        }
      }
    }

    testWidgets(
      'Alarms & Rhythms: circular buttons are centered (dial -, +, delete)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        const palette = TidaraPalette(isDark: false);
        const testAlarm = AlarmRhythm(
          id: 'alarm_test_1',
          title: 'Morning Awakening',
          wakeMinutes24: 360,
          enabled: true,
          weekdays: ['mon', 'tue', 'wed'],
          soundMeta: '432Hz Tibetan Singing Bowl',
          useCustomAudio: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: testEphem,
                alarmHomeCity: testCity,
                wakeMinutes: 360,
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
        await tester.pumpAndSettle();

        assertCircularButtonsCentered(tester, screenName: 'SmartAlarmTab');
      },
    );

    testWidgets(
      'Focus & Sand Timer: circular buttons are centered (tune, reset)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        const palette = TidaraPalette(isDark: false);
        final remainingNotifier = ValueNotifier<double>(1440.0);
        final progressNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusTimerTab(
                palette: palette,
                activePresetId: '24m',
                customTotalSec: null,
                focusRunning: false,
                completedGhatikas: 0,
                hourglassFlipCount: 0,
                activeSoundscapeId: 'bowl',
                customMusicName: null,
                focusProgressNotifier: progressNotifier,
                focusRemainingSecNotifier: remainingNotifier,
                effectiveFocusTotalSec: 1440,
                onToggleFocus: () {},
                onManualHourglassFlip: () {},
                onSelectPreset: (_) {},
                onChangeSoundscape: (_) {},
                onPromptCustomDuration: () {},
                onBrowseAudio: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        assertCircularButtonsCentered(tester, screenName: 'FocusTimerTab');
      },
    );

    testWidgets('TopStatusBar & SettingsModal: circular buttons are centered', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      final nowNotifier = ValueNotifier<DateTime>(DateTime.now());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TopStatusBar(
                  palette: palette,
                  nowNotifier: nowNotifier,
                  use24HourFormat: false,
                  activeTabIndex: 0,
                  isChronoRunning: false,
                  isFocusRunning: false,
                  themePreference: 'light',
                  isMuted: false,
                  showSettingsModal: true,
                  onSelectTab: (_) {},
                  onToggleTheme: () {},
                  onToggleMute: () {},
                  onToggleSettings: () {},
                ),
                SettingsAndGlossaryModal(
                  palette: palette,
                  alarmEphem: testEphem,
                  alarmHomeCity: testCity,
                  use24HourFormat: false,
                  highContrastMode: false,
                  onOpenSecurityDiagnostics: () {},
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
      await tester.pumpAndSettle();

      assertCircularButtonsCentered(
        tester,
        screenName: 'TopStatusBar & SettingsModal',
      );
    });

    testWidgets('Sound Selection Sheet: circular play buttons are centered', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        showCustomAudioSelectionSheet(ctx, palette: palette),
                    child: const Text('Open Sound Sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sound Sheet'));
      await tester.pumpAndSettle();

      assertCircularButtonsCentered(
        tester,
        screenName: 'CustomAudioSelectionSheet',
      );
    });
  });

  // ==========================================================================
  // 2. CONTRAST RATIO TESTS (WCAG AA >= 4.5:1)
  // ==========================================================================
  group('UI Polish Verification - 2. Contrast Ratio Tests', () {
    test('Token contrast verification for Light and Dark modes', () {
      const lightBg = Color(0xFFF4F0E8);
      const darkBg = Color(0xFF14110F);

      // Light Neutral Glass
      final lightNeutralFill = compositeOver(
        const Color(0xFFE8E2D5).withValues(alpha: 0.65),
        lightBg,
      );
      const lightNeutralText = Color(0xFF1C1917);
      expect(
        calcContrast(lightNeutralText, lightNeutralFill),
        greaterThanOrEqualTo(4.5),
        reason: 'Light neutral glass text must meet WCAG AA >= 4.5:1',
      );

      // Dark Neutral Glass
      final darkNeutralFill = compositeOver(
        const Color(0xFF2C2623).withValues(alpha: 0.70),
        darkBg,
      );
      const darkNeutralText = Color(0xFFF4F0E8);
      expect(
        calcContrast(darkNeutralText, darkNeutralFill),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark neutral glass text must meet WCAG AA >= 4.5:1',
      );

      // Light Primary / Accent Button
      final lightPrimaryFill = compositeOver(
        const Color(0xFFC24C27).withValues(alpha: 0.96),
        lightBg,
      );
      const lightPrimaryText = Color(0xFFFFFFFF);
      expect(
        calcContrast(lightPrimaryText, lightPrimaryFill),
        greaterThanOrEqualTo(4.5),
        reason: 'Light primary accent button must meet WCAG AA >= 4.5:1',
      );

      // Dark Primary / Accent Button
      final darkPrimaryFill = compositeOver(
        const Color(0xFFC24C27).withValues(alpha: 0.90),
        darkBg,
      );
      const darkPrimaryText = Color(0xFFFFFFFF);
      expect(
        calcContrast(darkPrimaryText, darkPrimaryFill),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark primary accent button must meet WCAG AA >= 4.5:1',
      );

      // High Emphasis Pill (Light)
      final lightPillFill = compositeOver(
        const Color(0xFF1C1917).withValues(alpha: 0.92),
        lightBg,
      );
      const lightPillText = Color(0xFFF4F0E8);
      expect(
        calcContrast(lightPillText, lightPillFill),
        greaterThanOrEqualTo(4.5),
        reason: 'Light high-emphasis pill must meet WCAG AA >= 4.5:1',
      );

      // High Emphasis Pill (Dark)
      final darkPillFill = compositeOver(
        const Color(0xFFF4F0E8).withValues(alpha: 0.92),
        darkBg,
      );
      const darkPillText = Color(0xFF14110F);
      expect(
        calcContrast(darkPillText, darkPillFill),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark high-emphasis pill must meet WCAG AA >= 4.5:1',
      );

      // Unselected Preset Chip (Dark)
      final darkChipFill = compositeOver(
        const Color(0xFF2A2421).withValues(alpha: 0.85),
        darkBg,
      );
      const darkChipText = Color(0xFFF4F0E8);
      expect(
        calcContrast(darkChipText, darkChipFill),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark unselected preset chip must meet WCAG AA >= 4.5:1',
      );
    });

    testWidgets(
      'Live mounted GlassButton variants achieve >= 4.5:1 contrast in Light and Dark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        for (final isDark in [false, true]) {
          final themeMode = isDark ? 'Dark' : 'Light';
          final bgSurface = isDark
              ? const Color(0xFF14110F)
              : const Color(0xFFF4F0E8);

          final testVariants = <Map<String, dynamic>>[
            {
              'name': 'Primary Accent ($themeMode)',
              'button': GlassButton.primary(label: 'Save', onPressed: () {}),
            },
            {
              'name': 'Secondary Neutral ($themeMode)',
              'button': GlassButton.secondary(
                label: 'Cancel',
                onPressed: () {},
              ),
            },
            {
              'name': 'Destructive ($themeMode)',
              'button': GlassButton.destructive(
                label: 'Delete',
                onPressed: () {},
              ),
            },
            {
              'name': 'High Emphasis Pill ($themeMode)',
              'button': GlassButton.highEmphasisPill(
                label: 'Start Focus',
                onPressed: () {},
              ),
            },
            {
              'name': 'Unselected Chip ($themeMode)',
              'button': GlassButton.chip(
                label: '25m',
                isSelected: false,
                onPressed: () {},
              ),
            },
            {
              'name': 'Selected Chip ($themeMode)',
              'button': GlassButton.chip(
                label: '24m',
                isSelected: true,
                onPressed: () {},
              ),
            },
            {
              'name': 'Icon-Only Neutral ($themeMode)',
              'button': GlassButton.iconOnly(
                icon: Icons.close,
                semanticLabel: 'Close',
                onPressed: () {},
              ),
            },
          ];

          for (final variant in testVariants) {
            await tester.pumpWidget(
              MaterialApp(
                theme: isDark ? ThemeData.dark() : ThemeData.light(),
                home: Scaffold(
                  backgroundColor: bgSurface,
                  body: Center(child: variant['button'] as Widget),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final textStyleWidget = tester.widget<DefaultTextStyle>(
              find
                  .descendant(
                    of: find.byType(GlassButton),
                    matching: find.byType(DefaultTextStyle),
                  )
                  .first,
            );
            final iconThemeWidget = tester.widget<IconTheme>(
              find
                  .descendant(
                    of: find.byType(GlassButton),
                    matching: find.byType(IconTheme),
                  )
                  .first,
            );

            final Color fgColor =
                textStyleWidget.style.color ??
                iconThemeWidget.data.color ??
                Colors.black;

            final containerFinder = find.descendant(
              of: find.byType(GlassButton),
              matching: find.byType(Container),
            );
            final container = tester.widget<Container>(containerFinder.first);
            final decoration = container.decoration as BoxDecoration;

            Color effectiveFill;
            if (decoration.color != null) {
              effectiveFill = compositeOver(decoration.color!, bgSurface);
            } else if (decoration.gradient is LinearGradient) {
              final grad = decoration.gradient! as LinearGradient;
              final topC = grad.colors.first;
              effectiveFill = compositeOver(topC, bgSurface);
            } else {
              effectiveFill = bgSurface;
            }

            final double contrast = calcContrast(fgColor, effectiveFill);
            expect(
              contrast,
              greaterThanOrEqualTo(4.5),
              reason:
                  '${variant['name']} must meet WCAG AA >= 4.5:1 (got $contrast:1 for fg: $fgColor over fill: $effectiveFill)',
            );
          }
        }
      },
    );
  });

  // ==========================================================================
  // 3. BANNED JARGON TESTS
  // ==========================================================================
  group('Plain-Language Terminology Compliance Tests', () {
    const bannedTerms = [
      'Circadian',
      'Arm ',
      '+ Arm',
      'Dawn Rhythm',
      'Solar Focus',
      'Astronomical',
    ];

    void assertNoBannedTerms(
      WidgetTester tester, {
      required String screenName,
    }) {
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final content =
            textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        for (final term in bannedTerms) {
          expect(
            content.contains(term),
            isFalse,
            reason:
                'Found banned term "$term" on screen $screenName in text: "$content"',
          );
        }
      }
    }

    testWidgets('Alarms & Rhythms: No banned jargon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      const testAlarm = AlarmRhythm(
        id: 'alarm_test_1',
        title: 'Morning Awakening',
        wakeMinutes24: 360,
        enabled: true,
        weekdays: ['mon', 'tue', 'wed'],
        soundMeta: '432Hz Tibetan Singing Bowl',
        useCustomAudio: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartAlarmTab(
              palette: palette,
              alarmEphem: testEphem,
              alarmHomeCity: testCity,
              wakeMinutes: 360,
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
      await tester.pumpAndSettle();

      assertNoBannedTerms(tester, screenName: 'SmartAlarmTab');
    });

    testWidgets('Focus & Sand Timer: No banned jargon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      final remainingNotifier = ValueNotifier<double>(1440.0);
      final progressNotifier = ValueNotifier<double>(0.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTimerTab(
              palette: palette,
              activePresetId: '24m',
              customTotalSec: null,
              focusRunning: false,
              completedGhatikas: 0,
              hourglassFlipCount: 0,
              activeSoundscapeId: 'bowl',
              customMusicName: null,
              focusProgressNotifier: progressNotifier,
              focusRemainingSecNotifier: remainingNotifier,
              effectiveFocusTotalSec: 1440,
              onToggleFocus: () {},
              onManualHourglassFlip: () {},
              onSelectPreset: (_) {},
              onChangeSoundscape: (_) {},
              onPromptCustomDuration: () {},
              onBrowseAudio: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      assertNoBannedTerms(tester, screenName: 'FocusTimerTab');
    });

    testWidgets('Chronometer: No banned jargon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      final elapsedNotifier = ValueNotifier<int>(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChronometerTab(
              palette: palette,
              chronoElapsedMsNotifier: elapsedNotifier,
              isRunning: false,
              laps: const [],
              onToggleChrono: () {},
              onLapOrReset: () {},
              onResetChrono: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      assertNoBannedTerms(tester, screenName: 'ChronometerTab');
    });

    testWidgets('World Clock: No banned jargon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);
      final nowNotifier = ValueNotifier<DateTime>(
        DateTime.utc(2026, 6, 21, 12, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldClockTab(
              palette: palette,
              ephem: testEphem,
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

      assertNoBannedTerms(tester, screenName: 'WorldClockTab');
    });

    testWidgets('Settings & Guide Sheet: No banned jargon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SettingsAndGlossaryModal(
                  palette: palette,
                  alarmEphem: testEphem,
                  alarmHomeCity: testCity,
                  use24HourFormat: false,
                  highContrastMode: false,
                  onOpenSecurityDiagnostics: () {},
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
      await tester.pumpAndSettle();

      assertNoBannedTerms(tester, screenName: 'SettingsAndGlossaryModal');
    });

    testWidgets('Tactile Alarm Bottom Sheet: No banned jargon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      const palette = TidaraPalette(isDark: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TactileAlarmBottomSheet(
              palette: palette,
              defaultWakeMinutes: 330,
              sunriseMinutesFromMidnight: testEphem.sunriseLocalMinutes,
              sunsetMinutesFromMidnight: testEphem.sunsetLocalMinutes,
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
      await tester.pumpAndSettle();

      assertNoBannedTerms(tester, screenName: 'TactileAlarmBottomSheet');
    });
  });
}
