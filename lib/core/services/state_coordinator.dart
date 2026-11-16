import 'dart:async';
import '../../features/chronometer/cubit/chronometer_cubit.dart';
import '../../features/focus_timer/cubit/focus_timer_cubit.dart';
import '../../features/shell/cubit/app_preferences_cubit.dart';
import '../../features/smart_alarm/cubit/alarm_cubit.dart';
import '../../features/world_clock/cubit/world_clock_cubit.dart';
import '../../models/horological_models.dart';
import '../services/native_platform_bridge.dart';
import '../services/storage_repository.dart';

class HorologicalStateCoordinator {
  final HorologicalStorageRepository storage;
  final AlarmCubit alarmCubit;
  final WorldClockCubit worldClockCubit;
  final ChronometerCubit chronometerCubit;
  final FocusTimerCubit focusTimerCubit;
  final AppPreferencesCubit preferencesCubit;

  Timer? _debouncePersistTimer;
  late final StreamSubscription _prefSub;
  late final StreamSubscription _alarmSub;
  late final StreamSubscription _worldSub;
  late final StreamSubscription _chronoSub;
  late final StreamSubscription _focusSub;

  HorologicalStateCoordinator({
    required this.storage,
    required this.alarmCubit,
    required this.worldClockCubit,
    required this.chronometerCubit,
    required this.focusTimerCubit,
    required this.preferencesCubit,
  }) {
    _prefSub = preferencesCubit.stream.listen((_) => schedulePersist());
    _alarmSub = alarmCubit.stream.listen((_) => schedulePersist());
    _worldSub = worldClockCubit.stream.listen((_) => schedulePersist());
    _chronoSub = chronometerCubit.stream.listen((_) => schedulePersist());
    _focusSub = focusTimerCubit.stream.listen((_) => schedulePersist());
  }

  void schedulePersist() {
    _debouncePersistTimer?.cancel();
    _debouncePersistTimer = Timer(const Duration(milliseconds: 300), () {
      persistAll();
    });
  }

  Future<void> hydrateAll() async {
    // 1. Synchronous initial load if available
    final initialSync = storage.loadState();
    if (initialSync != null) {
      _applyLoadedPayload(initialSync);
    }
    // 2. Asynchronous durable load from authenticated AES-256-GCM vault
    final durableAsync = await storage.loadStateAsync();
    if (durableAsync != null) {
      _applyLoadedPayload(durableAsync);
    }
  }

