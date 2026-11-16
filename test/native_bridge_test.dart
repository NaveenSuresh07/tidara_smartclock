import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/audio/horological_audio_engine.dart';
import 'package:tidara_smartclock/core/security/encrypted_vault.dart';
import 'package:tidara_smartclock/core/services/native_platform_bridge.dart';
import 'package:tidara_smartclock/core/services/state_coordinator.dart';
import 'package:tidara_smartclock/core/services/storage_repository.dart';
import 'package:tidara_smartclock/features/chronometer/cubit/chronometer_cubit.dart';
import 'package:tidara_smartclock/features/focus_timer/cubit/focus_timer_cubit.dart';
import 'package:tidara_smartclock/features/shell/cubit/app_preferences_cubit.dart';
import 'package:tidara_smartclock/features/smart_alarm/cubit/alarm_cubit.dart';
import 'package:tidara_smartclock/features/world_clock/cubit/world_clock_cubit.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

class FakeStorageRepository implements HorologicalStorageRepository {
  Map<String, dynamic>? savedPayload;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> clearAll() async {
    savedPayload = null;
  }

  @override
  Map<String, dynamic>? loadState() => savedPayload;

  @override
  Future<Map<String, dynamic>?> loadStateAsync() async => savedPayload;

  @override
  Future<bool> saveState(Map<String, dynamic> payload) async {
    savedPayload = Map<String, dynamic>.from(payload);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> nativeCalls = <MethodCall>[];

  setUpAll(() {
    ensureTimeZonesInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.tidara.smartclock/native_bridge'),
          (MethodCall call) async {
            nativeCalls.add(call);
            switch (call.method) {
              case 'getDurableStorageDir':
                return '/data/user/0/com.tidara.tidara_smartclock/app_flutter';
              case 'requestAlarmAndNotificationPermissions':
                return true;
              case 'canScheduleExactAlarms':
                return true;
              case 'openExactAlarmSettings':
                return true;
              case 'scheduleExactAlarm':
                return true;
              case 'cancelExactAlarm':
                return true;
              case 'pickAudioFileFromDevice':
                return {
                  'name': 'Gong_Chime.wav',
                  'path': '/storage/emulated/0/Music/Gong_Chime.wav',
                };
              case 'playAudioFile':
                return true;
              case 'playWavBytes':
                return true;
              case 'stopAudio':
                return true;
              case 'listDeviceAudio':
                return [
                  {
                    'name': 'Gong_Chime.wav',
                    'path': '/storage/emulated/0/Music/Gong_Chime.wav',
                  },
                ];
              default:
                return null;
            }
          },
        );
  });

  setUp(() {
    nativeCalls.clear();
    EncryptedVault.clearVault();
  });

  group('NativePlatformBridge Deep Channel Verification', () {
    test('1. Queries durable storage directory', () async {
      final dir = await NativePlatformBridge.getDurableStorageDir();
      expect(dir, '/data/user/0/com.tidara.tidara_smartclock/app_flutter');
    });

    test('2. Requests alarm and notification permissions', () async {
      final granted =
          await NativePlatformBridge.requestAlarmAndNotificationPermissions();
      expect(granted, isTrue);
    });

    test('3. Checks exact alarm capability and opens settings', () async {
      final canSchedule = await NativePlatformBridge.canScheduleExactAlarms();
      expect(canSchedule, isTrue);

      await NativePlatformBridge.openExactAlarmSettings();
      expect(
        nativeCalls.any((c) => c.method == 'openExactAlarmSettings'),
        isTrue,
      );
    });

    test('4. Schedules exact alarm with parameters', () async {
      final ok = await NativePlatformBridge.scheduleExactAlarm(
        id: 101,
        triggerUtc: DateTime.utc(2026, 6, 1, 6, 0),
        label: 'Sunrise Wakeup',
        audioPath: '/data/audio.wav',
      );
      expect(ok, isTrue);
      expect(
        nativeCalls.any(
          (c) => c.method == 'scheduleExactAlarm' && c.arguments['id'] == 101,
        ),
        isTrue,
      );
    });

    test('5. Cancels exact alarm', () async {
      await NativePlatformBridge.cancelExactAlarm(101);
      expect(
        nativeCalls.any(
          (c) => c.method == 'cancelExactAlarm' && c.arguments['id'] == 101,
        ),
        isTrue,
      );
    });

    test('6. Native audio playback and stop control', () async {
      final played = await NativePlatformBridge.playAudioFile(
        '/storage/alarm.wav',
        loop: true,
      );
      expect(played, isTrue);
      expect(
        nativeCalls.any(
          (c) =>
              c.method == 'playAudioFile' &&
              c.arguments['path'] == '/storage/alarm.wav' &&
              c.arguments['loop'] == true,
        ),
        isTrue,
      );

      await NativePlatformBridge.stopAudio();
      expect(nativeCalls.any((c) => c.method == 'stopAudio'), isTrue);
    });

    test('7. Picks audio file from device and registers custom path', () async {
      final item = await NativePlatformBridge.pickAudioFileFromDevice();
      expect(item, isNotNull);
      expect(item!['name'], 'Gong_Chime.wav');

      final resolved = NativePlatformBridge.resolveAudioPathForLabel(
        'Gong_Chime.wav',
      );
      expect(resolved, '/storage/emulated/0/Music/Gong_Chime.wav');
    });

    test('8. Plays and stops local audio via platform bridge', () async {
      final played = await NativePlatformBridge.playAudioFile(
        '/data/audio.wav',
        loop: true,
      );
      expect(played, isTrue);

      await NativePlatformBridge.stopAudio();
      expect(nativeCalls.any((c) => c.method == 'stopAudio'), isTrue);
    });

    test('9. Plays WAV bytes via platform bridge', () async {
      final played = await NativePlatformBridge.playWavBytes(
        Uint8List.fromList([0, 1, 2, 3]),
      );
      expect(played, isTrue);
    });

    test('10. Queries device audio library', () async {
      final list = await NativePlatformBridge.listDeviceAudio();
      expect(list.isNotEmpty, isTrue);
      expect(list.first['name'], 'Gong_Chime.wav');
    });

    test('11. HorologicalAudioEngine ensures preset files exist', () async {
      final engine = HorologicalAudioEngine.instance;
      final presets = await engine.ensurePresetWavFilesExist('');
      expect(presets, isA<Map<String, String>>());
    });
  });

