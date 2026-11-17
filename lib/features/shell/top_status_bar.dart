import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/ephemeris/noaa_ephemeris.dart';
import '../../core/theme/tidara_palette.dart';
import '../../shared/widgets/liquid_glass_components.dart';

class TopStatusBar extends StatelessWidget {
  final TidaraPalette palette;
  final ValueNotifier<DateTime> nowNotifier;
  final bool use24HourFormat;
  final int activeTabIndex;
  final bool isChronoRunning;
  final bool isFocusRunning;
  final String themePreference;
  final bool isMuted;
  final bool showSettingsModal;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSettings;

  const TopStatusBar({
    super.key,
    required this.palette,
    required this.nowNotifier,
    required this.use24HourFormat,
    required this.activeTabIndex,
    required this.isChronoRunning,
    required this.isFocusRunning,
    required this.themePreference,
    required this.isMuted,
    required this.showSettingsModal,
    required this.onSelectTab,
    required this.onToggleTheme,
    required this.onToggleMute,
    required this.onToggleSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<DateTime>(
                  valueListenable: nowNotifier,
                  builder: (context, now, _) {
                    final String formatted =
                        CircadianEphemeris.formatMinutes12h(
                          now.hour * 60 + now.minute,
                          use24Hour: use24HourFormat,
                        );
                    return Semantics(
                      label: 'Current local time $formatted',
                      child: Text(
                        formatted,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                    );
                  },
                ),
                if (activeTabIndex != 2 && isChronoRunning) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: GlassButton.chip(
                      label: ' Chrono',
                      accentColor: palette.accentPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      textStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: palette.accentPrimary,
                      ),
                      semanticLabel:
                          'Chronometer active. Tap to open Chronometer.',
                      onPressed: () => onSelectTab(2),
                    ),
                  ),
                ],
                if (activeTabIndex != 3 && isFocusRunning) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: GlassButton.chip(
                      label: ' Focus',
                      accentColor: palette.accentSolar,
                      customTextColor: palette.accentPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      textStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: palette.accentPrimary,
                      ),
                      semanticLabel:
                          'Focus timer running. Tap to open Focus Timer.',
                      onPressed: () => onSelectTab(3),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassButton.iconOnly(
                icon: themePreference == 'dark'
                    ? Icons.wb_sunny_outlined
                    : themePreference == 'system'
                    ? Icons.brightness_auto_outlined
                    : Icons.nightlight_round,
                iconSize: 19,
                iconColor: palette.isDark
                    ? palette.textPrimary
                    : palette.textSecondary,
                palette: palette,
                tooltip: 'Switch Theme (${themePreference.toUpperCase()})',
                semanticLabel: 'Toggle color theme',
                width: 36,
                height: 36,
                minWidth: 40,
                minHeight: 40,
                isCircle: true,
                onPressed: onToggleTheme,
              ),
              GlassButton.iconOnly(
                icon: isMuted
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined,
                iconSize: 19,
                iconColor: isMuted
                    ? palette.textSecondary
                    : palette.accentPrimary,
                palette: palette,
                tooltip: isMuted
                    ? 'Unmute UI/Ambient (Alarms still ring)'
                    : 'Mute UI/Ambient (Alarms still ring)',
                semanticLabel: isMuted
                    ? 'Unmute ambient and interface sounds. Alarms always ring.'
                    : 'Mute ambient and interface sounds. Alarms always ring.',
                width: 36,
                height: 36,
                minWidth: 40,
                minHeight: 40,
                isCircle: true,
                onPressed: onToggleMute,
              ),
              GlassButton.iconOnly(
                icon: Icons.tune_rounded,
                iconSize: 19,
                iconColor: showSettingsModal
                    ? palette.accentPrimary
                    : (palette.isDark
                          ? palette.textPrimary
                          : palette.textSecondary),
                palette: palette,
                tooltip: 'Settings, Permissions & Guide',
                semanticLabel: 'Open Settings and Time & Focus Guide',
                width: 36,
                height: 36,
                minWidth: 40,
                minHeight: 40,
                isCircle: true,
                onPressed: onToggleSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
