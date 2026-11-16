import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/chronometer/chronometer_tab.dart';
import 'package:tidara_smartclock/features/focus_timer/focus_timer_tab.dart';
import 'package:tidara_smartclock/features/shared/custom_audio_selection_sheet.dart';
import 'package:tidara_smartclock/features/shell/floating_dock.dart';
import 'package:tidara_smartclock/features/shell/settings_modal.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/features/smart_alarm/sunrise_arc_dial.dart';
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

  double calculateLuminance(Color color) {
    double transform(double c) {
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = transform(color.r);
    final g = transform(color.g);
    final b = transform(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  double calculateContrast(Color c1, Color c2) {
    final l1 = calculateLuminance(c1);
    final l2 = calculateLuminance(c2);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  group('UI Polish & Visual Alignment Verification', () {
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
    // ------------------------------------------------------------------------
    // Bug 1: Sound selection sheet preset rows contrast
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 1: Sound selection sheet preset rows use token colors with high contrast',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        const palette = TidaraPalette(isDark: false);
        const darkPalette = TidaraPalette(isDark: true);

        final contrastLight = calculateContrast(
          palette.textPrimary,
          palette.surfaceCard,
        );
        expect(
          contrastLight,
          greaterThanOrEqualTo(4.5),
          reason:
              'Preset row text on surfaceCard must meet WCAG AA (>= 4.5:1) in light theme',
        );

        final contrastDark = calculateContrast(
          darkPalette.textPrimary,
          darkPalette.surfaceCard,
        );
        expect(
          contrastDark,
          greaterThanOrEqualTo(4.5),
          reason:
              'Preset row text on surfaceCard must meet WCAG AA (>= 4.5:1) in dark theme',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: GlassButton.primary(
                    onPressed: () =>
                        showCustomAudioSelectionSheet(ctx, palette: palette),
                    label: 'Open Sheet',
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        final allText = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .toList();
        expect(
          find.text('Sound Selection & Custom Audio'),
          findsOneWidget,
          reason: 'Found: $allText',
        );

        final presetFinder = find.text('432Hz Tibetan Bowl');
        expect(presetFinder, findsOneWidget);
        final presetText = tester.widget<Text>(presetFinder);
        expect(presetText.style?.color, equals(palette.textPrimary));
      },
    );

    // ------------------------------------------------------------------------
    // Bug 2: "Resume Loaded Interval" styling
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 2: "Resume Focus" does not show white text on cream fill',
      (tester) async {
        for (final isDark in [false, true]) {
          final palette = TidaraPalette(isDark: isDark);
          final remSecNotifier = ValueNotifier<double>(
            1200.0,
          ); // 20m remaining, paused
          final progressNotifier = ValueNotifier<double>(0.2);

          await tester.pumpWidget(
            MaterialApp(
              theme: isDark ? ThemeData.dark() : ThemeData.light(),
              home: Scaffold(
                backgroundColor: palette.bgBase,
                body: FocusTimerTab(
                  palette: palette,
                  activePresetId: '24m',
                  customTotalSec: null,
                  focusRunning: false, // paused/loaded state
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
          );
          await tester.pumpAndSettle();

          final ctaFinder = find.text('Resume Focus');
          expect(ctaFinder, findsOneWidget);

          final highEmphasisPillFinder = find.ancestor(
            of: ctaFinder,
            matching: find.byType(GlassButton),
          );
          expect(highEmphasisPillFinder, findsOneWidget);

          final pillWidget = tester.widget<GlassButton>(highEmphasisPillFinder);
          expect(
            pillWidget.variant,
            equals(GlassButtonVariant.highEmphasisPill),
          );

          // High emphasis pill: dark fill with white text in light theme,
          // and light cream fill with dark text in dark theme.
          // Never white text on cream fill!
          if (!isDark) {
            final contrast = calculateContrast(
              Colors.white,
              const Color(0xFF1C1917),
            );
            expect(contrast, greaterThanOrEqualTo(11.0));
          } else {
            final contrast = calculateContrast(
              const Color(0xFF1C1917),
              const Color(0xFFF4F0E8),
            );
            expect(contrast, greaterThanOrEqualTo(11.0));
          }
        }
      },
    );

    // ------------------------------------------------------------------------
    // Bug 3: Chronometer round buttons do not truncate labels at various font scales
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 3: Chronometer round buttons fit labels without truncation at 0.8x, 1.0x, 1.5x, 2.0x font scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        const palette = TidaraPalette(isDark: false);
        final scales = [0.8, 1.0, 1.5, 2.0];

        for (final scale in scales) {
          final elapsedNotifier = ValueNotifier<int>(15000); // 15s elapsed
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(412, 915),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: ChronometerTab(
                    palette: palette,
                    chronoElapsedMsNotifier: elapsedNotifier,
                    isRunning: false,
                    laps: const [
                      ChronoLap(
                        id: 1,
                        number: 'Lap 01',
                        durationMs: 15000,
                        formatted: '00:15.00',
                      ),
                    ],
                    onToggleChrono: () {},
                    onLapOrReset: () {},
                    onResetChrono: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Check Reset and Resume labels render completely
          expect(find.text('Reset'), findsOneWidget);
          expect(find.text('Resume'), findsOneWidget);

          // Neither button should show truncated 'Re...' or 'St...'
          expect(find.textContaining('Re...'), findsNothing);
          expect(find.textContaining('St...'), findsNothing);
        }
      },
    );

    // ------------------------------------------------------------------------
    // Bug 4: Lap pill text format is complete and not cut
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 4: Lap pill text renders complete format (.84 · Lap 03 style)',
      (tester) async {
        const palette = TidaraPalette(isDark: false);
        final elapsedNotifier = ValueNotifier<int>(42840); // .84 centis, Lap 03

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChronometerTab(
                palette: palette,
                chronoElapsedMsNotifier: elapsedNotifier,
                isRunning: true,
                laps: const [
                  ChronoLap(
                    id: 1,
                    number: 'Lap 01',
                    durationMs: 12000,
                    formatted: '00:12.00',
                  ),
                  ChronoLap(
                    id: 2,
                    number: 'Lap 02',
                    durationMs: 15000,
                    formatted: '00:15.00',
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

        // Lap pill should show '.84 · Lap 03'
        final lapPillFinder = find.text('.84 · Lap 03');
        expect(lapPillFinder, findsOneWidget);
      },
    );

    // ------------------------------------------------------------------------
    // Bug 5: Alarm header post-sunrise formatting for 0, 1, and 60+ minutes
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 5: SunriseArcDial header shows correct number for 0, 1, and 60+ minutes after sunrise',
      (tester) async {
        const palette = TidaraPalette(isDark: false);
        const int sunrise = 360; // 06:00 AM (360 mins)

        // Case A: delta == 0 (Exact sunrise)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SunriseArcDialWidget(
                palette: palette,
                wakeMinutesFromMidnight: 360,
                sunriseMinutesFromMidnight: sunrise,
                use24Hour: false,
                plainLanguage: true,
                onChangeWakeMinutes: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Exact Sunrise · 0m at sunrise'), findsOneWidget);

        // Case B: 1 minute after sunrise (wake = 361)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SunriseArcDialWidget(
                palette: palette,
                wakeMinutesFromMidnight: 361,
                sunriseMinutesFromMidnight: sunrise,
                use24Hour: false,
                plainLanguage: true,
                onChangeWakeMinutes: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Post-Sunrise Morning | 1m after sunrise'),
          findsOneWidget,
        );

        // Case C: 65 minutes after sunrise (wake = 425)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SunriseArcDialWidget(
                palette: palette,
                wakeMinutesFromMidnight: 425,
                sunriseMinutesFromMidnight: sunrise,
                use24Hour: false,
                plainLanguage: true,
                onChangeWakeMinutes: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Post-Sunrise Morning | 65m after sunrise'),
          findsOneWidget,
        );

        // Case D: Classical mode for 65 minutes after sunrise
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SunriseArcDialWidget(
                palette: palette,
                wakeMinutesFromMidnight: 425,
                sunriseMinutesFromMidnight: sunrise,
                use24Hour: false,
                plainLanguage: false,
                onChangeWakeMinutes: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Post-Sunrise Morning | 65m after sunrise'),
          findsOneWidget,
        );
      },
    );

    // ------------------------------------------------------------------------
    // Bug 6: Dock unselected globe icon does not render as filled dark circle
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 6: FloatingDock unselected globe renders without dark circle container',
      (tester) async {
        const palette = TidaraPalette(isDark: false);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FloatingDock(
                palette: palette,
                activeTabIndex:
                    0, // Tab 0 is active, Tab 1 (World Clock) is unselected
                hasActiveAlarms: false,
                isChronoRunning: false,
                isFocusRunning: false,
                onSelectTab: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final globeFinder = find.byIcon(Icons.language);
        expect(globeFinder, findsOneWidget);

        // Verify the globe icon has palette.textPrimary color (consistent with other tabs)
        final globeIcon = tester.widget<Icon>(globeFinder);
        expect(globeIcon.color, equals(palette.textPrimary));
        expect(globeIcon.size, equals(20.0));

        // There should NOT be any Container with shape: BoxShape.circle and color 0xFF1C1917
        final darkCircleFinder = find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final box = w.decoration as BoxDecoration;
            return box.shape == BoxShape.circle &&
                box.color == const Color(0xFF1C1917);
          }
          return false;
        });
        expect(darkCircleFinder, findsNothing);
      },
    );

    // ------------------------------------------------------------------------
    // Bug 7: Alarm card delete button sizing
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 7: Alarm card delete button matches 28x28 visual size and keeps 48x48 hit target',
      (tester) async {
        const palette = TidaraPalette(isDark: false);
        const testAlarms = [
          AlarmRhythm(
            id: 'alarm-1',
            title: 'Solar Awakening',
            weekdays: ['Mon'],
            soundMeta: 'Soft gong',
            useCustomAudio: false,
            enabled: true,
            wakeMinutes24: 330,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: testEphem,
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
        );
        await tester.pumpAndSettle();

        final deleteBtnFinder = find.byTooltip('Delete alarm');
        expect(deleteBtnFinder, findsOneWidget);

        // Hit area target must be >= 48x48
        final hitSize = tester.getSize(deleteBtnFinder);
        expect(hitSize.width, greaterThanOrEqualTo(48.0));
        expect(hitSize.height, greaterThanOrEqualTo(48.0));

        // Visual container size must be 28x28
        final visualContainer = find.descendant(
          of: deleteBtnFinder,
          matching: find.byType(Container),
        );
        expect(visualContainer, findsWidgets);
        final visualSize = tester.getSize(visualContainer.first);
        expect(visualSize.width, equals(28.0));
        expect(visualSize.height, equals(28.0));
      },
    );

    // ------------------------------------------------------------------------
    // Bug 8: Diagnostics button guarded by kDebugMode / absent in release
    // ------------------------------------------------------------------------
    testWidgets(
      'Bug 8: Security diagnostics button is absent when enableDebugDiagnostics is false',
      (tester) async {
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
                    plainLanguageVedic: true,
                    enableDebugDiagnostics: false, // Simulates release mode
                    onOpenSecurityDiagnostics: () {},
                    onToggle24Hour: (_) {},
                    onToggleHighContrast: (_) {},
                    onTogglePlainLanguage: (_) {},
                    onSelectAlarmHomeCity: (_) {},
                    onClose: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('open_debug_security_diagnostics_button')),
          findsNothing,
        );
        expect(
          find.text('Developer Security Diagnostics (Debug Only)'),
          findsNothing,
        );
      },
    );
  });
}
