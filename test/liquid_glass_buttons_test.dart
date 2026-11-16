import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Liquid Glass Buttons - Variants & Behaviors', () {
    testWidgets('GlassButton.primary renders, taps, satisfies min 48x48 size', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassButton.primary(
                label: 'Save Rhythm',
                icon: Icons.check,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Save Rhythm'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      final size = tester.getSize(find.byType(GlassButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(find.byType(GlassButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      final semantics = tester.getSemantics(find.byType(GlassButton));
      expect(semantics.label, contains('Save Rhythm'));
    });

    testWidgets('GlassButton.primary disabled state ignores tap', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassButton.primary(
                label: 'Disabled Action',
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GlassButton));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);

      final semantics = tester.getSemantics(find.byType(GlassButton));
      expect(semantics.label, contains('Disabled Action'));
    });

    testWidgets('GlassButton.secondary renders, taps, satisfies min size', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassButton.secondary(
                label: 'Cancel',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      final size = tester.getSize(find.byType(GlassButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(find.byType(GlassButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('GlassButton.destructive renders and triggers tap', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassButton.destructive(
                label: 'Delete Alarm',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Delete Alarm'), findsOneWidget);
      await tester.tap(find.byType(GlassButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets(
      'GlassButton.iconOnly renders tooltip, semantics, satisfies min 48x48 size',
      (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GlassButton.iconOnly(
                  icon: Icons.close,
                  semanticLabel: 'Close Sheet',
                  tooltip: 'Close',
                  onPressed: () => tapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsOneWidget);
        final size = tester.getSize(find.byType(GlassButton));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));

        await tester.tap(find.byType(GlassButton));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'GlassButton.chip renders selected/unselected state and fires callback',
      (tester) async {
        bool selected = false;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: GlassButton.chip(
                      label: 'Mon',
                      isSelected: selected,
                      onPressed: () => setState(() => selected = !selected),
                    ),
                  ),
                ),
              );
            },
          ),
        );

        expect(find.text('Mon'), findsOneWidget);
        final size = tester.getSize(find.byType(GlassButton));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));

        await tester.tap(find.byType(GlassButton));
        await tester.pumpAndSettle();
        expect(selected, isTrue);
      },
    );

    testWidgets('GlassButton.largeCta renders full width or 52dp height', (
      tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassButton.largeCta(
                label: 'Dismiss Alarm',
                isPrimary: true,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dismiss Alarm'), findsOneWidget);
      final size = tester.getSize(find.byType(GlassButton));
      expect(size.height, greaterThanOrEqualTo(52.0));

      await tester.tap(find.byType(GlassButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets(
      'GlassButton.highEmphasisPill renders dark glass in light theme and light glass in dark theme',
      (tester) async {
        // Light Theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Center(
                child: GlassButton.highEmphasisPill(
                  label: 'Pause Stillness',
                  icon: Icons.pause_circle_outline,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('Pause Stillness'), findsOneWidget);
        expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);

        // Dark Theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: GlassButton.highEmphasisPill(
                  label: 'Pause Stillness',
                  icon: Icons.pause_circle_outline,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('Pause Stillness'), findsOneWidget);
        expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      },
    );

    testWidgets(
      'GlassButton wraps custom child preserving visual size and satisfying 48x48 touch target',
      (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GlassButton(
                  width: 32,
                  height: 32,
                  isCircle: true,
                  onPressed: () => tapped = true,
                  child: const Icon(Icons.tune, size: 18),
                ),
              ),
            ),
          ),
        );

        // Visual container size
        final containerFinder = find.descendant(
          of: find.byType(GlassButton),
          matching: find.byType(Container),
        );
        expect(containerFinder, findsWidgets);
        final visualSize = tester.getSize(containerFinder.first);
        expect(visualSize.width, equals(32.0));
        expect(visualSize.height, equals(32.0));

        // Overall GlassButton widget hit area satisfies >= 48x48
        final buttonSize = tester.getSize(find.byType(GlassButton));
        expect(buttonSize.width, greaterThanOrEqualTo(48.0));
        expect(buttonSize.height, greaterThanOrEqualTo(48.0));

        await tester.tap(find.byType(GlassButton));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'GlassButton respects disableAnimations setting from MediaQuery',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: GlassButton.primary(
                    label: 'Animated',
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        final animatedScaleFinder = find.descendant(
          of: find.byType(GlassButton),
          matching: find.byType(AnimatedScale),
        );
        expect(animatedScaleFinder, findsOneWidget);
        final scaleWidget = tester.widget<AnimatedScale>(animatedScaleFinder);
        expect(scaleWidget.duration, equals(Duration.zero));
      },
    );

    testWidgets('High-contrast mode uses solid fill and strong borders', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: Scaffold(
              body: Center(
                child: GlassButton.primary(
                  label: 'High Contrast Primary',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('High Contrast Primary'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);

      final containerFinder = find.descendant(
        of: find.byType(GlassButton),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.gradient, isNull);
    });

    test(
      'Source-scan: No raw Button widgets used outside liquid_glass_components.dart',
      () {
        final libDir = Directory('lib');
        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.endsWith('liquid_glass_components.dart'));

        final rawButtonRegex = RegExp(
          r'\b(ElevatedButton|FilledButton|OutlinedButton|TextButton|IconButton)\s*(\.icon|\.styleFrom|\()',
        );

        final List<String> violations = [];

        for (final file in dartFiles) {
          final lines = file.readAsLinesSync();
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Allow justified theme configuration and pre-glass baseline screens
            if (file.path.contains('tidara_shell_screen.dart') &&
                (line.contains('ThemeData') ||
                    line.contains('ButtonThemeData') ||
                    line.contains('.styleFrom'))) {
              continue;
            }
            if (rawButtonRegex.hasMatch(line)) {
              violations.add('${file.path}:${i + 1}: $line');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Raw buttons must not be used outside liquid_glass_components.dart. Violations found:\n${violations.join('\n')}',
        );
      },
    );

    testWidgets(
      'Every circular / icon-only button places its icon center at the exact visual center of the button',
      (tester) async {
        final cases = <Map<String, dynamic>>[
          {
            'name': 'Alarm Dial (-) Button (48x48 icon-only)',
            'widget': GlassButton.iconOnly(
              icon: Icons.remove,
              semanticLabel: 'Decrease wake time',
              onPressed: () {},
            ),
          },
          {
            'name': 'Alarm Dial (+) Button (48x48 icon-only)',
            'widget': GlassButton.iconOnly(
              icon: Icons.add,
              semanticLabel: 'Increase wake time',
              onPressed: () {},
            ),
          },
          {
            'name': 'Focus Timer Tune (32x32 circle)',
            'widget': GlassButton.iconOnly(
              icon: Icons.tune_rounded,
              iconSize: 15,
              width: 32,
              height: 32,
              isCircle: true,
              semanticLabel: 'Tune custom focus',
              onPressed: () {},
            ),
          },
          {
            'name': 'Focus Timer Reset (32x32 circle)',
            'widget': GlassButton.iconOnly(
              icon: Icons.replay,
              iconSize: 15,
              width: 32,
              height: 32,
              isCircle: true,
              semanticLabel: 'Reset hourglass',
              onPressed: () {},
            ),
          },
          {
            'name': 'Top Utility Circle (36x36 circle)',
            'widget': GlassButton.iconOnly(
              icon: Icons.wb_sunny_outlined,
              iconSize: 19,
              width: 36,
              height: 36,
              isCircle: true,
              semanticLabel: 'Toggle theme',
              onPressed: () {},
            ),
          },
          {
            'name': 'Settings Close Circle (48x48 icon-only)',
            'widget': GlassButton.iconOnly(
              icon: Icons.close,
              semanticLabel: 'Close settings',
              onPressed: () {},
            ),
          },
          {
            'name': 'Sound Preset Preview Circle (28x28 circle)',
            'widget': GlassButton.iconOnly(
              icon: Icons.play_circle_fill_rounded,
              iconSize: 18,
              width: 28,
              height: 28,
              minWidth: 36,
              minHeight: 36,
              isCircle: true,
              semanticLabel: 'Preview sound',
              onPressed: () {},
            ),
          },
          {
            'name': 'Custom Child in Circle Button',
            'widget': GlassButton(
              width: 32,
              height: 32,
              isCircle: true,
              onPressed: () {},
              child: const Icon(Icons.tune, size: 18),
            ),
          },
        ];

        for (final c in cases) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: Center(child: c['widget'] as Widget)),
            ),
          );

          final iconFinder = find.byType(Icon);
          expect(
            iconFinder,
            findsOneWidget,
            reason: '${c['name']} must render an Icon',
          );

          final containerFinder = find.descendant(
            of: find.byType(GlassButton),
            matching: find.byType(Container),
          );
          expect(containerFinder, findsWidgets);

          final Offset iconCenter = tester.getCenter(iconFinder);
          final Offset visualCenter = tester.getCenter(containerFinder.first);
          final double distance = (iconCenter - visualCenter).distance;

          expect(
            distance,
            lessThanOrEqualTo(1.0),
            reason:
                '${c['name']} icon must be centered within 1.0px of visual container (got distance: $distance)',
          );
        }
      },
    );

    testWidgets(
      'Every GlassButton variant in Light and Dark themes meets at least 4.5:1 contrast',
      (tester) async {
        double lumChannel(int ch) {
          final double c = ch / 255.0;
          return c <= 0.04045
              ? c / 12.92
              : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
        }

        double relLum(Color color) {
          final int r = (color.r * 255.0).round();
          final int g = (color.g * 255.0).round();
          final int b = (color.b * 255.0).round();
          return 0.2126 * lumChannel(r) +
              0.7152 * lumChannel(g) +
              0.0722 * lumChannel(b);
        }

        double calcContrast(Color c1, Color c2) {
          final l1 = relLum(c1);
          final l2 = relLum(c2);
          final hi = math.max(l1, l2);
          final lo = math.min(l1, l2);
          return (hi + 0.05) / (lo + 0.05);
        }

        Color blend(Color fg, double alpha, Color bg) {
          final int fgR = (fg.r * 255.0).round();
          final int fgG = (fg.g * 255.0).round();
          final int fgB = (fg.b * 255.0).round();
          final int bgR = (bg.r * 255.0).round();
          final int bgG = (bg.g * 255.0).round();
          final int bgB = (bg.b * 255.0).round();
          final int outR = (fgR * alpha + bgR * (1.0 - alpha)).round().clamp(
            0,
            255,
          );
          final int outG = (fgG * alpha + bgG * (1.0 - alpha)).round().clamp(
            0,
            255,
          );
          final int outB = (fgB * alpha + bgB * (1.0 - alpha)).round().clamp(
            0,
            255,
          );
          return Color.fromARGB(255, outR, outG, outB);
        }

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

            // Find resolved foreground color from IconTheme or DefaultTextStyle
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

            // Find resolved background decoration
            final containerFinder = find.descendant(
              of: find.byType(GlassButton),
              matching: find.byType(Container),
            );
            final container = tester.widget<Container>(containerFinder.first);
            final decoration = container.decoration as BoxDecoration;

            Color effectiveFill;
            if (decoration.color != null) {
              effectiveFill = blend(
                decoration.color!,
                decoration.color!.a,
                bgSurface,
              );
            } else if (decoration.gradient is LinearGradient) {
              final grad = decoration.gradient! as LinearGradient;
              final topC = grad.colors.first;
              effectiveFill = blend(topC, topC.a, bgSurface);
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
}
