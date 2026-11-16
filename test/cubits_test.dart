import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/services/native_platform_bridge.dart';
import 'package:tidara_smartclock/features/chronometer/cubit/chronometer_cubit.dart';
import 'package:tidara_smartclock/features/focus_timer/cubit/focus_timer_cubit.dart';
import 'package:tidara_smartclock/features/shell/cubit/app_preferences_cubit.dart';
import 'package:tidara_smartclock/features/smart_alarm/cubit/alarm_cubit.dart';
import 'package:tidara_smartclock/features/world_clock/cubit/world_clock_cubit.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCity = kWorldCities.firstWhere((c) => c.name == 'Bengaluru');
  final newYorkCity = kWorldCities.firstWhere((c) => c.name == 'New York');
  final londonCity = kWorldCities.firstWhere((c) => c.name == 'London');

  group('AppPreferencesCubit Unit Tests', () {
    blocTest<AppPreferencesCubit, AppPreferencesState>(
      'cycles theme when toggleTheme is invoked',
      build: () => AppPreferencesCubit(),
      act: (cubit) {
        cubit.toggleTheme(); // light -> dark
        cubit.toggleTheme(); // dark -> system
      },
      expect: () => [
        predicate<AppPreferencesState>((s) => s.themePreference == 'dark'),
        predicate<AppPreferencesState>((s) => s.themePreference == 'system'),
      ],
    );

    blocTest<AppPreferencesCubit, AppPreferencesState>(
      'toggles 24 hour format, high contrast, plain language, and tab selection',
      build: () => AppPreferencesCubit(),
      act: (cubit) {
        cubit.toggle24HourFormat(true);
        cubit.toggleHighContrast(true);
        cubit.togglePlainLanguage(true);
        cubit.selectTab(0);
      },
      expect: () => [
        predicate<AppPreferencesState>((s) => s.use24HourFormat == true),
        predicate<AppPreferencesState>(
          (s) => s.use24HourFormat == true && s.highContrastMode == true,
        ),
        predicate<AppPreferencesState>(
          (s) =>
              s.use24HourFormat == true &&
              s.highContrastMode == true &&
              s.plainLanguageVedic == true,
        ),
        predicate<AppPreferencesState>(
          (s) =>
              s.use24HourFormat == true &&
              s.highContrastMode == true &&
              s.plainLanguageVedic == true &&
              s.activeTabIndex == 0,
        ),
      ],
    );

    blocTest<AppPreferencesCubit, AppPreferencesState>(
      'hydrates state correctly from snapshot values',
      build: () => AppPreferencesCubit(),
      act: (cubit) => cubit.hydrate(
        themePreference: 'dark',
        use24HourFormat: true,
        highContrastMode: true,
        plainLanguageVedic: false,
      ),
      expect: () => [
        predicate<AppPreferencesState>(
          (s) =>
              s.themePreference == 'dark' &&
              s.use24HourFormat == true &&
              s.highContrastMode == true &&
              s.plainLanguageVedic == false,
        ),
      ],
    );
  });

  group('AlarmCubit Unit Tests', () {
    const alarm1 = AlarmRhythm(
      id: 'alarm-test-1',
      title: 'Dawn Rise',
      wakeMinutes24: 360,
      soundMeta: 'Tibetan 432Hz',
      weekdays: ['Mon', 'Tue', 'Wed'],
      useCustomAudio: false,
      enabled: true,
    );

    const alarm2 = AlarmRhythm(
      id: 'alarm-test-2',
      title: 'Solar Meridian',
      wakeMinutes24: 720,
      soundMeta: 'Golden Chime 528Hz',
      weekdays: ['Thu', 'Fri'],
      useCustomAudio: false,
      enabled: false,
    );

    blocTest<AlarmCubit, AlarmState>(
      'updates wake minutes and home city',
      build: () => AlarmCubit(initialHomeCity: testCity),
      act: (cubit) {
        cubit.setWakeMinutes(390);
        cubit.setHomeCity(newYorkCity);
      },
      expect: () => [
        predicate<AlarmState>((s) => s.wakeMinutes == 390),
        predicate<AlarmState>(
          (s) => s.wakeMinutes == 390 && s.homeCity.name == 'New York',
        ),
      ],
    );

    blocTest<AlarmCubit, AlarmState>(
      'adds, updates, toggles, and deletes alarms',
      build: () => AlarmCubit(initialHomeCity: testCity),
      act: (cubit) {
        cubit.addAlarm(alarm1);
        cubit.saveAlarm(alarm1.copyWith(title: 'Solar Awakening Updated'));
        cubit.toggleAlarm(0, alarm1, false);
        cubit.deleteAlarm(alarm1.id);
      },
      expect: () => [
        predicate<AlarmState>(
          (s) => s.alarms.length == 1 && s.alarms.first.id == 'alarm-test-1',
        ),
        predicate<AlarmState>(
          (s) => s.alarms.first.title == 'Solar Awakening Updated',
        ),
        predicate<AlarmState>((s) => s.alarms.first.enabled == false),
        predicate<AlarmState>((s) => s.alarms.isEmpty),
      ],
    );

    blocTest<AlarmCubit, AlarmState>(
      'inserts alarm at specific index and handles undo restore',
      build: () =>
          AlarmCubit(initialHomeCity: testCity, initialAlarms: const [alarm1]),
      act: (cubit) => cubit.insertAlarmAt(0, alarm2),
      expect: () => [
        predicate<AlarmState>(
          (s) => s.alarms.length == 2 && s.alarms.first.id == 'alarm-test-2',
        ),
      ],
    );

    blocTest<AlarmCubit, AlarmState>(
      'handles triggerDawnAwakening and dismissRingingAlarm flow',
      build: () => AlarmCubit(initialHomeCity: testCity),
      act: (cubit) {
        cubit.triggerDawnAwakening(
          alarmId: 'alarm-test-1',
          title: 'Morning Glory',
          time: '06:00 AM',
          soundMeta: 'Tibetan Bell 432Hz',
          useCustomAudio: false,
        );
        cubit.dismissRingingAlarm();
      },
      expect: () => [
        predicate<AlarmState>(
          (s) =>
              s.ringingAlarm != null &&
              s.ringingAlarm!['title'] == 'Morning Glory' &&
              s.ringingAlarm!['alarmId'] == 'alarm-test-1',
        ),
        predicate<AlarmState>((s) => s.ringingAlarm == null),
      ],
    );

    blocTest<AlarmCubit, AlarmState>(
      'checks exact alarm permission and reflects in state',
      build: () => AlarmCubit(initialHomeCity: testCity),
      act: (cubit) => cubit.checkExactAlarmPermission(),
      verify: (cubit) {
        expect(cubit.state.canScheduleExact, isNotNull);
      },
    );
  });

  group('WorldClockCubit Unit Tests', () {
    blocTest<WorldClockCubit, WorldClockState>(
      'selects city properly',
      build: () => WorldClockCubit(initialCity: testCity),
      act: (cubit) => cubit.selectCity(londonCity),
      expect: () => [
        predicate<WorldClockState>((s) => s.selectedCity.name == 'London'),
      ],
    );

    blocTest<WorldClockCubit, WorldClockState>(
      'toggles pin on an unpinned city',
      build: () => WorldClockCubit(
        initialCity: testCity,
        initialPinnedIds: ['bengaluru', 'stockholm'],
      ),
      act: (cubit) {
        cubit.togglePinCity('tokyo'); // add tokyo
        cubit.togglePinCity('bengaluru'); // remove bengaluru
      },
      expect: () => [
        predicate<WorldClockState>((s) => s.pinnedCityIds.contains('tokyo')),
        predicate<WorldClockState>(
          (s) =>
              !s.pinnedCityIds.contains('bengaluru') &&
              s.pinnedCityIds.contains('tokyo'),
        ),
      ],
    );

    test('retains last pinned city when trying to unpin only remaining city', () {
      final cubit = WorldClockCubit(
        initialCity: testCity,
        initialPinnedIds: ['bengaluru'],
      );
      cubit.togglePinCity('bengaluru');
      // Should still contain bengaluru because length <= 1 guard prevents empty pinned list
      expect(cubit.state.pinnedCityIds, equals(['bengaluru']));
      cubit.close();
    });

    test('addCustomCity and resolveCity lookup hierarchy', () {
      final cubit = WorldClockCubit(initialCity: testCity);
      const customCity = WorldCity(
        id: 'reykjavik_custom',
        name: 'Reykjavik',
        country: 'Iceland',
        stdTzCode: 'GMT',
        dstTzCode: 'GMT',
        stdOffsetMinutes: 0,
        dstOffsetMinutes: 0,
        dstRegion: 'NONE',
        lat: 64.1466,
        lon: -21.9426,
        isCustom: true,
      );

      cubit.addCustomCity(customCity);
      expect(
        cubit.state.customCities.any((c) => c.id == 'reykjavik_custom'),
        isTrue,
      );

      // Resolves custom city
      final resolvedCustom = cubit.state.resolveCity('reykjavik_custom');
      expect(resolvedCustom.name, 'Reykjavik');

      // Resolves bundled city
      final resolvedBundled = cubit.state.resolveCity('tokyo');
      expect(resolvedBundled.name, 'Tokyo');

      // Resolves unknown id to selected city
      final resolvedFallback = cubit.state.resolveCity('unknown_city_xyz');
      expect(resolvedFallback.id, cubit.state.selectedCity.id);

      cubit.close();
    });
  });

  group('ChronometerCubit Unit Tests', () {
    blocTest<ChronometerCubit, ChronometerState>(
      'toggles running state and stops properly',
      build: () => ChronometerCubit(),
      act: (cubit) {
        cubit.toggle(); // start
        cubit.toggle(); // stop
      },
      expect: () => [
        predicate<ChronometerState>((s) => s.isRunning == true),
        predicate<ChronometerState>((s) => s.isRunning == false),
      ],
    );

    blocTest<ChronometerCubit, ChronometerState>(
      'records laps when elapsed time is present',
      build: () => ChronometerCubit(),
      act: (cubit) {
        cubit.toggle(); // start
        cubit.elapsedNotifier.value = 5200; // simulate 5.2 seconds elapsed
        cubit.recordLap(); // record lap
        cubit.toggle(); // stop
        cubit.recordLap(); // reset
      },
      expect: () => [
        predicate<ChronometerState>((s) => s.isRunning == true),
        predicate<ChronometerState>((s) => s.laps.length == 1),
        predicate<ChronometerState>(
          (s) => s.isRunning == false && s.laps.length == 1,
        ),
        predicate<ChronometerState>(
          (s) => s.isRunning == false && s.laps.isEmpty,
        ),
      ],
    );
  });

  group('FocusTimerCubit Unit Tests', () {
    blocTest<FocusTimerCubit, FocusTimerState>(
      'sets custom music name and soundscape',
      build: () => FocusTimerCubit(),
      act: (cubit) {
        cubit.setCustomMusic('Solfeggio Forest.wav');
        cubit.changeSoundscape('tanpura');
      },
      expect: () => [
        predicate<FocusTimerState>(
          (s) => s.customMusicName == 'Solfeggio Forest.wav',
        ),
        predicate<FocusTimerState>(
          (s) =>
              s.customMusicName == 'Solfeggio Forest.wav' &&
              s.activeSoundscapeId == 'tanpura',
        ),
      ],
    );

    blocTest<FocusTimerCubit, FocusTimerState>(
      'toggles timer and completes session',
      build: () => FocusTimerCubit(),
      act: (cubit) {
        cubit.toggleTimer(); // start
        cubit.completeSession(); // complete
      },
      expect: () => [
        predicate<FocusTimerState>((s) => s.focusRunning == true),
        predicate<FocusTimerState>(
          (s) =>
              s.focusRunning == false &&
              s.completedGhatikas == 1 &&
              s.remainingSec == 0.0,
        ),
      ],
    );

    test(
      'selectPreset, setCustomDuration, and effectiveTotalSec calculation',
      () {
        final cubit = FocusTimerCubit();
        expect(cubit.state.effectiveTotalSec, 24 * 60);

        // Select 12m preset
        final p12 = kFocusPresets.firstWhere((p) => p.id == '12m');
        cubit.selectPreset(p12);
        expect(cubit.state.activePresetId, '12m');
        expect(cubit.state.effectiveTotalSec, 12 * 60);

        // Set custom 45 minute duration
        cubit.setCustomDuration(45);
        expect(cubit.state.customTotalSec, 45 * 60);
        expect(cubit.state.effectiveTotalSec, 45 * 60);

        // Restore session state
        cubit.restoreSessionState(
          targetSec: 45 * 60.0,
          targetProgress: 0.0,
          autoStart: false,
        );
        expect(cubit.state.focusRunning, isFalse);
        expect(cubit.remainingNotifier.value, 45 * 60.0);

        cubit.close();
      },
    );

    test(
      'manualHourglassFlip triggers inversion and increments flip count',
      () {
        final cubit = FocusTimerCubit();
        expect(cubit.state.hourglassFlipCount, 0);

        cubit.manualHourglassFlip();
        expect(cubit.state.hourglassFlipCount, 1);
        expect(cubit.state.isInverting, isTrue);

        cubit.close();
      },
    );
  });

  group('DST & Timezone Rollover Boundary Tests', () {
    test('Fall Back DST Transition preserves chronometer monotonic flow', () {
      final londonPreDst = DateTime.utc(
        2026,
        10,
        24,
        20,
        0,
      ); // Day before switch
      final nextTriggerUtc = NativePlatformBridge.computeNextAlarmTriggerUtc(
        nowUtc: londonPreDst,
        hour: 7,
        minute: 30,
        cityOffsetMinutes: 60, // BST = UTC+1
      );
      expect(nextTriggerUtc.isAfter(londonPreDst), isTrue);
      // Trigger should be 06:30 UTC next morning (7:30 BST - 1h)
      expect(nextTriggerUtc, DateTime.utc(2026, 10, 25, 6, 30));
    });

    test('Spring Forward DST Transition maintains positive future delta', () {
      final nyPreDst = DateTime.utc(2026, 3, 7, 23, 0);
      final nextTriggerUtc = NativePlatformBridge.computeNextAlarmTriggerUtc(
        nowUtc: nyPreDst,
        hour: 6,
        minute: 0,
        cityOffsetMinutes: -300, // EST = UTC-5
      );
      expect(nextTriggerUtc.isAfter(nyPreDst), isTrue);
      // Trigger should be 11:00 UTC (06:00 EST + 5h)
      expect(nextTriggerUtc, DateTime.utc(2026, 3, 8, 11, 0));
    });

    test(
      'Weekday repeating alarm rolls over entire week when target passed today',
      () {
        final wednesdayAfternoon = DateTime.utc(
          2026,
          11,
          11,
          15,
          0,
        ); // Wednesday
        final nextTriggerUtc = NativePlatformBridge.computeNextAlarmTriggerUtc(
          nowUtc: wednesdayAfternoon,
          hour: 8,
          minute: 0,
          cityOffsetMinutes: 0,
          activeWeekdays: {DateTime.monday}, // Only Monday!
        );
        expect(nextTriggerUtc.isAfter(wednesdayAfternoon), isTrue);
        expect(nextTriggerUtc.weekday, DateTime.monday);
        expect(nextTriggerUtc, DateTime.utc(2026, 11, 16, 8, 0));
      },
    );
  });
}
