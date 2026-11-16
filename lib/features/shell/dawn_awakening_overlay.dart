import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/theme/tidara_palette.dart';
import '../../shared/widgets/liquid_glass_components.dart';

class DawnAwakeningOverlay extends StatelessWidget {
  final TidaraPalette palette;
  final Map<String, dynamic> ringingAlarm;
  final ValueNotifier<DateTime> nowNotifier;
  final void Function({required int snoozeMinutes}) onDismiss;

  const DawnAwakeningOverlay({
    super.key,
    required this.palette,
    required this.ringingAlarm,
    required this.nowNotifier,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPreview = ringingAlarm['isPreview'] == true;
    final String title = ringingAlarm['title']?.toString() ?? 'Solar Awakening';
    final String time = ringingAlarm['time']?.toString() ?? '05:30 AM';
    final String soundMeta = ringingAlarm['soundMeta']?.toString() ?? '';

    return Positioned.fill(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.35),
            radius: 1.1,
            colors: [Color(0xFFE58A38), Color(0xFFC24C27), Color(0xFF1C1917)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ValueListenableBuilder<DateTime>(
                valueListenable: nowNotifier,
                builder: (context, _, __) {
                  final int swellPct =
                      (HorologicalAudioEngine
                                  .instance
                                  .currentAlarmSwellProgress *
                              100)
                          .round();
                  final String bannerText = isPreview
                      ? 'DAWN SWELL PREVIEW | $swellPct% VOLUME (SIMULATED)'
                      : 'GRADUAL DAWN SWELL | $swellPct% VOLUME (BYPASSES MUTE)';
                  return Text(
                    bannerText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  );
                },
              ),
            ),
            Column(
              children: [
                if (isPreview) ...[
                  Container(
                    key: const Key('preview_mode_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentPrimary.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PREVIEW MODE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F0E8).withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_rounded,
                    size: 48,
                    color: Color(0xFFF4F0E8),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF4F0E8),
                    fontFeatures: [ui.FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (soundMeta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    soundMeta,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFFF4F0E8).withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassButton.largeCta(
                  label: 'Snooze 12 minutes',
                  isPrimary: false,
                  onPressed: () => onDismiss(snoozeMinutes: 12),
                ),
                const SizedBox(height: 12),
                GlassButton.largeCta(
                  label: isPreview ? 'Close preview' : 'Dismiss Alarm',
                  isPrimary: false,
                  isDestructive: !isPreview,
                  accentColor: isPreview ? palette.accentPrimary : null,
                  onPressed: () => onDismiss(snoozeMinutes: 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
