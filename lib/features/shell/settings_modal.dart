import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/ephemeris/noaa_ephemeris.dart';
import '../../core/theme/tidara_palette.dart';
import '../../models/horological_models.dart';
import '../../shared/widgets/liquid_glass_components.dart';

const bool kShowSecurityDiagnostics = bool.fromEnvironment(
  'SHOW_SECURITY_DIAGNOSTICS',
  defaultValue: false,
);

class SettingsAndGlossaryModal extends StatelessWidget {
  final TidaraPalette palette;
  final CircadianEphemeris alarmEphem;
  final WorldCity alarmHomeCity;
  final bool use24HourFormat;
  final bool highContrastMode;
  final bool enableDebugDiagnostics;
  final bool? showDiagnosticsOverride;
  final VoidCallback? onOpenSecurityDiagnostics;
  final ValueChanged<bool> onToggle24Hour;
  final ValueChanged<bool> onToggleHighContrast;
  final ValueChanged<WorldCity> onSelectAlarmHomeCity;
  final VoidCallback onClose;

  const SettingsAndGlossaryModal({
    super.key,
    required this.palette,
    required this.alarmEphem,
    required this.alarmHomeCity,
    required this.use24HourFormat,
    required this.highContrastMode,
    this.enableDebugDiagnostics = kDebugMode && kShowSecurityDiagnostics,
    this.showDiagnosticsOverride,
    this.onOpenSecurityDiagnostics,
    required this.onToggle24Hour,
    required this.onToggleHighContrast,
    required this.onSelectAlarmHomeCity,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bool shouldShowDiagnostics =
        showDiagnosticsOverride ??
        (enableDebugDiagnostics && kDebugMode && kShowSecurityDiagnostics);

    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 84),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.strokeSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Settings & Guide',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        GlassButton.iconOnly(
                          icon: Icons.close,
                          semanticLabel: 'Close settings',
                          tooltip: 'Close',
                          onPressed: onClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '24-Hour Time Format',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                'Display 13:00 instead of 1:00 PM',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: use24HourFormat,
                          onChanged: onToggle24Hour,
                          activeColor: palette.accentPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'High-Contrast Legibility Mode',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                'Maximise text contrast against frosted backgrounds',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: highContrastMode,
                          onChanged: onToggleHighContrast,
                          activeColor: palette.accentPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'HOME REFERENCE CITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: alarmHomeCity.id,
                      isExpanded: true,
                      dropdownColor: palette.surfaceElevated,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: palette.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: kWorldCities
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(
                                '${c.name}, ${c.country} (${c.tzCode})',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (cid) {
                        if (cid == null) return;
                        final selected = kWorldCities.firstWhere(
                          (c) => c.id == cid,
                          orElse: () => kWorldCities[0],
                        );
                        onSelectAlarmHomeCity(selected);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'TIME & FOCUS GUIDE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.strokeSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• Focus Interval (24 Minutes): A 24-minute structured focus session, dividing the 24-hour day into 60 manageable working intervals.',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• Short Sprint (12 Minutes): A 12-minute sprint interval, designed for rapid task bursts, quick breaks, or gentle alarm snoozes.',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• Pre-Dawn Window (96m–48m Before Sunrise): The twilight interval preceding sunrise (${alarmEphem.sunriseFormatted}), calibrated for morning wakefulness and routine.',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Debug-only diagnostics button (hidden by default; visible only when SHOW_SECURITY_DIAGNOSTICS or override is true)
                    if (shouldShowDiagnostics &&
                        onOpenSecurityDiagnostics != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GlassButton.secondary(
                          key: const Key(
                            'open_debug_security_diagnostics_button',
                          ),
                          palette: palette,
                          onPressed: onOpenSecurityDiagnostics,
                          icon: Icons.bug_report_outlined,
                          label: 'Developer Security Diagnostics (Debug Only)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
