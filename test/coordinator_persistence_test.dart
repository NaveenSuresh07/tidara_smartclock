import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/services/state_coordinator.dart';
import 'package:tidara_smartclock/core/services/storage_repository.dart';
import 'package:tidara_smartclock/features/chronometer/cubit/chronometer_cubit.dart';
import 'package:tidara_smartclock/features/focus_timer/cubit/focus_timer_cubit.dart';
import 'package:tidara_smartclock/features/shell/cubit/app_preferences_cubit.dart';
import 'package:tidara_smartclock/features/smart_alarm/cubit/alarm_cubit.dart';
import 'package:tidara_smartclock/features/world_clock/cubit/world_clock_cubit.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

class MockFailingStorageRepository implements HorologicalStorageRepository {
  bool shouldThrowOnSave = false;
  bool shouldReturnFalseOnSave = false;
  int saveCount = 0;
  Map<String, dynamic>? lastSavedPayload;
  Map<String, dynamic>? syncStateToReturn;
  Map<String, dynamic>? asyncStateToReturn;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> clearAll() async {
    lastSavedPayload = null;
  }

  @override
  Map<String, dynamic>? loadState() => syncStateToReturn;

  @override
  Future<Map<String, dynamic>?> loadStateAsync() async => asyncStateToReturn;

