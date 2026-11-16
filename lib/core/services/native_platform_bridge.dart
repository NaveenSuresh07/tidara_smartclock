import 'dart:io';
import 'package:flutter/services.dart';
import '../ephemeris/noaa_ephemeris.dart';
import '../../models/horological_models.dart';

typedef AudioTrackItem = Map<String, String>;

class NativePlatformBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.tidara.smartclock/native_bridge',
  );
  static final Map<String, String> _customAudioPathByName = <String, String>{};
  static String? _presetAudioDirectory;
  static int lastScheduledAlarmCount = 0;

  static void setPresetAudioDirectory(String path) {
    _presetAudioDirectory = path;
  }

  static void registerCustomAudioPath(String displayName, String durablePath) {
    if (displayName.isNotEmpty && durablePath.isNotEmpty) {
      _customAudioPathByName[displayName] = durablePath;
    }
  }

  static String? resolveAudioPathForLabel(String soundName) {
    final customPath = _customAudioPathByName[soundName];
    if (customPath != null && customPath.isNotEmpty) {
      return customPath;
    }
    return resolvePresetAudioPath(soundName);
  }

  static String? resolvePresetAudioPath(String soundName) {
    final dir = _presetAudioDirectory;
    final lower = soundName.toLowerCase();
    String? fileName;
    if (lower.contains('432') ||
        lower.contains('tibet') ||
        lower.contains('bowl') ||
        lower.contains('gong')) {
      fileName = 'preset_432hz.wav';
    } else if (lower.contains('528') ||
        lower.contains('solfeggio') ||
        lower.contains('chime')) {
      fileName = 'preset_528hz.wav';
    } else if (lower.contains('639') ||
        lower.contains('dawn') ||
        lower.contains('resonance')) {
      fileName = 'preset_639hz.wav';
    }

    if (fileName != null && dir != null && dir.isNotEmpty) {
      final file = File('$dir${Platform.pathSeparator}$fileName');
      if (file.existsSync()) {
        return file.absolute.path;
      }
    }
    return null;
  }

  static Map<String, String> exportCustomAudioMap() =>
      Map<String, String>.from(_customAudioPathByName);

  static void importCustomAudioMap(Map<String, dynamic>? raw) {
    if (raw == null) return;
    raw.forEach((k, v) {
      if (v is String && v.isNotEmpty) {
        _customAudioPathByName[k] = v;
      }
    });
  }

  static Future<String?> getDurableStorageDir() async {
    try {
      return await _channel.invokeMethod<String>('getDurableStorageDir');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> requestAlarmAndNotificationPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'requestAlarmAndNotificationPermissions',
      );
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<AudioTrackItem?> pickAudioFileFromDevice() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'pickAudioFileFromDevice',
      );
      if (raw is Map) {
        final name = (raw['name'] ?? '').toString().trim();
        final path = (raw['path'] ?? '').toString().trim();
        if (name.isNotEmpty && path.isNotEmpty) {
          registerCustomAudioPath(name, path);
          return <String, String>{'name': name, 'path': path};
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static void Function(Map<String, dynamic> alarmData)? onRingingAlarmTriggered;
  static void Function(String action, int alarmId)?
  onNotificationActionReceived;
  static bool _handlerInitialized = false;

  static void initializeMethodCallHandler() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onRingingAlarmTriggered':
          if (call.arguments is Map) {
            final map = Map<String, dynamic>.from(call.arguments as Map);
            onRingingAlarmTriggered?.call(map);
          }
          break;
        case 'onNotificationAction':
          if (call.arguments is Map) {
            final action = (call.arguments['action'] ?? '').toString();
            final alarmId = (call.arguments['alarmId'] as num?)?.toInt() ?? 0;
            onNotificationActionReceived?.call(action, alarmId);
          }
          break;
      }
    });
  }

  static Future<Map<String, dynamic>?> getInitialRingingAlarm() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getInitialRingingAlarm',
      );
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearKeepScreenOn() async {
    try {
      await _channel.invokeMethod<bool>('clearKeepScreenOn');
    } catch (_) {}
  }

  static Future<Map<String, bool>> getAlarmPermissionStatus() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getAlarmPermissionStatus',
      );
      if (raw != null) {
        return {
          'canScheduleExact': raw['canScheduleExact'] == true,
          'notificationsEnabled': raw['notificationsEnabled'] == true,
          'alarmChannelValid': raw['alarmChannelValid'] == true,
          'canUseFullScreenIntent': raw['canUseFullScreenIntent'] == true,
        };
      }
    } catch (_) {}
    return {
      'canScheduleExact': true,
      'notificationsEnabled': true,
      'alarmChannelValid': true,
      'canUseFullScreenIntent': true,
    };
  }

  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<bool>('openNotificationSettings');
    } catch (_) {}
  }

  static Future<void> openAlarmChannelSettings() async {
    try {
      await _channel.invokeMethod<bool>('openAlarmChannelSettings');
    } catch (_) {}
  }

  static Future<void> openFullScreenIntentSettings() async {
    try {
      await _channel.invokeMethod<bool>('openFullScreenIntentSettings');
    } catch (_) {}
  }

  static Future<bool> canScheduleExactAlarms() async {
    try {
      final res = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod<bool>('openExactAlarmSettings');
    } catch (_) {}
  }

  static Future<bool> scheduleExactAlarm({
    required int id,
    required DateTime triggerUtc,
    required String label,
    String? audioPath,
    String? timeFormatted,
    String? soundMeta,
    String? originalAlarmId,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('scheduleExactAlarm', {
        'id': id,
        'epochMillis': triggerUtc.millisecondsSinceEpoch,
        'label': label,
        'audioPath': audioPath ?? '',
        'timeFormatted': timeFormatted ?? '',
        'soundMeta': soundMeta ?? '',
        'originalAlarmId': originalAlarmId ?? '',
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelExactAlarm(int id) async {
    try {
      await _channel.invokeMethod<bool>('cancelExactAlarm', {'id': id});
    } catch (_) {}
  }

  /// Converts standard weekday string names (e.g. ['Mon', 'Tue']) to
  /// ISO weekday numbers (1 = Monday .. 7 = Sunday).
  static Set<int> mapWeekdayNamesToIndices(List<String> weekdays) {
    const map = {
      'mon': 1,
      'tue': 2,
      'wed': 3,
      'thu': 4,
      'fri': 5,
      'sat': 6,
      'sun': 7,
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    final result = <int>{};
    for (final day in weekdays) {
      final idx = map[day.trim().toLowerCase()];
      if (idx != null) {
        result.add(idx);
      }
    }
    return result;
  }

  /// Computes the next UTC trigger DateTime for an alarm in [cityOffsetMinutes]
  /// respecting optional [activeWeekdays] (1 = Mon .. 7 = Sun).
  static DateTime computeNextAlarmTriggerUtc({
    required int hour,
    required int minute,
    required int cityOffsetMinutes,
    required DateTime nowUtc,
    Set<int>? activeWeekdays,
  }) {
    final cityNow = nowUtc.toUtc().add(Duration(minutes: cityOffsetMinutes));
    for (int dayDelta = 0; dayDelta <= 7; dayDelta++) {
      final candidateCityDate = cityNow.add(Duration(days: dayDelta));
      final candidateCityWall = DateTime.utc(
        candidateCityDate.year,
        candidateCityDate.month,
        candidateCityDate.day,
        hour,
        minute,
      );
      if (!candidateCityWall.isAfter(cityNow)) {
        continue;
      }
      if (activeWeekdays != null &&
          activeWeekdays.isNotEmpty &&
          !activeWeekdays.contains(candidateCityWall.weekday)) {
        continue;
      }
      return candidateCityWall.subtract(Duration(minutes: cityOffsetMinutes));
    }
    return nowUtc.toUtc().add(const Duration(days: 1));
  }

  /// Synchronizes all user alarms with Android's native AlarmManager using
  /// strongly typed AlarmRhythm properties. Eliminates dynamic reflection-by-exception.
  static Future<int> syncAlarmsWithOsScheduler({
    required List<AlarmRhythm> alarms,
    required WorldCity homeCity,
    DateTime? referenceUtc,
  }) async {
    final nowUtc = (referenceUtc ?? DateTime.now()).toUtc();
    final offsetMin = homeCity.effectiveOffsetMinutes(nowUtc);
    int scheduledCount = 0;

    for (final alarm in alarms) {
      final numericId = (alarm.id.hashCode & 0x7fffffff) % 90000 + 1000;
      if (!alarm.enabled) {
        await cancelExactAlarm(numericId);
        continue;
      }

      final int totalMin = alarm.wakeMinutes24;
      final Set<int> weekdays = mapWeekdayNamesToIndices(alarm.weekdays);
      final int hour = (totalMin ~/ 60) % 24;
      final int minute = totalMin % 60;

      final triggerUtc = computeNextAlarmTriggerUtc(
        hour: hour,
        minute: minute,
        cityOffsetMinutes: offsetMin,
        nowUtc: nowUtc,
        activeWeekdays: weekdays.isEmpty ? null : weekdays,
      );

      final customAudioPath = alarm.useCustomAudio
          ? resolveAudioPathForLabel(alarm.soundMeta)
          : resolvePresetAudioPath(alarm.soundMeta);

      final label = alarm.title.trim().isNotEmpty
          ? alarm.title.trim()
          : 'Tidara Smart Alarm';

      final String timeFormatted = CircadianEphemeris.formatMinutes12h(
        totalMin,
        use24Hour: false,
      );

      await scheduleExactAlarm(
        id: numericId,
        triggerUtc: triggerUtc,
        label: label,
        audioPath: customAudioPath,
        timeFormatted: timeFormatted,
        soundMeta: alarm.soundMeta,
        originalAlarmId: alarm.id,
      );
      scheduledCount++;
    }

    lastScheduledAlarmCount = scheduledCount;
    return scheduledCount;
  }

  static Future<List<AudioTrackItem>> listDeviceAudio() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listDeviceAudio');
      if (raw == null) {
        return const [];
      }
      final list = <AudioTrackItem>[];
      for (final e in raw) {
        if (e is Map) {
          final name = (e['name'] ?? 'Track').toString();
          final path = (e['path'] ?? '').toString();
          if (path.isNotEmpty) {
            registerCustomAudioPath(name, path);
            list.add(<String, String>{'name': name, 'path': path});
          }
        }
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> playAudioFile(String path, {bool loop = false}) async {
    try {
      final res = await _channel.invokeMethod<bool>('playAudioFile', {
        'path': path,
        'loop': loop,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> playWavBytes(
    Uint8List wavBytes, {
    bool loop = false,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('playWavBytes', {
        'wavBytes': wavBytes,
        'loop': loop,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopAudio() async {
    try {
      await _channel.invokeMethod<bool>('stopAudio');
    } catch (_) {}
  }
}
