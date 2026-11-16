import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/tidara_palette.dart';
import '../../models/horological_models.dart';
import '../../shared/widgets/liquid_glass_components.dart';
import 'chronometer_dial_painter.dart';

class ChronometerTab extends StatelessWidget {
  final TidaraPalette palette;
  final ValueNotifier<int> chronoElapsedMsNotifier;
  final bool isRunning;
  final List<ChronoLap> laps;
  final VoidCallback onToggleChrono;
  final VoidCallback onLapOrReset;
  final VoidCallback onResetChrono;

  const ChronometerTab({
    super.key,
    required this.palette,
    required this.chronoElapsedMsNotifier,
    required this.isRunning,
    required this.laps,
    required this.onToggleChrono,
    required this.onLapOrReset,
    required this.onResetChrono,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('screen-chrono'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chronometer',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Precision split & lap tracking',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: chronoElapsedMsNotifier,
                    builder: (context, ms, _) {
                      if (ms == 0 && laps.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return GlassButton.chip(
                        label: 'Reset 00:00',
                        icon: Icons.replay,
                        iconSize: 13,
                        accentColor: palette.accentPrimary,
                        customTextColor: palette.accentPrimary,
                        textStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.accentPrimary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        onPressed: onResetChrono,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 240x240 Circular Chronometer Dial
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: ValueListenableBuilder<int>(
                    valueListenable: chronoElapsedMsNotifier,
                    builder: (context, ms, _) {
                      final int hrs = ms ~/ 3600000;
                      final int mins = (ms % 3600000) ~/ 60000;
                      final int secs = (ms % 60000) ~/ 1000;
                      final int centis = (ms % 1000) ~/ 10;

                      final String mainReadout = hrs > 0
                          ? '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
                          : '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

                      final int lapNum = isRunning
                          ? laps.length + 1
                          : math.max(1, laps.length);

                      final String subBadgeText =
                          '.${centis.toString().padLeft(2, '0')} · Lap ${lapNum.toString().padLeft(2, '0')}';

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(240, 240),
                              painter: StaticChronometerDialRingPainter(
                                palette: palette,
                              ),
                            ),
                          ),
                          RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(240, 240),
                              painter: DynamicChronometerSweepHandPainter(
                                elapsedMs: ms,
                                palette: palette,
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    mainReadout,
                                    style: TextStyle(
                                      fontSize: hrs > 0 ? 40 : 52,
                                      fontWeight: FontWeight.w600,
                                      height: 1.0,
                                      letterSpacing: -1.0,
                                      color: palette.textPrimary,
                                      fontFeatures: const [
                                        ui.FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.surfaceCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: palette.strokeSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    subBadgeText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: palette.textSecondary,
                                      fontFeatures: const [
                                        ui.FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Symmetrical 72x72px Control Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: ValueListenableBuilder<int>(
                  valueListenable: chronoElapsedMsNotifier,
                  builder: (context, ms, _) {
                    final bool canResetOrLap =
                        isRunning || ms > 0 || laps.isNotEmpty;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GlassButton(
                          label: isRunning
                              ? 'Lap'
                              : (ms > 0 || laps.isNotEmpty ? 'Reset' : 'Lap'),
                          isCircle: true,
                          palette: palette,
                          width: 72,
                          height: 72,
                          minWidth: 72,
                          minHeight: 72,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          semanticLabel: isRunning
                              ? 'Record Lap'
                              : 'Reset Chronometer',
                          onPressed: canResetOrLap ? onLapOrReset : null,
                        ),
                        GlassButton(
                          label: isRunning
                              ? 'Stop'
                              : (ms > 0 ? 'Resume' : 'Start'),
                          isCircle: true,
                          isPrimary: true,
                          palette: palette,
                          accentColor: palette.accentPrimary,
                          width: 72,
                          height: 72,
                          minWidth: 72,
                          minHeight: 72,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          semanticLabel: isRunning
                              ? 'Stop Chronometer'
                              : 'Start Chronometer',
                          onPressed: onToggleChrono,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // Lap Ledger
              if (laps.isEmpty)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: palette.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.strokeSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'No splits recorded yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                      Text(
                        '00:00.00',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 156),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: laps.length,
                    itemBuilder: (ctx, idx) {
                      final ChronoLap lap = laps[idx];
                      final bool isHighlighted = idx == 0 || lap.isFastest;
                      return Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: idx == 0
                              ? palette.surfaceCard
                              : Colors.transparent,
                          borderRadius: idx == 0
                              ? BorderRadius.circular(10)
                              : BorderRadius.zero,
                          border: idx != 0 && idx < laps.length - 1
                              ? Border(
                                  bottom: BorderSide(
                                    color: palette.strokeSubtle,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      lap.number.startsWith('Lap')
                                          ? lap.number
                                          : 'Lap ${lap.number}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isHighlighted
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isHighlighted
                                            ? palette.textPrimary
                                            : palette.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (lap.isFastest) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.surfaceElevated,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Fastest',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: palette.accentPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (lap.isSlowest && !lap.isFastest) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.surfaceCard,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: palette.strokeSubtle,
                                        ),
                                      ),
                                      child: Text(
                                        'Slowest',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              lap.formatted,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isHighlighted
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isHighlighted
                                    ? palette.textPrimary
                                    : palette.textSecondary,
                                fontFeatures: const [
                                  ui.FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
