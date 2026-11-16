import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/audio/horological_audio_engine.dart';
import '../../../core/ephemeris/noaa_ephemeris.dart';
import '../../../core/services/native_platform_bridge.dart';
import '../../../models/horological_models.dart';

class AlarmState {
  final List<AlarmRhythm> alarms;
  final WorldCity homeCity;
  final int wakeMinutes;
  final Map<String, dynamic>? ringingAlarm;
  final String lastTriggeredMinuteKey;
  final bool isLoading;
  final bool canScheduleExact;
  final bool notificationsEnabled;
  final bool alarmChannelValid;
  final bool canUseFullScreenIntent;

  const AlarmState({
    this.alarms = const [],
    required this.homeCity,
    this.wakeMinutes = 330, // 5:30 AM
    this.ringingAlarm,
    this.lastTriggeredMinuteKey = '',
    this.isLoading = false,
    this.canScheduleExact = true,
    this.notificationsEnabled = true,
    this.alarmChannelValid = true,
    this.canUseFullScreenIntent = true,
  });

  AlarmState copyWith({
    List<AlarmRhythm>? alarms,
    WorldCity? homeCity,
    int? wakeMinutes,
    Map<String, dynamic>? ringingAlarm,
    bool clearRingingAlarm = false,
    String? lastTriggeredMinuteKey,
    bool? isLoading,
    bool? canScheduleExact,
    bool? notificationsEnabled,
    bool? alarmChannelValid,
    bool? canUseFullScreenIntent,
  }) {
    return AlarmState(
      alarms: alarms ?? this.alarms,
      homeCity: homeCity ?? this.homeCity,
      wakeMinutes: wakeMinutes ?? this.wakeMinutes,
      ringingAlarm: clearRingingAlarm
          ? null
          : (ringingAlarm ?? this.ringingAlarm),
      lastTriggeredMinuteKey:
          lastTriggeredMinuteKey ?? this.lastTriggeredMinuteKey,
      isLoading: isLoading ?? this.isLoading,
      canScheduleExact: canScheduleExact ?? this.canScheduleExact,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      alarmChannelValid: alarmChannelValid ?? this.alarmChannelValid,
      canUseFullScreenIntent:
          canUseFullScreenIntent ?? this.canUseFullScreenIntent,
    );
  }
}

class AlarmCubit extends Cubit<AlarmState> {
  final void Function()? onStateChanged;

  AlarmCubit({
    required WorldCity initialHomeCity,
    List<AlarmRhythm> initialAlarms = const [],
    int initialWakeMinutes = 330,
    this.onStateChanged,
  }) : super(
         AlarmState(
           homeCity: initialHomeCity,
           alarms: initialAlarms,
           wakeMinutes: initialWakeMinutes,
         ),
       );

  Future<void> checkExactAlarmPermission() async {
    final status = await NativePlatformBridge.getAlarmPermissionStatus();
    emit(
      state.copyWith(
        canScheduleExact: status['canScheduleExact'] ?? true,
        notificationsEnabled: status['notificationsEnabled'] ?? true,
        alarmChannelValid: status['alarmChannelValid'] ?? true,
        canUseFullScreenIntent: status['canUseFullScreenIntent'] ?? true,
      ),
    );
  }

  Future<void> checkAlarmPermissions() => checkExactAlarmPermission();

  void setWakeMinutes(int mins) {
    emit(state.copyWith(wakeMinutes: mins));
    onStateChanged?.call();
  }

  void setHomeCity(WorldCity city) {
    emit(state.copyWith(homeCity: city));
    NativePlatformBridge.syncAlarmsWithOsScheduler(
      alarms: state.alarms,
      homeCity: city,
    );
    onStateChanged?.call();
  }

  void saveAlarm(AlarmRhythm saved) {
    final updatedList = List<AlarmRhythm>.from(state.alarms);
    final int idx = updatedList.indexWhere((a) => a.id == saved.id);
    if (idx >= 0) {
      updatedList[idx] = saved;
    } else {
      updatedList.add(saved);
    }
    final nextWake = (saved.wakeMinutes24 >= 180 && saved.wakeMinutes24 <= 600)
        ? saved.wakeMinutes24
        : state.wakeMinutes;

    emit(state.copyWith(alarms: updatedList, wakeMinutes: nextWake));
    NativePlatformBridge.syncAlarmsWithOsScheduler(
      alarms: updatedList,
      homeCity: state.homeCity,
    );
    onStateChanged?.call();
  }

  void addAlarm(AlarmRhythm newAlarm) {
    final updatedList = List<AlarmRhythm>.from(state.alarms)..add(newAlarm);
    emit(state.copyWith(alarms: updatedList));
    NativePlatformBridge.syncAlarmsWithOsScheduler(
      alarms: updatedList,
      homeCity: state.homeCity,
    );
    onStateChanged?.call();
  }

  void deleteAlarm(String id) {
    final updatedList = state.alarms.where((a) => a.id != id).toList();
    emit(state.copyWith(alarms: updatedList));
    NativePlatformBridge.syncAlarmsWithOsScheduler(
      alarms: updatedList,
      homeCity: state.homeCity,
    );
    onStateChanged?.call();
  }

