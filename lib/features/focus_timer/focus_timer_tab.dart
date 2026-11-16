import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/tidara_palette.dart';
import '../../models/horological_models.dart';
import '../../shared/widgets/liquid_glass_components.dart';
import 'sculptural_hourglass_widget.dart';

class FocusTimerTab extends StatelessWidget {
  final TidaraPalette palette;
  final String activePresetId;
  final int? customTotalSec;
  final bool focusRunning;
  final int completedGhatikas;
  final int hourglassFlipCount;
  final String activeSoundscapeId;
  final String? customMusicName;
  final ValueNotifier<double> focusProgressNotifier;
  final ValueNotifier<double> focusRemainingSecNotifier;
  final int effectiveFocusTotalSec;
  final VoidCallback onToggleFocus;
  final VoidCallback onManualHourglassFlip;
  final ValueChanged<FocusPreset> onSelectPreset;
  final VoidCallback onPromptCustomDuration;
  final ValueChanged<String> onChangeSoundscape;
  final VoidCallback onBrowseAudio;

  const FocusTimerTab({
    super.key,
    required this.palette,
    required this.activePresetId,
    required this.customTotalSec,
    required this.focusRunning,
    required this.completedGhatikas,
    required this.hourglassFlipCount,
    required this.activeSoundscapeId,
    required this.customMusicName,
    required this.focusProgressNotifier,
    required this.focusRemainingSecNotifier,
    required this.effectiveFocusTotalSec,
    required this.onToggleFocus,
    required this.onManualHourglassFlip,
    required this.onSelectPreset,
    required this.onPromptCustomDuration,
    required this.onChangeSoundscape,
    required this.onBrowseAudio,
  });

  @override
  Widget build(BuildContext context) {
    final int plannedMins = (effectiveFocusTotalSec / 60).round();

    final Map<String, Map<String, String>> soundscapes = {
      'bowl': {
        'title': 'Nordic Cedar & Singing Bowl',
        'sub': 'Binaural 432Hz | Continuous flow',
      },
      'tanpura': {
        'title': 'Harmonic Tanpura & Monsoon Rain',
        'sub': '528Hz Harmonic Chime | Organic tone',
      },
      'pendulum': {
        'title': 'Stockholm Observatory Pendulum',
        'sub': '60 BPM Mechanical tick | Isochronic',
      },
      if (customMusicName != null)
        'custom': {
          'title': customMusicName!,
          'sub': 'Custom Phone Audio | Continuous loop',
        },
      'silent': {
        'title': 'Silent Focus Meditation',
        'sub': 'Zero acoustic output | End-bell only',
      },
    };

    final Map<String, String> activeSound =
        soundscapes[activeSoundscapeId] ?? soundscapes['bowl']!;

    return SingleChildScrollView(
      key: const ValueKey('screen-focus'),
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
                      'Focus & Sand Timer',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Structured focus & deep work intervals',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (completedGhatikas > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.strokeSubtle),
                  ),
                  child: Text(
                    ' $completedGhatikas Done',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.accentPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Center(
            child: SculpturalHourglassWidget(
              progressListenable: focusProgressNotifier,
              isRunning: focusRunning,
              flipGeneration: hourglassFlipCount,
              palette: palette,
              onManualFlip: onManualHourglassFlip,
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: ValueListenableBuilder<double>(
              valueListenable: focusRemainingSecNotifier,
              builder: (context, remSec, _) {
                final int rounded = remSec.ceil();
                final String m = (rounded ~/ 60).toString().padLeft(2, '0');
                final String s = (rounded % 60).toString().padLeft(2, '0');

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GlassButton.iconOnly(
                          icon: Icons.tune_rounded,
                          iconSize: 15,
                          iconColor: palette.textSecondary,
                          width: 32,
                          height: 32,
                          minWidth: 48,
                          minHeight: 48,
                          isCircle: true,
                          semanticLabel: 'Set custom focus minutes',
                          onPressed: onPromptCustomDuration,
                        ),
                        const SizedBox(width: 14),
                        Semantics(
                          button: true,
                          label:
                              'Remaining time $m minutes $s seconds. Tap to customize focus duration.',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onPromptCustomDuration,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                '$m:$s',
                                style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                  letterSpacing: -0.9,
                                  color: palette.textPrimary,
                                  fontFeatures: const [
                                    ui.FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        GlassButton.iconOnly(
                          icon: Icons.replay,
                          iconSize: 15,
                          iconColor: palette.textSecondary,
                          width: 32,
                          height: 32,
                          minWidth: 48,
                          minHeight: 48,
                          isCircle: true,
                          semanticLabel: 'Reset hourglass',
                          onPressed: onManualHourglassFlip,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.strokeSubtle),
                      ),
                      child: Text(
                        customTotalSec != null
                            ? '${customTotalSec! ~/ 60}m Focus Session'
                            : '${plannedMins}m Focus Session',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              clipBehavior: Clip.none,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: kFocusPresets.map((preset) {
                  final bool isSelected =
                      preset.id == activePresetId && customTotalSec == null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GlassButton.chip(
                      label: isSelected ? preset.activeLabel : preset.label,
                      icon: Icons.timer_outlined,
                      iconSize: 13,
                      isSelected: isSelected,
                      accentColor: palette.accentPrimary,
                      palette: palette,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onPressed: () => onSelectPreset(preset),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ValueListenableBuilder<double>(
            valueListenable: focusRemainingSecNotifier,
            builder: (context, remSec, _) {
              final double targetTotal = (customTotalSec ?? (plannedMins * 60))
                  .toDouble();
              final String ctaText;
              if (focusRunning) {
                ctaText = 'Pause';
              } else if (remSec >= targetTotal || remSec <= 0) {
                ctaText = 'Start Focus';
              } else {
                ctaText = 'Resume Focus';
              }
              return GlassButton.highEmphasisPill(
                label: ctaText,
                palette: palette,
                icon: focusRunning
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                iconSize: 20,
                height: 52,
                borderRadius: BorderRadius.circular(16),
                semanticLabel: ctaText,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                onPressed: onToggleFocus,
              );
            },
          ),
          const SizedBox(height: 12),

          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.strokeSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activeSoundscapeId == 'custom'
                        ? Icons.library_music_outlined
                        : Icons.air,
                    size: 16,
                    color: palette.accentPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final List<String> keys = soundscapes.keys.toList();
                      final int nextIdx =
                          (keys.indexOf(activeSoundscapeId) + 1) % keys.length;
                      final String nextId = keys[nextIdx];
                      onChangeSoundscape(nextId);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          activeSound['title']!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          activeSound['sub']!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GlassButton(
                  label: 'Browse',
                  icon: Icons.folder_open_rounded,
                  iconSize: 13,
                  isPrimary: true,
                  accentColor: palette.accentPrimary,
                  palette: palette,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  semanticLabel: 'Browse device audio files',
                  onPressed: onBrowseAudio,
                ),
                const SizedBox(width: 6),
                GlassButton(
                  label: 'Change',
                  palette: palette,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  textStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.accentPrimary,
                  ),
                  customTextColor: palette.accentPrimary,
                  onPressed: () {
                    final List<String> keys = soundscapes.keys.toList();
                    final int nextIdx =
                        (keys.indexOf(activeSoundscapeId) + 1) % keys.length;
                    final String nextId = keys[nextIdx];
                    onChangeSoundscape(nextId);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
