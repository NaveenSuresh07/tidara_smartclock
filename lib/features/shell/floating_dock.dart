import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/theme/tidara_palette.dart';

class FloatingDock extends StatelessWidget {
  final TidaraPalette palette;
  final int activeTabIndex;
  final bool hasActiveAlarms;
  final bool isChronoRunning;
  final bool isFocusRunning;
  final ValueChanged<int> onSelectTab;

  const FloatingDock({
    super.key,
    required this.palette,
    required this.activeTabIndex,
    required this.hasActiveAlarms,
    required this.isChronoRunning,
    required this.isFocusRunning,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tabs = [
      {'index': 0, 'label': 'Alarms & Rhythms', 'dot': hasActiveAlarms},
      {'index': 1, 'label': 'World Clock', 'dot': false},
      {'index': 2, 'label': 'Chronometer', 'dot': isChronoRunning},
      {'index': 3, 'label': 'Focus Timer', 'dot': isFocusRunning},
    ];

    const List<double> pillLeftOffsets = [18.0, 82.6, 147.3, 212.0];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 280,
          height: 64,
          decoration: BoxDecoration(
            color: palette.surfaceCard,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: palette.strokeSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isDark ? 0.45 : 0.08,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                left: pillLeftOffsets[activeTabIndex.clamp(0, 3)],
                top: 11,
                child: Container(
                  width: 50,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.isDark
                        ? const Color(0xFF2E2723)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: palette.isDark
                        ? Border.all(
                            color: palette.accentPrimary.withValues(
                              alpha: 0.28,
                            ),
                            width: 1.0,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: palette.isDark ? 0.35 : 0.08,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: tabs.map((tab) {
                    final int idx = tab['index'] as int;
                    final bool isActive = activeTabIndex == idx;
                    final bool showDot = (tab['dot'] as bool) && !isActive;

                    return Semantics(
                      button: true,
                      selected: isActive,
                      label: tab['label'] as String,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HorologicalAudioEngine.instance.playEscapementClick(
                            pitchHz: isActive ? 940 : 1180,
                          );
                          onSelectTab(idx);
                        },
                        child: SizedBox(
                          width: 50,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (idx == 0)
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 20,
                                  color: isActive
                                      ? palette.accentPrimary
                                      : palette.textPrimary,
                                )
                              else if (idx == 1)
                                Icon(
                                  Icons.language,
                                  size: 20,
                                  color: isActive
                                      ? palette.accentPrimary
                                      : palette.textPrimary,
                                )
                              else if (idx == 2)
                                Icon(
                                  Icons.timer_outlined,
                                  size: 20,
                                  color: isActive
                                      ? palette.accentPrimary
                                      : palette.textPrimary,
                                )
                              else
                                Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 20,
                                  color: isActive
                                      ? palette.accentPrimary
                                      : palette.textPrimary,
                                ),
                              if (showDot)
                                Positioned(
                                  top: 6,
                                  right: 10,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: palette.accentPrimary.withValues(
                                        alpha: 0.82,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'tidara',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            fontFamily: 'Georgia',
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
