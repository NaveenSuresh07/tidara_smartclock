import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/shell/security_diagnostics_modal.dart';
import 'package:tidara_smartclock/features/shell/settings_modal.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

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

  group('Security Diagnostics & Release Mode Isolation Tests', () {
    testWidgets(
      'SecurityDiagnosticsModal in debug mode (isDebug: true) runs live checks and shows key source',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        bool closed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  SecurityDiagnosticsModal(
                    palette: palette,
                    isDebug: true,
                    onClose: () => closed = true,
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Diagnostics header is visible
        expect(find.text('Security Diagnostics (Debug Only)'), findsOneWidget);

        // 2. Active key source is dynamically reflected
        expect(find.textContaining('Active Vault Key Source:'), findsOneWidget);

        // 3. Live checks execute and display live pass/fail badges
        expect(find.text('LIVE SELF-TEST RESULTS'), findsOneWidget);
        expect(find.text('LIVE PASS'), findsWidgets);

        // 4. Re-run live checks button is functional
        final refreshButton = find.text('Re-run Live Checks');
        expect(refreshButton, findsOneWidget);
        await tester.tap(refreshButton);
        await tester.pumpAndSettle();

        // 5. Close button functions
        final closeBtn = find.byIcon(Icons.close);
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        expect(closed, isTrue);
      },
    );

    testWidgets(
      'SecurityDiagnosticsModal in release mode (isDebug: false) is completely unreachable and renders empty SizedBox',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  SecurityDiagnosticsModal(
                    palette: palette,
                    isDebug: false, // Simulating production release mode
                    onClose: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Diagnostic content must be strictly absent
        expect(find.text('Security Diagnostics (Debug Only)'), findsNothing);
        expect(find.text('LIVE SELF-TEST RESULTS'), findsNothing);
        expect(find.textContaining('Active Vault Key Source:'), findsNothing);
        expect(find.text('LIVE PASS'), findsNothing);

        // Only SizedBox.shrink is rendered
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(
          sizedBoxes.any((sb) => sb.width == 0.0 && sb.height == 0.0),
          isTrue,
        );
      },
    );

    testWidgets(
      'SettingsAndGlossaryModal by default hides developer button and raw cipher preview',
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
                    plainLanguageVedic: true,
                    // Default configuration: enableDebugDiagnostics defaults to kDebugMode && kShowSecurityDiagnostics (false)
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

        // Debug button must NOT be present by default
        expect(
          find.byKey(const Key('open_debug_security_diagnostics_button')),
          findsNothing,
        );

        // Raw cipher / nonce preview must never be shown to users
        expect(
          find.textContaining('Authenticated Vault Cipher:'),
          findsNothing,
        );
        expect(find.textContaining('"alg":"AES-256-GCM"'), findsNothing);
        expect(find.textContaining('"nonce":'), findsNothing);
      },
    );

    testWidgets(
      'SettingsAndGlossaryModal with showDiagnosticsOverride: true exposes diagnostics button with high-contrast text and triggers callback',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        bool diagnosticsOpened = false;
        const darkPalette = TidaraPalette(isDark: true);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Stack(
                children: [
                  SettingsAndGlossaryModal(
                    palette: darkPalette,
                    alarmEphem: ephem,
                    alarmHomeCity: testCity,
                    use24HourFormat: false,
                    highContrastMode: false,
                    plainLanguageVedic: true,
                    showDiagnosticsOverride: true,
                    onOpenSecurityDiagnostics: () => diagnosticsOpened = true,
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

        final buttonFinder = find.byKey(
          const Key('open_debug_security_diagnostics_button'),
        );
        expect(buttonFinder, findsOneWidget);

        // Ensure text is high-contrast off-white in dark mode, not black-on-dark-grey
        final labelFinder = find.text(
          'Developer Security Diagnostics (Debug Only)',
        );
        expect(labelFinder, findsOneWidget);
        final labelText = tester.widget<Text>(labelFinder);
        expect(labelText.style?.color, equals(const Color(0xFFF4F0E8)));

        await tester.ensureVisible(buttonFinder);
        await tester.pumpAndSettle();
        await tester.tap(buttonFinder);
        expect(diagnosticsOpened, isTrue);
      },
    );
  });
}
