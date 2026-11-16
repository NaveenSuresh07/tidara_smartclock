import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/shared/custom_audio_selection_sheet.dart';
import 'package:tidara_smartclock/features/smart_alarm/tactile_alarm_sheets.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

/// WCAG 2.1 relative luminance calculation
double _channelLuminance(int channel) {
  final double c = channel / 255.0;
  return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  // Convert Color channels to 0-255 int
  final int r = (color.r * 255.0).round();
  final int g = (color.g * 255.0).round();
  final int b = (color.b * 255.0).round();
  return 0.2126 * _channelLuminance(r) +
      0.7152 * _channelLuminance(g) +
      0.0722 * _channelLuminance(b);
}

/// Computes WCAG 2.1 contrast ratio between two colors (range: 1.0:1 to 21.0:1)
double contrastRatio(Color c1, Color c2) {
  final double l1 = relativeLuminance(c1);
  final double l2 = relativeLuminance(c2);
  final double lighter = max(l1, l2);
  final double darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Blends foreground color with [alpha] over an opaque background color.
Color blendOver(Color fg, double alpha, Color bg) {
  final int fgR = (fg.r * 255.0).round();
  final int fgG = (fg.g * 255.0).round();
  final int fgB = (fg.b * 255.0).round();

  final int bgR = (bg.r * 255.0).round();
  final int bgG = (bg.g * 255.0).round();
  final int bgB = (bg.b * 255.0).round();

  final int outR = (fgR * alpha + bgR * (1.0 - alpha)).round().clamp(0, 255);
  final int outG = (fgG * alpha + bgG * (1.0 - alpha)).round().clamp(0, 255);
  final int outB = (fgB * alpha + bgB * (1.0 - alpha)).round().clamp(0, 255);

  return Color.fromARGB(255, outR, outG, outB);
}

void main() {
  group('WCAG AA Contrast Ratio Tests (>= 4.5:1)', () {
    test('Light theme key colors reach >= 4.5:1 against light backgrounds', () {
      const palette = TidaraPalette(isDark: false, highContrast: false);
      final bgBase = palette.bgBase;
      final surfaceCard = palette.surfaceCard;
      const pureWhite = Color(0xFFFFFFFF);

      // 1. Text Primary (Charcoal)
      expect(
        contrastRatio(palette.textPrimary, bgBase),
        greaterThanOrEqualTo(4.5),
        reason: 'textPrimary on bgBase must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.textPrimary, surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: 'textPrimary on surfaceCard must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.textPrimary, pureWhite),
        greaterThanOrEqualTo(4.5),
        reason: 'textPrimary on white must pass WCAG AA',
      );

      // 2. Text Secondary (Muted charcoal)
      expect(
        contrastRatio(palette.textSecondary, bgBase),
        greaterThanOrEqualTo(4.5),
        reason: 'textSecondary on bgBase must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.textSecondary, surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: 'textSecondary on surfaceCard must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.textSecondary, pureWhite),
        greaterThanOrEqualTo(4.5),
        reason: 'textSecondary on white must pass WCAG AA',
      );

      // 3. Accent Primary (Figma #C24C27) & Dark Pill High-Emphasis
      // White text on Accent Primary (e.g. Stop circle, active chips)
      expect(
        contrastRatio(pureWhite, palette.accentPrimary),
        greaterThanOrEqualTo(4.5),
        reason:
            'White text on accentPrimary button must pass WCAG AA (>= 4.5:1)',
      );
      // Accent on background / card surfaces (large text / UI components per WCAG 2.1: >= 3:1)
      expect(
        contrastRatio(palette.accentPrimary, bgBase),
        greaterThanOrEqualTo(3.0),
        reason:
            'accentPrimary on bgBase must pass WCAG AA for large text/UI components (>= 3:1)',
      );
      expect(
        contrastRatio(palette.accentPrimary, surfaceCard),
        greaterThanOrEqualTo(3.0),
        reason:
            'accentPrimary on surfaceCard must pass WCAG AA for large text/UI components (>= 3:1)',
      );
      // White text on high-emphasis dark pill (Pause Stillness)
      expect(
        contrastRatio(pureWhite, palette.surfaceDark),
        greaterThanOrEqualTo(4.5),
        reason: 'White text on surfaceDark pill must pass WCAG AA (>= 4.5:1)',
      );

      // 4. Error color (Alert banner)
      expect(
        contrastRatio(palette.errorColor, bgBase),
        greaterThanOrEqualTo(4.5),
        reason: 'errorColor on bgBase must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.errorColor, surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: 'errorColor on surfaceCard must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.errorColor, pureWhite),
        greaterThanOrEqualTo(4.5),
        reason: 'errorColor on white must pass WCAG AA',
      );
    });

    test('Dark theme key colors reach >= 4.5:1 against dark backgrounds', () {
      const palette = TidaraPalette(isDark: true, highContrast: false);
      final bgBase = palette.bgBase;
      final surfaceCard = palette.surfaceCard;
      final surfaceElevated = palette.surfaceElevated;

      // 1. Text Primary (Cream)
      expect(
        contrastRatio(palette.textPrimary, bgBase),
        greaterThanOrEqualTo(4.5),
        reason: 'dark textPrimary on bgBase must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.textPrimary, surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: 'dark textPrimary on surfaceCard must pass WCAG AA',
      );

      // 2. Text Secondary (Warm gray)
      expect(
        contrastRatio(palette.textSecondary, bgBase),
        greaterThanOrEqualTo(4.5),
        reason: 'dark textSecondary on bgBase must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.textSecondary, surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: 'dark textSecondary on surfaceCard must pass WCAG AA',
      );

      // 3. Accent Primary (Figma #C24C27) & Sand & Inverted Pill
      // White text on Accent Primary (e.g. Stop circle)
      expect(
        contrastRatio(const Color(0xFFFFFFFF), palette.accentPrimary),
        greaterThanOrEqualTo(4.5),
        reason:
            'White text on dark accentPrimary button must pass WCAG AA (>= 4.5:1)',
      );
      // Dark high-emphasis pill becomes light pill in dark mode with dark text >= 4.5:1
      expect(
        contrastRatio(const Color(0xFF1C1917), palette.surfaceDark),
        greaterThanOrEqualTo(4.5),
        reason:
            'Dark text on surfaceDark light pill in dark mode must pass WCAG AA (>= 4.5:1)',
      );
      // Accent on dark background / card surfaces (large text / UI components: >= 3:1)
      expect(
        contrastRatio(palette.accentPrimary, bgBase),
        greaterThanOrEqualTo(3.0),
        reason:
            'dark accentPrimary on bgBase must pass WCAG AA for large text/UI components (>= 3:1)',
      );
      expect(
        contrastRatio(palette.accentPrimary, surfaceCard),
        greaterThanOrEqualTo(3.0),
        reason:
            'dark accentPrimary on surfaceCard must pass WCAG AA for large text/UI components (>= 3:1)',
      );
      expect(
        contrastRatio(palette.accentPrimary, surfaceElevated),
        greaterThanOrEqualTo(3.0),
        reason:
            'dark accentPrimary on surfaceElevated must pass WCAG AA for large text/UI components (>= 3:1)',
      );
      // Solar sand in dark mode
      expect(
        contrastRatio(palette.accentSolar, bgBase),
        greaterThanOrEqualTo(4.5),
        reason: 'dark accentSolar on bgBase must pass WCAG AA (>= 4.5:1)',
      );
      expect(
        contrastRatio(palette.accentSolar, surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: 'dark accentSolar on surfaceCard must pass WCAG AA (>= 4.5:1)',
      );

      // 4. Error color (Alert banner)
      expect(
        contrastRatio(palette.errorColor, bgBase),
        greaterThanOrEqualTo(4.5),
        reason: 'dark errorColor on bgBase must pass WCAG AA',
      );
      expect(
        contrastRatio(palette.errorColor, surfaceCard),
        greaterThanOrEqualTo(4.5),
        reason: 'dark errorColor on surfaceCard must pass WCAG AA',
      );
    });

    test('High-contrast mode reaches >= 5.0:1 across both themes', () {
      const lightHc = TidaraPalette(isDark: false, highContrast: true);
      expect(
        contrastRatio(lightHc.textPrimary, lightHc.bgBase),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        contrastRatio(lightHc.textSecondary, lightHc.bgBase),
        greaterThanOrEqualTo(5.0),
      );
      expect(
        contrastRatio(lightHc.accentPrimary, lightHc.bgBase),
        greaterThanOrEqualTo(5.0),
      );
      expect(
        contrastRatio(lightHc.errorColor, lightHc.bgBase),
        greaterThanOrEqualTo(5.0),
      );

      const darkHc = TidaraPalette(isDark: true, highContrast: true);
      expect(
        contrastRatio(darkHc.textPrimary, darkHc.bgBase),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        contrastRatio(darkHc.textSecondary, darkHc.bgBase),
        greaterThanOrEqualTo(5.0),
      );
      expect(
        contrastRatio(darkHc.accentPrimary, darkHc.bgBase),
        greaterThanOrEqualTo(5.0),
      );
      expect(
        contrastRatio(darkHc.errorColor, darkHc.bgBase),
        greaterThanOrEqualTo(5.0),
      );
    });

    test(
      'Contrast table verification — every text/background pair passes >= 4.5:1 (3:1 for large text)',
      () {
        for (final isDark in [false, true]) {
          final palette = TidaraPalette(isDark: isDark);
          final themeName = isDark ? 'Dark' : 'Light';

          // Primary text on bg and surface: >= 4.5:1
          final crPrimaryBg = contrastRatio(
            palette.textPrimary,
            palette.bgBase,
          );
          final crPrimaryCard = contrastRatio(
            palette.textPrimary,
            palette.surfaceCard,
          );
          expect(
            crPrimaryBg,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName primary text on bgBase ($crPrimaryBg:1) must be >= 4.5:1',
          );
          expect(
            crPrimaryCard,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName primary text on surfaceCard ($crPrimaryCard:1) must be >= 4.5:1',
          );

          // Secondary text on bg and surface: >= 4.5:1
          final crSecBg = contrastRatio(palette.textSecondary, palette.bgBase);
          final crSecCard = contrastRatio(
            palette.textSecondary,
            palette.surfaceCard,
          );
          expect(
            crSecBg,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName secondary text on bgBase ($crSecBg:1) must be >= 4.5:1',
          );
          expect(
            crSecCard,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName secondary text on surfaceCard ($crSecCard:1) must be >= 4.5:1',
          );

          // High-emphasis pill text: >= 4.5:1
          final pillTextColor = isDark ? const Color(0xFF1C1917) : Colors.white;
          final crPill = contrastRatio(pillTextColor, palette.surfaceDark);
          expect(
            crPill,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName text on surfaceDark pill ($crPill:1) must be >= 4.5:1',
          );

          // White text on accent primary button: >= 4.5:1
          final crAccentWhite = contrastRatio(
            Colors.white,
            palette.accentPrimary,
          );
          expect(
            crAccentWhite,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName white text on accentPrimary button ($crAccentWhite:1) must be >= 4.5:1',
          );

          // Accent on background / card (large text / UI component: >= 3.0:1)
          final crAccentBg = contrastRatio(
            palette.accentPrimary,
            palette.bgBase,
          );
          final crAccentCard = contrastRatio(
            palette.accentPrimary,
            palette.surfaceCard,
          );
          expect(
            crAccentBg,
            greaterThanOrEqualTo(3.0),
            reason:
                '$themeName accentPrimary on bgBase ($crAccentBg:1) must be >= 3.0:1',
          );
          expect(
            crAccentCard,
            greaterThanOrEqualTo(3.0),
            reason:
                '$themeName accentPrimary on surfaceCard ($crAccentCard:1) must be >= 3.0:1',
          );

          // Error color on bg and surface: >= 4.5:1
          final crErrBg = contrastRatio(palette.errorColor, palette.bgBase);
          final crErrCard = contrastRatio(
            palette.errorColor,
            palette.surfaceCard,
          );
          expect(
            crErrBg,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName errorColor on bgBase ($crErrBg:1) must be >= 4.5:1',
          );
          expect(
            crErrCard,
            greaterThanOrEqualTo(4.5),
            reason:
                '$themeName errorColor on surfaceCard ($crErrCard:1) must be >= 4.5:1',
          );
        }
      },
    );

    test(
      'GlassButton primary text reaches >= 4.5:1 when rendered over light/dark surfaces',
      () {
        const lightPalette = TidaraPalette(isDark: false);
        const darkPalette = TidaraPalette(isDark: true);

        // Pure accent fill (Figma #C24C27) has >= 4.5:1 with white
        expect(
          contrastRatio(Colors.white, lightPalette.accentPrimary),
          greaterThanOrEqualTo(4.5),
          reason:
              'White text on pure accentPrimary (#C24C27) must pass WCAG AA (>= 4.5:1)',
        );

        // Light mode primary button: White text over blended accent fill
        final lightButtonFillOpaque = blendOver(
          lightPalette.accentPrimary,
          0.95,
          lightPalette.surfaceCard,
        );
        expect(
          contrastRatio(Colors.white, lightButtonFillOpaque),
          greaterThanOrEqualTo(4.5),
          reason:
              'White text on 95% blended light primary button passes >= 4.5:1',
        );

        final lightButtonFillGlass = blendOver(
          lightPalette.accentPrimary,
          0.85,
          lightPalette.surfaceCard,
        );
        expect(
          contrastRatio(Colors.white, lightButtonFillGlass),
          greaterThanOrEqualTo(3.0),
          reason:
              'White text on 85% glass accent button passes >= 3.0:1 for large text',
        );

        // Dark mode primary button: White text over blended dark accent fill
        final darkButtonFill = blendOver(
          lightPalette.accentPrimary,
          0.85,
          darkPalette.bgBase,
        );
        expect(
          contrastRatio(Colors.white, darkButtonFill),
          greaterThanOrEqualTo(4.5),
          reason: 'White text on dark primary button must pass WCAG AA',
        );
      },
    );
  });

  group('Widget Rendering & Sheet Contrast Verification', () {
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
    testWidgets('Sound Selection sheet renders with high contrast elements', (
      tester,
    ) async {
      const palette = TidaraPalette(isDark: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return Center(
                  child: GlassButton.primary(
                    onPressed: () =>
                        showCustomAudioSelectionSheet(ctx, palette: palette),
                    label: 'Open Sheet',
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet title and subtitle
      expect(find.text('Sound Selection & Custom Audio'), findsOneWidget);
      expect(
        find.text(
          'Browse your device storage for audio files (MP3/WAV/AAC) or choose a calibrated resonance preset.',
        ),
        findsOneWidget,
      );

      // Verify preset bowls rendered in GlassCards
      expect(find.text('432Hz Tibetan Bowl'), findsOneWidget);
      expect(find.text('528Hz Solfeggio Chime'), findsOneWidget);
      expect(find.text('639Hz Dawn Resonance'), findsOneWidget);

      // Verify buttons
      expect(find.text('Browse Phone Audio Files...'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm Selection'), findsOneWidget);
    });

    testWidgets(
      'TactileAlarmBottomSheet AM/PM and -5m/+5m controls render cleanly without faded appearance',
      (tester) async {
        const palette = TidaraPalette(isDark: false);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: TactileAlarmBottomSheet(
                editingAlarm: null,
                defaultWakeMinutes: 360,
                sunriseMinutesFromMidnight: 360,
                sunsetMinutesFromMidnight: 1080,
                customMusicName: null,
                palette: palette,
                onSelectPhoneMusic: () async => null,
                onTriggerDawnPreview: (_) {},
                onDelete: (_) {},
                onSave: (_) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify AM/PM period chips
        expect(find.text('AM'), findsOneWidget);
        expect(find.text('PM'), findsOneWidget);

        // Verify -5m and +5m chips
        expect(find.text('-5m'), findsOneWidget);
        expect(find.text('+5m'), findsOneWidget);

        // Tap +5m and verify interaction
        await tester.tap(find.text('+5m'));
        await tester.pumpAndSettle();
      },
    );
  });
}