  group('HorologicalStateCoordinator Architecture & Hydration Tests', () {
    late FakeStorageRepository repo;
    late AlarmCubit alarmCubit;
    late WorldClockCubit worldClockCubit;
    late ChronometerCubit chronoCubit;
    late FocusTimerCubit focusCubit;
    late AppPreferencesCubit prefCubit;
    late HorologicalStateCoordinator coordinator;

    setUp(() {
      repo = FakeStorageRepository();
      alarmCubit = AlarmCubit(initialHomeCity: kWorldCities[0]);
      worldClockCubit = WorldClockCubit(initialCity: kWorldCities[0]);
      chronoCubit = ChronometerCubit();
      focusCubit = FocusTimerCubit();
      prefCubit = AppPreferencesCubit();

      coordinator = HorologicalStateCoordinator(
        storage: repo,
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

    test('12. persistAll serializes state across all feature cubits', () async {
      worldClockCubit.selectCity(kWorldCities[2]); // Stockholm
      alarmCubit.setWakeMinutes(360);
      prefCubit.toggle24HourFormat(true);

      await coordinator.persistAll();

      expect(repo.savedPayload, isNotNull);
      expect(repo.savedPayload!['cityId'], 'stockholm');
      expect(repo.savedPayload!['wakeMinutes'], 360);
      expect(repo.savedPayload!['use24HourFormat'], isTrue);
    });

    test(
      '13. hydrateAll restores state into cubits from storage payload',
      () async {
        repo.savedPayload = {
          'cityId': 'london',
          'wakeMinutes': 420,
          'use24HourFormat': true,
          'highContrastMode': true,
          'plainLanguageVedic': true,
          'pinnedCityIds': ['bengaluru', 'london'],
          'customCities': [
            {
              'id': 'custom_berlin',
              'name': 'Berlin',
              'country': 'Germany',
              'tzCode': 'CET',
              'stdOffsetMinutes': 60,
              'lat': 52.52,
              'lon': 13.405,
              'isCustom': true,
            },
          ],
        };

        await coordinator.hydrateAll();

        expect(worldClockCubit.state.selectedCity.id, 'london');
        expect(alarmCubit.state.wakeMinutes, 420);
        expect(prefCubit.state.use24HourFormat, isTrue);
        expect(prefCubit.state.highContrastMode, isTrue);
        expect(prefCubit.state.plainLanguageVedic, isTrue);
        expect(worldClockCubit.state.pinnedCityIds, contains('london'));
        expect(
          worldClockCubit.state.customCities.any((c) => c.name == 'Berlin'),
          isTrue,
        );
      },
    );
  });

  group('NativePlatformBridge — Robustness & Platform Failure Handling', () {
    const channel = MethodChannel('com.tidara.smartclock/native_bridge');

    test(
      '14. Bridge methods handle PlatformException gracefully without crashing',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              throw PlatformException(
                code: 'UNAVAILABLE',
                message: 'Simulated platform channel failure',
              );
            });

        expect(await NativePlatformBridge.getDurableStorageDir(), isNull);
        expect(
          await NativePlatformBridge.requestAlarmAndNotificationPermissions(),
          isTrue,
        );
        expect(await NativePlatformBridge.pickAudioFileFromDevice(), isNull);
        expect(await NativePlatformBridge.playAudioFile('/bad/path'), isFalse);
        expect(await NativePlatformBridge.playWavBytes(Uint8List(0)), isFalse);
        expect(await NativePlatformBridge.canScheduleExactAlarms(), isTrue);
        await expectLater(
          NativePlatformBridge.openExactAlarmSettings(),
          completes,
        );
        expect(
          await NativePlatformBridge.scheduleExactAlarm(
            id: 9999,
            triggerUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
            label: 'Test Alarm',
          ),
          isFalse,
        );
        await expectLater(
          NativePlatformBridge.cancelExactAlarm(9999),
          completes,
        );
        expect(await NativePlatformBridge.listDeviceAudio(), isEmpty);
        expect(
          await NativePlatformBridge.playAudioFile('/invalid/path.wav'),
          isFalse,
        );
        expect(await NativePlatformBridge.playWavBytes(Uint8List(0)), isFalse);
        await expectLater(NativePlatformBridge.stopAudio(), completes);
      },
    );

    test(
      '15. pickAudioFileFromDevice and listDeviceAudio handle malformed platform data',
      () async {
        // 1. Picker returning non-Map
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'pickAudioFileFromDevice') {
                return 'invalid_string_result';
              }
              if (call.method == 'listDeviceAudio') {
                return null;
              }
              return null;
            });

        expect(await NativePlatformBridge.pickAudioFileFromDevice(), isNull);
        expect(await NativePlatformBridge.listDeviceAudio(), isEmpty);

        // 2. Picker returning Map with empty or whitespace values
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'pickAudioFileFromDevice') {
                return {'name': '   ', 'path': ''};
              }
              if (call.method == 'listDeviceAudio') {
                return [
                  {'name': 'Valid Track', 'path': '/path/to/valid.wav'},
                  'invalid_item_format',
                  {'name': 'Empty Path', 'path': ''},
                  {'name': null, 'path': '/path/to/null_name.wav'},
                ];
              }
              return null;
            });

        expect(await NativePlatformBridge.pickAudioFileFromDevice(), isNull);
        final tracks = await NativePlatformBridge.listDeviceAudio();
        expect(tracks.length, 2);
        expect(tracks[0]['name'], 'Valid Track');
        expect(tracks[1]['name'], 'Track'); // fallback for null name
      },
    );

    test(
      '16. mapWeekdayNamesToIndices parses all ISO weekdays and filters invalid input',
      () {
        final allDays = [
          'mon',
          'tuesday',
          'WED',
          'Thu',
          'Friday',
          'SATURDAY',
          'Sun',
          'invalid_day',
          'funday',
          '',
        ];
        final indices = NativePlatformBridge.mapWeekdayNamesToIndices(allDays);
        expect(indices, {1, 2, 3, 4, 5, 6, 7});

        final empty = NativePlatformBridge.mapWeekdayNamesToIndices([
          'none',
          'xyz',
        ]);
        expect(empty, isEmpty);
      },
    );

    test(
      '17. computeNextAlarmTriggerUtc handles rollover and weekday filtering',
      () {
        // Now is Wednesday 12:00 UTC (day 3) in city offset +0
        final nowUtc = DateTime.utc(2026, 3, 25, 12, 0); // Wednesday

        // Alarm set for 08:00 (already passed today) -> rolls over to Thursday (day 4)
        final nextRollover = NativePlatformBridge.computeNextAlarmTriggerUtc(
          hour: 8,
          minute: 0,
          cityOffsetMinutes: 0,
          nowUtc: nowUtc,
        );
        expect(nextRollover, DateTime.utc(2026, 3, 26, 8, 0));

        // Alarm set for 14:00 (upcoming today) but active weekdays is only Friday (5)
        final nextFriday = NativePlatformBridge.computeNextAlarmTriggerUtc(
          hour: 14,
          minute: 0,
          cityOffsetMinutes: 0,
          nowUtc: nowUtc,
          activeWeekdays: {5}, // Friday only
        );
        expect(nextFriday, DateTime.utc(2026, 3, 27, 14, 0));
      },
    );

    test(
      '18. Audio path resolution handles missing files and custom registry',
      () {
        NativePlatformBridge.registerCustomAudioPath(
          'Custom Bell',
          '/sdcard/bell.mp3',
        );
        expect(
          NativePlatformBridge.resolveAudioPathForLabel('Custom Bell'),
          '/sdcard/bell.mp3',
        );

        // Export and import custom audio map
        final exported = NativePlatformBridge.exportCustomAudioMap();
        expect(exported['Custom Bell'], '/sdcard/bell.mp3');

        NativePlatformBridge.importCustomAudioMap({
          'Restored Bowl': '/sdcard/bowl.wav',
        });
        expect(
          NativePlatformBridge.resolveAudioPathForLabel('Restored Bowl'),
          '/sdcard/bowl.wav',
        );

        // Preset resolution without directory set returns null
        NativePlatformBridge.setPresetAudioDirectory('');
        expect(
          NativePlatformBridge.resolvePresetAudioPath('Tibetan Bowl 432Hz'),
          isNull,
        );
      },
    );

    test(
      '19. syncAlarmsWithOsScheduler synchronizes enabled and disabled alarms',
      () async {
        final scheduledCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              scheduledCalls.add(call);
              return true;
            });

        final alarms = [
          const AlarmRhythm(
            id: 'alarm_enabled_1',
            title: '', // tests empty title fallback
            wakeMinutes24: 360,
            soundMeta: 'Custom Gong',
            weekdays: ['Mon', 'Tue'],
            useCustomAudio: true,
            enabled: true,
          ),
          const AlarmRhythm(
            id: 'alarm_disabled_2',
            title: 'Evening Chime',
            wakeMinutes24: 1200,
            soundMeta: 'Golden Chime 528Hz',
            weekdays: ['Wed'],
            useCustomAudio: false,
            enabled: false,
          ),
        ];

        NativePlatformBridge.registerCustomAudioPath(
          'Custom Gong',
          '/storage/gong.wav',
        );

        final count = await NativePlatformBridge.syncAlarmsWithOsScheduler(
          alarms: alarms,
          homeCity: kWorldCities[0],
          referenceUtc: DateTime.utc(2026, 6, 1, 12, 0),
        );

        expect(count, 1);
        expect(NativePlatformBridge.lastScheduledAlarmCount, 1);

        // Verify scheduleExactAlarm called for enabled alarm with fallback label
        final scheduleCall = scheduledCalls.firstWhere(
          (c) => c.method == 'scheduleExactAlarm',
        );
        expect(scheduleCall.arguments['label'], 'Tidara Smart Alarm');
        expect(scheduleCall.arguments['audioPath'], '/storage/gong.wav');

        // Verify cancelExactAlarm called for disabled alarm
        final cancelCall = scheduledCalls.firstWhere(
          (c) => c.method == 'cancelExactAlarm',
        );
        expect(cancelCall.arguments['id'], isNotNull);
      },
    );

    test(
      '20. Permission denial and null channel responses return false safely',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              switch (call.method) {
                case 'requestAlarmAndNotificationPermissions':
                  return false;
                case 'canScheduleExactAlarms':
                  return false;
                case 'scheduleExactAlarm':
                  return null;
                case 'playAudioFile':
                  return null;
                case 'playWavBytes':
                  return null;
                default:
                  return null;
              }
            });

        expect(
          await NativePlatformBridge.requestAlarmAndNotificationPermissions(),
          isFalse,
        );
        expect(await NativePlatformBridge.canScheduleExactAlarms(), isFalse);
        expect(
          await NativePlatformBridge.scheduleExactAlarm(
            id: 42,
            triggerUtc: DateTime.utc(2026, 7, 1, 6, 0),
            label: 'Denied Alarm',
          ),
          isFalse,
        );
        expect(await NativePlatformBridge.playAudioFile('/bad.mp3'), isFalse);
        expect(await NativePlatformBridge.playWavBytes(Uint8List(0)), isFalse);
      },
    );

    test(
      '21. Preset audio resolution maps 432Hz, 528Hz, and 639Hz files correctly',
      () {
        final tempAudioDir = Directory.systemTemp.createTempSync(
          'tidara_preset_audio_',
        );
        final f432 = File(
          '${tempAudioDir.path}${Platform.pathSeparator}preset_432hz.wav',
        )..writeAsStringSync('audio432');
        final f528 = File(
          '${tempAudioDir.path}${Platform.pathSeparator}preset_528hz.wav',
        )..writeAsStringSync('audio528');
        final f639 = File(
          '${tempAudioDir.path}${Platform.pathSeparator}preset_639hz.wav',
        )..writeAsStringSync('audio639');

        NativePlatformBridge.setPresetAudioDirectory(tempAudioDir.path);

        expect(
          NativePlatformBridge.resolvePresetAudioPath(
            'Tibetan Singing Bowl 432Hz',
          ),
          equals(f432.absolute.path),
        );
        expect(
          NativePlatformBridge.resolvePresetAudioPath('Harmonic Chime (528Hz)'),
          equals(f528.absolute.path),
        );
        expect(
          NativePlatformBridge.resolvePresetAudioPath(
            'Morning Dawn Resonance 639Hz',
          ),
          equals(f639.absolute.path),
        );
        expect(
          NativePlatformBridge.resolvePresetAudioPath('Unrecognized Sound FX'),
          isNull,
        );

        tempAudioDir.deleteSync(recursive: true);
      },
    );
  });
}
