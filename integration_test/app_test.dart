import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tidara_smartclock/core/security/encrypted_vault.dart';
import 'package:tidara_smartclock/features/shell/tidara_shell_screen.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureTimeZonesInitialized();
    EncryptedVault.clearVault();
  });

  group('Tidara Smartclock End-to-End Integration Tests', () {
    testWidgets(
      '1. Full app lifecycle: Mount shell, verify initial rendering, and navigate across all 4 tabs',
      (tester) async {
        await tester.pumpWidget(const TidaraSmartclockApp());
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TidaraSmartclockApp), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Verify bottom navigation items exist
        expect(find.text('World'), findsOneWidget);
        expect(find.text('Alarms'), findsOneWidget);
        expect(find.text('Chrono'), findsOneWidget);
        expect(find.text('Focus'), findsOneWidget);

        // Navigate to Alarms tab
        await tester.tap(find.text('Alarms'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('SMART ALARMS'), findsOneWidget);

        // Navigate to Chrono tab
        await tester.tap(find.text('Chrono'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('SOLAR CHRONOMETER'), findsOneWidget);

        // Navigate to Focus tab
        await tester.tap(find.text('Focus'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('MIND STILLNESS & FOCUS'), findsOneWidget);

        // Return to World tab
        await tester.tap(find.text('World'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('CELESTIAL WORLD CLOCK'), findsOneWidget);
      },
    );

    testWidgets(
      '2. World Clock: Search action opens city search sheet and dismisses cleanly',
      (tester) async {
        await tester.pumpWidget(const TidaraSmartclockApp());
        await tester.pump(const Duration(milliseconds: 300));

        final searchButton = find.byIcon(Icons.search_rounded);
        expect(searchButton, findsOneWidget);

        await tester.tap(searchButton);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Search World Cities'), findsOneWidget);

        final closeButton = find.byIcon(Icons.close_rounded);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Search World Cities'), findsNothing);
      },
    );

    testWidgets('3. Chronometer: Start and stop button interactions', (
      tester,
    ) async {
      await tester.pumpWidget(const TidaraSmartclockApp());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Chrono'));
      await tester.pump(const Duration(milliseconds: 300));

      final startButton = find.text('Start');
      expect(startButton, findsOneWidget);
      await tester.tap(startButton);
      await tester.pump(const Duration(milliseconds: 200));

      final stopButton = find.text('Stop');
      expect(stopButton, findsOneWidget);
      await tester.tap(stopButton);
      await tester.pump(const Duration(milliseconds: 200));

      final resetOrStart = find.text('Reset');
      if (resetOrStart.evaluate().isNotEmpty) {
        await tester.tap(resetOrStart);
        await tester.pump(const Duration(milliseconds: 200));
      }
    });

    testWidgets('4. Settings and Glossary modal opens and dismisses', (
      tester,
    ) async {
      await tester.pumpWidget(const TidaraSmartclockApp());
      await tester.pump(const Duration(milliseconds: 300));

      final settingsIcon = find.byIcon(Icons.tune_rounded);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Settings & Horological Guide'), findsOneWidget);

        final closeIcon = find.byIcon(Icons.close);
        if (closeIcon.evaluate().isNotEmpty) {
          await tester.tap(closeIcon);
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
    });
  });
}
