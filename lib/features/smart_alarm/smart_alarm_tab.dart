import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/ephemeris/noaa_ephemeris.dart';
import '../../core/theme/tidara_palette.dart';
import '../../models/horological_models.dart';
import '../../shared/widgets/liquid_glass_components.dart';
import 'alarm_sheet_coordinator.dart';
import 'sunrise_arc_dial.dart';

class DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  const DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.2,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth;
}

class SmartAlarmTab extends StatelessWidget {
  final TidaraPalette palette;
  final CircadianEphemeris alarmEphem;
  final WorldCity alarmHomeCity;
  final int wakeMinutes;
  final List<AlarmRhythm> alarms;
  final bool use24HourFormat;
  final bool plainLanguageVedic;
  final String? customMusicName;
  final ValueChanged<int> onWakeMinutesChanged;
  final ValueChanged<AlarmRhythm> onSaveAlarm;
  final ValueChanged<AlarmRhythm> onAddAlarm;
  final ValueChanged<String> onDeleteAlarm;
  final void Function(int index, AlarmRhythm alarm) onInsertAlarmAt;
  final void Function(int index, AlarmRhythm alarm, bool enabled) onToggleAlarm;
  final void Function({
    String? alarmId,
    String? title,
    String? time,
    String? soundMeta,
    bool? useCustomAudio,
    bool isPreview,
  })
  onTriggerDawnPreview;
  final Future<String?> Function() onSelectPhoneMusic;
  final bool canScheduleExact;
  final bool notificationsEnabled;
  final bool alarmChannelValid;
  final bool canUseFullScreenIntent;
  final VoidCallback? onOpenExactAlarmSettings;
  final VoidCallback? onOpenNotificationSettings;
  final VoidCallback? onOpenAlarmChannelSettings;
  final VoidCallback? onOpenFullScreenIntentSettings;
  final void Function(BuildContext context, {AlarmRhythm? editingAlarm})?
  onOpenAlarmSheet;

  const SmartAlarmTab({
    super.key,
    required this.palette,
    required this.alarmEphem,
    required this.alarmHomeCity,
    required this.wakeMinutes,
    required this.alarms,
    required this.use24HourFormat,
    required this.plainLanguageVedic,
    required this.customMusicName,
    required this.onWakeMinutesChanged,
    required this.onSaveAlarm,
    required this.onAddAlarm,
    required this.onDeleteAlarm,
    required this.onInsertAlarmAt,
    required this.onToggleAlarm,
    required this.onTriggerDawnPreview,
    required this.onSelectPhoneMusic,
    this.canScheduleExact = true,
    this.notificationsEnabled = true,
    this.alarmChannelValid = true,
    this.canUseFullScreenIntent = true,
    this.onOpenExactAlarmSettings,
    this.onOpenNotificationSettings,
    this.onOpenAlarmChannelSettings,
    this.onOpenFullScreenIntentSettings,
    this.onOpenAlarmSheet,
  });

  Widget? _buildPermissionBanner() {
    if (!canScheduleExact) {
      return _buildBannerCard(
        key: const Key('exact_alarm_banner'),
        message: 'Exact alarm permission required for precision wakeup.',
        buttonLabel: 'ENABLE',
        onPressed: onOpenExactAlarmSettings,
      );
    }
    if (!notificationsEnabled) {
      return _buildBannerCard(
        key: const Key('notifications_permission_banner'),
        message: 'Notification permission required to display ringing alarms.',
        buttonLabel: 'ENABLE',
        onPressed: onOpenNotificationSettings,
      );
    }
    if (!alarmChannelValid) {
      return _buildBannerCard(
        key: const Key('alarm_channel_banner'),
        message: 'Alarm notification channel is muted or lowered. Set to High.',
        buttonLabel: 'CONFIGURE',
        onPressed: onOpenAlarmChannelSettings,
      );
    }
    if (!canUseFullScreenIntent) {
      return _buildBannerCard(
        key: const Key('full_screen_intent_banner'),
        message: 'Full-screen alarm display over lock screen is disabled.',
        buttonLabel: 'ENABLE',
        onPressed: onOpenFullScreenIntentSettings,
      );
    }
    return null;
  }