  @override
  Future<bool> saveState(Map<String, dynamic> payload) async {
    saveCount++;
    if (shouldThrowOnSave) {
      throw Exception('Simulated filesystem I/O fault');
    }
    if (shouldReturnFalseOnSave) {
      return false;
    }
    lastSavedPayload = Map<String, dynamic>.from(payload);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.tidara.smartclock/native_bridge'),
          (MethodCall call) async => true,
        );
  });

  group('HorologicalStateCoordinator — Debounce & Persistence Robustness', () {
    late MockFailingStorageRepository storage;
    late AlarmCubit alarmCubit;
    late WorldClockCubit worldClockCubit;
    late ChronometerCubit chronoCubit;
    late FocusTimerCubit focusCubit;
    late AppPreferencesCubit prefCubit;
    late HorologicalStateCoordinator coordinator;

    setUp(() {
      storage = MockFailingStorageRepository();
      alarmCubit = AlarmCubit(initialHomeCity: kWorldCities[0]);
      worldClockCubit = WorldClockCubit(initialCity: kWorldCities[0]);
      chronoCubit = ChronometerCubit();
      focusCubit = FocusTimerCubit();
      prefCubit = AppPreferencesCubit();

      coordinator = HorologicalStateCoordinator(
        storage: storage,
        alarmCubit: alarmCubit,
        worldClockCubit: worldClockCubit,
        chronometerCubit: chronoCubit,
        focusTimerCubit: focusCubit,
        preferencesCubit: prefCubit,
      );
    });

    tearDown(() {
      coordinator.dispose();
      alarmCubit.close();
      worldClockCubit.close();
      chronoCubit.close();
      focusCubit.close();
      prefCubit.close();
    });

    test(
      '1. Debounce coalesces rapid sequential emissions into single disk save',
      () async {
        expect(storage.saveCount, 0);

        coordinator.schedulePersist();
        coordinator.schedulePersist();
        coordinator.schedulePersist();

        // Immediately after, save count should still be 0 because of 300ms debounce
        expect(storage.saveCount, 0);

        // Wait 350ms for debounce timer to fire
        await Future<void>.delayed(const Duration(milliseconds: 350));

        // Should have saved exactly once
        expect(storage.saveCount, 1);
        expect(storage.lastSavedPayload, isNotNull);

        // Now verify a real Cubit emission triggers schedulePersist
        prefCubit.toggle24HourFormat(true);
        await Future<void>.delayed(const Duration(milliseconds: 350));

        expect(storage.saveCount, 2);
        expect(storage.lastSavedPayload!['use24HourFormat'], isTrue);
      },
    );

    test(
      '2. Handles storage throw exception gracefully without unhandled crashes',
      () async {
        storage.shouldThrowOnSave = true;

        // persistAll returns false when underlying storage throws
        final result = await coordinator.persistAll();
        expect(result, isFalse);
      },
    );

    test('3. Handles storage returning false gracefully', () async {
      storage.shouldReturnFalseOnSave = true;

      final result = await coordinator.persistAll();
      expect(result, isFalse);
    });

    test(
      '4. Native platform bridge error during alarm sync does not crash persist',
      () async {
        // Configure platform channel to throw
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.tidara.smartclock/native_bridge'),
              (MethodCall call) async {
                if (call.method == 'scheduleExactAlarm') {
                  throw PlatformException(
                    code: 'SECURITY_EXCEPTION',
                    message: 'No permission',
                  );
                }
                return true;
              },
            );

        final result = await coordinator.persistAll();
        expect(result, isTrue); // Storage save still succeeded
      },
    );

    test(
      '5. HydrateAll handles malformed, partial or corrupted payloads without crash',
      () async {
        storage.syncStateToReturn = {
          'cityId': 'non_existent_city_xyz',
          'customCities': 'invalid_not_a_list',
          'pinnedCityIds': 'invalid_not_a_list',
          'wakeMinutes': 'invalid_string_wake',
          'alarms': ['invalid_alarm_type'],
          'laps': 12345,
          'highContrastMode': 'not_a_bool',
          'use24HourFormat': null,
        };

        await coordinator.hydrateAll();

        // Fallback city applied
        expect(worldClockCubit.state.selectedCity, isNotNull);
        // Fallback preferences preserved
        expect(prefCubit.state.highContrastMode, isFalse);
      },
    );

    test('6. Dispose cancels active debounce timer safely', () async {
      coordinator.schedulePersist();
      // Dispose immediately before timer fires
      coordinator.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 350));
      // Save should never have fired
      expect(storage.saveCount, 0);
    });

    test(
      '7. Full Cubit hydration and persistence across all entities preserves complete state',
      () async {
        const customCity = WorldCity(
          id: 'custom_helsinki',
          name: 'Helsinki',
          country: 'Finland',
          stdTzCode: 'EET',
          dstTzCode: 'EEST',
          stdOffsetMinutes: 120,
          dstOffsetMinutes: 180,
          dstRegion: 'EU',
          lat: 60.1699,
          lon: 24.9384,
          isCustom: true,
        );

        const customAlarm = AlarmRhythm(
          id: 'nordic_alarm',
          title: 'Nordic Awakening',
          wakeMinutes24: 390,
          soundMeta: 'Nordic Cedar',
          weekdays: ['Mon', 'Wed', 'Fri'],
          useCustomAudio: true,
          enabled: true,
        );

        const testLap = ChronoLap(
          id: 1,
          number: '01',
          durationMs: 12400,
          formatted: '00:12.40',
        );

        // Populate all Cubits with non-default state
        worldClockCubit.selectCity(customCity);
        worldClockCubit.togglePinCity(customCity.id);

        alarmCubit.setHomeCity(kWorldCities.firstWhere((c) => c.id == 'tokyo'));
        alarmCubit.setWakeMinutes(390);
        alarmCubit.addAlarm(customAlarm);

        chronoCubit.hydrate([testLap]);

        focusCubit.setCustomMusic('Cedar Wind.mp3');
        focusCubit.changeSoundscape('tanpura');
        focusCubit.setCustomDuration(30);

        prefCubit.toggleTheme();
        prefCubit.toggle24HourFormat(true);
        prefCubit.toggleHighContrast(true);
        prefCubit.togglePlainLanguage(true);

        // Persist immediately via coordinator
        final persistOk = await coordinator.persistAll();
        expect(persistOk, isTrue);
        expect(storage.lastSavedPayload, isNotNull);

        final payload = storage.lastSavedPayload!;
        expect(payload['cityId'], 'custom_helsinki');
        expect(payload['alarmHomeCityId'], 'tokyo');
        expect(payload['selectedCityData'], isNotNull);
        expect(payload['use24HourFormat'], isTrue);
        expect(payload['highContrastMode'], isTrue);
        expect(payload['plainLanguageVedic'], isTrue);

        // Now create a fresh set of Cubits and a new coordinator to simulate app reboot
        final freshStorage = MockFailingStorageRepository()
          ..syncStateToReturn = payload;
        final freshWorldClock = WorldClockCubit(initialCity: kWorldCities[0]);
        final freshAlarm = AlarmCubit(initialHomeCity: kWorldCities[0]);
        final freshChrono = ChronometerCubit();
        final freshFocus = FocusTimerCubit();
        final freshPrefs = AppPreferencesCubit();

        final freshCoordinator = HorologicalStateCoordinator(
          storage: freshStorage,
          alarmCubit: freshAlarm,
          worldClockCubit: freshWorldClock,
          chronometerCubit: freshChrono,
          focusTimerCubit: freshFocus,
          preferencesCubit: freshPrefs,
        );

        await freshCoordinator.hydrateAll();

        // Verify all state was restored precisely
        expect(freshWorldClock.state.selectedCity.name, 'Helsinki');
        expect(freshWorldClock.state.selectedCity.isCustom, isTrue);
        expect(
          freshWorldClock.state.pinnedCityIds,
          contains('custom_helsinki'),
        );

        expect(freshAlarm.state.homeCity.id, 'tokyo');
        expect(freshAlarm.state.wakeMinutes, 390);
        expect(
          freshAlarm.state.alarms.any((a) => a.id == 'nordic_alarm'),
          isTrue,
        );

        expect(freshChrono.state.laps.length, 1);
        expect(freshChrono.state.laps.first.formatted, '00:12.40');

        expect(freshFocus.state.customTotalSec, 1800);
        expect(freshFocus.state.activeSoundscapeId, 'tanpura');
        expect(freshFocus.state.customMusicName, 'Cedar Wind.mp3');

        expect(freshPrefs.state.use24HourFormat, isTrue);
        expect(freshPrefs.state.highContrastMode, isTrue);
        expect(freshPrefs.state.plainLanguageVedic, isTrue);

        freshCoordinator.dispose();
        freshWorldClock.close();
        freshAlarm.close();
        freshChrono.close();
        freshFocus.close();
        freshPrefs.close();
      },
    );
  });
}