  void insertAlarmAt(int index, AlarmRhythm alarm) {
    final updatedList = List<AlarmRhythm>.from(state.alarms);
    updatedList.insert(index.clamp(0, updatedList.length), alarm);
    emit(state.copyWith(alarms: updatedList));
    NativePlatformBridge.syncAlarmsWithOsScheduler(
      alarms: updatedList,
      homeCity: state.homeCity,
    );
    onStateChanged?.call();
  }

  void toggleAlarm(int idx, AlarmRhythm alarm, bool enabled) {
    final updatedList = List<AlarmRhythm>.from(state.alarms);
    if (idx >= 0 && idx < updatedList.length) {
      updatedList[idx] = alarm.copyWith(
        enabled: enabled,
        clearSnooze: !enabled,
      );
      emit(state.copyWith(alarms: updatedList));
      NativePlatformBridge.syncAlarmsWithOsScheduler(
        alarms: updatedList,
        homeCity: state.homeCity,
      );
      onStateChanged?.call();
    }
  }

  void triggerDawnAwakening({
    String? alarmId,
    String title = 'Solar Awakening',
    String time = '05:30 AM',
    String soundMeta = 'Soft gong | 15m gradual dawn swell',
    bool useCustomAudio = false,
    bool isPreview = false,
  }) {
    emit(
      state.copyWith(
        ringingAlarm: {
          'alarmId': alarmId,
          'title': title,
          'time': time,
          'soundMeta': soundMeta,
          'useCustomAudio': useCustomAudio,
          'isPreview': isPreview,
        },
      ),
    );
    HorologicalAudioEngine.instance.startDawnAlarmLoop(
      useCustom: useCustomAudio,
    );
  }

  void dismissRingingAlarm({int snoozeMinutes = 0}) {
    HorologicalAudioEngine.instance.stopDawnAlarmLoop();
    HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1120);
    NativePlatformBridge.clearKeepScreenOn();
    NativePlatformBridge.stopAudio();
    final String? ringingId = state.ringingAlarm?['alarmId']?.toString();
    final bool isPreview = state.ringingAlarm?['isPreview'] == true;

    List<AlarmRhythm> updatedAlarms = state.alarms;
    if (ringingId != null && !isPreview) {
      final DateTime now = DateTime.now();
      final int targetSnoozeMins =
          (now.hour * 60 + now.minute + snoozeMinutes) % 1440;
      updatedAlarms = state.alarms.map((a) {
        if (a.id != ringingId) return a;
        if (snoozeMinutes > 0) {
          return a.copyWith(snoozedUntilMinutes24: targetSnoozeMins);
        } else {
          return a.copyWith(clearSnooze: true);
        }
      }).toList();
    }

    emit(state.copyWith(alarms: updatedAlarms, clearRingingAlarm: true));
    NativePlatformBridge.syncAlarmsWithOsScheduler(
      alarms: updatedAlarms,
      homeCity: state.homeCity,
    );
    onStateChanged?.call();
  }

  void evaluateScheduledAlarms(DateTime now, {bool use24HourFormat = false}) {
    final int currentMins24 = now.hour * 60 + now.minute;
    final String minuteKey =
        '${now.year}-${now.month}-${now.day}-$currentMins24';
    if (state.lastTriggeredMinuteKey == minuteKey) return;

    const List<String> weekdayNames = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final String todayName = weekdayNames[(now.weekday - 1).clamp(0, 6)];

    for (final AlarmRhythm a in state.alarms) {
      if (!a.enabled) continue;
      final bool timeMatch =
          a.wakeMinutes24 == currentMins24 ||
          (a.snoozedUntilMinutes24 != null &&
              a.snoozedUntilMinutes24 == currentMins24);
      final bool dayMatch =
          a.weekdays.contains(todayName) || a.snoozedUntilMinutes24 != null;

      if (timeMatch && dayMatch) {
        emit(state.copyWith(lastTriggeredMinuteKey: minuteKey));
        final int targetMinutes = a.snoozedUntilMinutes24 ?? a.wakeMinutes24;
        triggerDawnAwakening(
          alarmId: a.id,
          title: a.title,
          time: CircadianEphemeris.formatMinutes12h(
            targetMinutes,
            use24Hour: use24HourFormat,
          ),
          soundMeta: a.soundMeta,
          useCustomAudio: a.useCustomAudio,
          isPreview: false,
        );
        break;
      }
    }
  }

  void hydrate({
    List<AlarmRhythm>? alarms,
    WorldCity? homeCity,
    int? wakeMinutes,
  }) {
    final nextAlarms = alarms ?? state.alarms;
    final nextCity = homeCity ?? state.homeCity;
    emit(
      state.copyWith(
        alarms: nextAlarms,
        homeCity: nextCity,
        wakeMinutes: wakeMinutes ?? state.wakeMinutes,
      ),
    );
    NativePlatformBridge.syncAlarmsWithOsScheduler(
      alarms: nextAlarms,
      homeCity: nextCity,
    );
  }
}
