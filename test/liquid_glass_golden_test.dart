import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Liquid Glass Buttons Golden Tests', () {
    testWidgets('GlassButton primary dark theme golden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF141210),
            body: Center(
              child: GlassButton.primary(
                label: 'Save Rhythm',
                icon: Icons.check,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(GlassButton),
        matchesGoldenFile('goldens/glass_button_primary_dark.png'),
      );
    });

    testWidgets('GlassButton primary light theme golden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: const Color(0xFFF4F0E8),
            body: Center(
              child: GlassButton.primary(
                label: 'Save Rhythm',
                icon: Icons.check,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(GlassButton),
        matchesGoldenFile('goldens/glass_button_primary_light.png'),
      );
    });

    testWidgets('GlassButton secondary dark theme golden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF141210),
            body: Center(
              child: GlassButton.secondary(
                label: 'Cancel Action',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(GlassButton),
        matchesGoldenFile('goldens/glass_button_secondary_dark.png'),
      );
    });

    testWidgets('GlassButton secondary light theme golden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: const Color(0xFFF4F0E8),
            body: Center(
              child: GlassButton.secondary(
                label: 'Cancel Action',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(GlassButton),
        matchesGoldenFile('goldens/glass_button_secondary_light.png'),
      );
    });
  });
}
