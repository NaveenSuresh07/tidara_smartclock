import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/theme/tidara_palette.dart';
import '../../models/horological_models.dart';
import 'tactile_alarm_sheets.dart';

/// Coordinator separating bottom sheet presentation logic from [SmartAlarmTab],
/// keeping [SmartAlarmTab] as a pure presentation widget.
class AlarmSheetCoordinator {
  const AlarmSheetCoordinator._();

  /// Displays the tactile alarm configuration sheet as a modal bottom sheet.
  static Future<void> showAlarmSheet(
    BuildContext context, {
    AlarmRhythm? editingAlarm,
    required int defaultWakeMinutes,
    required int sunriseMinutesFromMidnight,
    required int sunsetMinutesFromMidnight,
    required String? customMusicName,
    required TidaraPalette palette,
    required Future<String?> Function() onSelectPhoneMusic,
    required void Function({
      String? alarmId,
      String? title,
      String? time,
      String? soundMeta,
      bool? useCustomAudio,
      bool isPreview,
    })
    onTriggerDawnPreview,
    required ValueChanged<String> onDeleteAlarm,
    required ValueChanged<AlarmRhythm> onSaveAlarm,
  }) {
    HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1180);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return TactileAlarmBottomSheet(
          editingAlarm: editingAlarm,
          defaultWakeMinutes: defaultWakeMinutes,
          sunriseMinutesFromMidnight: sunriseMinutesFromMidnight,
          sunsetMinutesFromMidnight: sunsetMinutesFromMidnight,
          customMusicName: customMusicName,
          palette: palette,
          onSelectPhoneMusic: onSelectPhoneMusic,
          onTriggerDawnPreview: (previewMap) {
            Navigator.of(ctx).pop();
            onTriggerDawnPreview(
              alarmId: editingAlarm?.id,
              title: previewMap['title']?.toString() ?? 'Solar Awakening',
              time: previewMap['time']?.toString() ?? '05:30 AM',
              soundMeta:
                  previewMap['soundMeta']?.toString() ??
                  'Soft gong | 15m gradual dawn light',
              useCustomAudio: previewMap['useCustomAudio'] == true,
              isPreview: previewMap['isPreview'] ?? true,
            );
          },
          onDelete: editingAlarm == null
              ? null
              : (id) {
                  Navigator.of(ctx).pop();
                  onDeleteAlarm(id);
                },
          onSave: (savedAlarm) {
            Navigator.of(ctx).pop();
            onSaveAlarm(savedAlarm);
          },
        );
      },
    );
  }
}