  Widget _buildBannerCard({
    required Key key,
    required String message,
    required String buttonLabel,
    required VoidCallback? onPressed,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: palette.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GlassButton.chip(
            label: buttonLabel,
            isSelected: true,
            accentColor: Colors.amber,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }

  void _openAlarmBottomSheet(
    BuildContext context, {
    AlarmRhythm? editingAlarm,
  }) {
    if (onOpenAlarmSheet != null) {
      onOpenAlarmSheet!(context, editingAlarm: editingAlarm);
      return;
    }
    AlarmSheetCoordinator.showAlarmSheet(
      context,
      editingAlarm: editingAlarm,
      defaultWakeMinutes: wakeMinutes,
      sunriseMinutesFromMidnight: alarmEphem.sunriseLocalMinutes,
      sunsetMinutesFromMidnight: alarmEphem.sunsetLocalMinutes,
      customMusicName: customMusicName,
      palette: palette,
      onSelectPhoneMusic: onSelectPhoneMusic,
      onTriggerDawnPreview: onTriggerDawnPreview,
      onDeleteAlarm: onDeleteAlarm,
      onSaveAlarm: onSaveAlarm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String dialTimeFormatted = CircadianEphemeris.formatMinutes12h(
      wakeMinutes,
      use24Hour: use24HourFormat,
    );
    final int windDownMinutes = (wakeMinutes - 465 + 1440) % 1440;
    final String windDownFormatted = CircadianEphemeris.formatMinutes12h(
      windDownMinutes,
      use24Hour: use24HourFormat,
    );

    return SingleChildScrollView(
      key: const ValueKey('screen-alarm'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_buildPermissionBanner() != null) _buildPermissionBanner()!,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarms & Rhythms',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sunrise in ${alarmHomeCity.name} · ${alarmEphem.sunriseFormatted}',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GlassButton.chip(
                label: 'Sunrise Tone',
                icon: Icons.wb_sunny_outlined,
                isSelected: false,
                semanticLabel: 'Preview sunrise tone',
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                onPressed: () {
                  onTriggerDawnPreview(
                    alarmId: alarms.isNotEmpty ? alarms.first.id : null,
                    title: alarms.isNotEmpty
                        ? alarms.first.title
                        : 'Solar Awakening',
                    time: dialTimeFormatted,
                    soundMeta: alarms.isNotEmpty
                        ? alarms.first.soundMeta
                        : 'Soft gong | 15m gradual dawn swell',
                    useCustomAudio: alarms.isNotEmpty
                        ? alarms.first.useCustomAudio
                        : false,
                    isPreview: true,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          SunriseArcDialWidget(
            wakeMinutesFromMidnight: wakeMinutes,
            sunriseMinutesFromMidnight: alarmEphem.sunriseLocalMinutes,
            palette: palette,
            use24Hour: use24HourFormat,
            plainLanguage: plainLanguageVedic,
            onChangeWakeMinutes: onWakeMinutesChanged,
          ),
          const SizedBox(height: 10),

          if (alarms.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.strokeSubtle),
              ),
              child: Column(
                children: [
                  Text(
                    'No Active Alarms',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Drag the dial above to choose a time and set your alarm below',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassButton.primary(
                    label: 'Set $dialTimeFormatted Alarm',
                    icon: Icons.alarm_add,
                    iconSize: 16,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      HorologicalAudioEngine.instance.strikeSingingBowl(
                        duration: 2.8,
                      );
                      onAddAlarm(
                        AlarmRhythm(
                          id: 'alarm-${DateTime.now().millisecondsSinceEpoch}',
                          title: 'Solar Awakening',
                          weekdays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                          soundMeta: 'Soft gong | 15m gradual dawn light',
                          useCustomAudio: false,
                          enabled: true,
                          wakeMinutes24: wakeMinutes,
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          else
            ...alarms.asMap().entries.map((entry) {
              final int idx = entry.key;
              final AlarmRhythm alarm = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      _openAlarmBottomSheet(context, editingAlarm: alarm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.strokeSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alarm.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alarm.formatSchedule(
                                  use24Hour: use24HourFormat,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.textSecondary,
                                  fontFeatures: const [
                                    ui.FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alarm.soundMeta,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: alarm.enabled
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: alarm.enabled
                                      ? palette.accentPrimary
                                      : palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GlassButton.iconOnly(
                          tooltip: 'Delete alarm',
                          semanticLabel: 'Delete alarm',
                          icon: Icons.delete_outline,
                          iconSize: 15,
                          isCircle: true,
                          width: 28,
                          height: 28,
                          minWidth: 48,
                          minHeight: 48,
                          isDestructive: true,
                          onPressed: () {
                            HorologicalAudioEngine.instance.playEscapementClick(
                              pitchHz: 760,
                            );
                            onDeleteAlarm(alarm.id);
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 5),
                                content: Text('Deleted "${alarm.title}"'),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  textColor: palette.accentPrimary,
                                  onPressed: () {
                                    onInsertAlarmAt(idx, alarm);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        Semantics(
                          toggled: alarm.enabled,
                          label: 'Toggle ${alarm.title}',
                          child: GestureDetector(
                            onTap: () {
                              final bool next = !alarm.enabled;
                              if (next) {
                                HorologicalAudioEngine.instance
                                    .strikeSingingBowl(duration: 2.4);
                              } else {
                                HorologicalAudioEngine.instance
                                    .playEscapementClick(pitchHz: 780);
                              }
                              onToggleAlarm(idx, alarm, next);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 24,
                              padding: const EdgeInsets.all(2),
                              alignment: alarm.enabled
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: alarm.enabled
                                    ? palette.accentPrimary
                                    : palette.strokeSubtle,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(height: 4),

          // Add Custom Rhythm or Yantra Alarm Button
          GlassButton(
            borderRadius: BorderRadius.circular(14),
            padding: EdgeInsets.zero,
            customBackgroundColor: Colors.transparent,
            customBorderColor: Colors.transparent,
            onPressed: () => _openAlarmBottomSheet(context),
            semanticLabel: 'Add Custom Alarm',
            child: CustomPaint(
              painter: DashedRRectPainter(
                color: palette.strokeSubtle,
                radius: 14,
              ),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_alarm_rounded,
                      size: 17,
                      color: palette.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Add Custom Alarm',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Optimal Sleep Window Card
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HorologicalAudioEngine.instance.strikeSingingBowl(duration: 2.6);
              final int existingIdx = alarms.indexWhere(
                (a) => a.title == 'Optimal Sleep Wind-Down',
              );
              final AlarmRhythm windAlarm = AlarmRhythm(
                id: existingIdx >= 0
                    ? alarms[existingIdx].id
                    : 'alarm-winddown-${DateTime.now().millisecondsSinceEpoch}',
                title: 'Optimal Sleep Wind-Down',
                weekdays: const [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ],
                soundMeta: '432Hz Singing Bowl | 15m dawn swell',
                useCustomAudio: false,
                enabled: true,
                wakeMinutes24: windDownMinutes,
              );
              onSaveAlarm(windAlarm);
            },
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.strokeSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: palette.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Optimal Sleep Window',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          'Wind-down at $windDownFormatted | 7h 45m target',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final bool isWindDownActive = alarms.any(
                        (a) =>
                            a.title == 'Optimal Sleep Wind-Down' && a.enabled,
                      );
                      return Text(
                        isWindDownActive ? 'Active' : '+ Set',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: palette.accentPrimary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