  void _applyLoadedPayload(Map<String, dynamic> data) {
    // 1. World Clock
    List<WorldCity> customCities = [];
    if (data['customCities'] is List) {
      customCities = (data['customCities'] as List)
          .whereType<Map<String, dynamic>>()
          .map(WorldCity.fromJson)
          .toList();
    }
    final String? cityId = data['cityId']?.toString();
    WorldCity? selectedCity;
    if (data['selectedCityData'] is Map<String, dynamic>) {
      selectedCity = WorldCity.fromJson(
        data['selectedCityData'] as Map<String, dynamic>,
      );
    } else if (cityId != null) {
      selectedCity = [
        ...kWorldCities,
        ...customCities,
      ].firstWhere((c) => c.id == cityId, orElse: () => kWorldCities[0]);
    }
    List<String>? pinnedCityIds;
    if (data['pinnedCityIds'] is List) {
      pinnedCityIds = (data['pinnedCityIds'] as List)
          .map((e) => e.toString())
          .toList();
    }
    worldClockCubit.hydrate(
      selectedCity: selectedCity,
      pinnedCityIds: pinnedCityIds,
      customCities: customCities,
    );

    // 2. Alarm
    final String? alarmCityId = data['alarmHomeCityId']?.toString();
    WorldCity? alarmHomeCity;
    if (alarmCityId != null) {
      alarmHomeCity = kWorldCities.firstWhere(
        (c) => c.id == alarmCityId,
        orElse: () => kWorldCities[0],
      );
    }
    int? wakeMinutes;
    if (data['wakeMinutes'] is num) {
      wakeMinutes = (data['wakeMinutes'] as num).toInt();
    }
    List<AlarmRhythm>? alarms;
    if (data['alarms'] is List) {
      alarms = (data['alarms'] as List)
          .whereType<Map<String, dynamic>>()
          .map(AlarmRhythm.fromJson)
          .toList();
    }
    alarmCubit.hydrate(
      alarms: alarms,
      homeCity: alarmHomeCity,
      wakeMinutes: wakeMinutes,
    );

    // 3. Chronometer
    if (data['laps'] is List) {
      final laps = (data['laps'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ChronoLap.fromJson)
          .toList();
      chronometerCubit.hydrate(laps);
    }

    // 4. Focus Timer
    String? activePresetId = data['activePresetId']?.toString();
    int? customTotalSec;
    if (data['customTotalSec'] is num) {
      customTotalSec = (data['customTotalSec'] as num).toInt();
    }
    String? activeSoundscapeId = data['activeSoundscapeId']?.toString();
    String? customMusicName = data['customMusicName']?.toString();
    int? completedGhatikas;
    if (data['completedGhatikas'] is num) {
      completedGhatikas = (data['completedGhatikas'] as num).toInt();
    }
    focusTimerCubit.hydrate(
      activePresetId: activePresetId,
      customTotalSec: customTotalSec,
      activeSoundscapeId: activeSoundscapeId,
      customMusicName: customMusicName,
      completedGhatikas: completedGhatikas,
    );

    // 5. Preferences
    preferencesCubit.hydrate(
      themePreference: data['themePreference']?.toString(),
      highContrastMode: data['highContrastMode'] is bool
          ? data['highContrastMode'] as bool
          : null,
      use24HourFormat: data['use24HourFormat'] is bool
          ? data['use24HourFormat'] as bool
          : null,
      plainLanguageVedic: data['plainLanguageVedic'] is bool
          ? data['plainLanguageVedic'] as bool
          : null,
    );
  }

  Future<bool> persistAll() async {
    try {
      final payload = <String, dynamic>{
        'cityId': worldClockCubit.state.selectedCity.id,
        'alarmHomeCityId': alarmCubit.state.homeCity.id,
        'customCities': worldClockCubit.state.customCities
            .map((c) => c.toJson())
            .toList(),
        'selectedCityData': worldClockCubit.state.selectedCity.isCustom
            ? worldClockCubit.state.selectedCity.toJson()
            : null,
        'pinnedCityIds': worldClockCubit.state.pinnedCityIds,
        'wakeMinutes': alarmCubit.state.wakeMinutes,
        'alarms': alarmCubit.state.alarms.map((a) => a.toJson()).toList(),
        'laps': chronometerCubit.state.laps.map((l) => l.toJson()).toList(),
        'activePresetId': focusTimerCubit.state.activePresetId,
        'customTotalSec': focusTimerCubit.state.customTotalSec,
        'activeSoundscapeId': focusTimerCubit.state.activeSoundscapeId,
        'customMusicName': focusTimerCubit.state.customMusicName,
        'themePreference': preferencesCubit.state.themePreference,
        'highContrastMode': preferencesCubit.state.highContrastMode,
        'use24HourFormat': preferencesCubit.state.use24HourFormat,
        'plainLanguageVedic': preferencesCubit.state.plainLanguageVedic,
        'completedGhatikas': focusTimerCubit.state.completedGhatikas,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final saved = await storage.saveState(payload);
      try {
        await NativePlatformBridge.syncAlarmsWithOsScheduler(
          alarms: alarmCubit.state.alarms,
          homeCity: alarmCubit.state.homeCity,
        );
      } catch (_) {
        // Platform sync failure must not disrupt state persistence
      }
      return saved;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _debouncePersistTimer?.cancel();
    _prefSub.cancel();
    _alarmSub.cancel();
    _worldSub.cancel();
    _chronoSub.cancel();
    _focusSub.cancel();
  }
}
