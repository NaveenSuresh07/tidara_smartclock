import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/shared/custom_audio_selection_sheet.dart';
import 'package:tidara_smartclock/features/smart_alarm/alarm_sheet_coordinator.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final palette = TidaraPalette(isDark: true);
  final ephem = CircadianEphemeris.compute(
    rawLat: 12.9716,
    rawLon: 77.5946,
    utcNow: DateTime.utc(2026, 3, 21, 6, 0),
    cityOffsetMinutes: 330,
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.tidara.smartclock/native_bridge'),
          (MethodCall call) async {
            switch (call.method) {
              case 'listDeviceAudio':
                return [
                  {
                    'name': 'Forest_Dawn.mp3',
                    'path': '/sdcard/Forest_Dawn.mp3',
                  },
                  {
                    'name': 'Ocean_Breeze.wav',
                    'path': '/sdcard/Ocean_Breeze.wav',
                  },
                ];
              case 'playAudioFile':
                return true;
              case 'playWavBytes':
                return true;
              case 'stopAudio':
                return true;
              case 'pickAudioFileFromDevice':
                return {
                  'name': 'Picked_Chime.mp3',
                  'path': '/storage/Picked_Chime.mp3',
                };
              default:
                return true;
            }
          },
        );
  });

  group('AlarmSheetCoordinator — Presentation Decoupling', () {
    testWidgets('shows modal sheet, triggers callbacks and saves alarm', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      AlarmRhythm? savedAlarm;
      String? deletedId;
      bool previewTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AlarmSheetCoordinator.showAlarmSheet(
                      context,
                      editingAlarm: null,
                      defaultWakeMinutes: 360,
                      sunriseMinutesFromMidnight: ephem.sunriseLocalMinutes,
                      sunsetMinutesFromMidnight: ephem.sunsetLocalMinutes,
                      customMusicName: null,
                      palette: palette,
                      onSelectPhoneMusic: () async => 'Selected_Track.mp3',
                      onTriggerDawnPreview:
                          ({
                            alarmId,
                            title,
                            time,
                            soundMeta,
                            useCustomAudio,
                            isPreview = false,
                          }) {
                            previewTriggered = true;
                          },
                      onDeleteAlarm: (id) => deletedId = id,
                      onSaveAlarm: (alarm) => savedAlarm = alarm,
                    );
                  },
                  child: const Text('Open Alarm Sheet'),
                );
              },
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open Alarm Sheet'));
      await tester.pumpAndSettle();

      // Verify bottom sheet mounted
      expect(find.text('New Alarm'), findsOneWidget);
      expect(find.text('Save Alarm'), findsOneWidget);

      // Tap Save
      await tester.ensureVisible(find.text('Save Alarm'));
      await tester.tap(find.text('Save Alarm'));
      await tester.pumpAndSettle();

      expect(savedAlarm, isNotNull);
      expect(savedAlarm!.enabled, isTrue);
      expect(previewTriggered, isFalse);
      expect(deletedId, isNull);
    });

    testWidgets('editing existing alarm delegates delete callback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final existingAlarm = AlarmRhythm(
        id: 'test_alarm_42',
        title: 'Morning Awakening',
        wakeMinutes24: 330,
        enabled: true,
        weekdays: ['mon', 'tue'],
        soundMeta: '432Hz Tibetan Singing Bowl',
        useCustomAudio: false,
      );

      String? deletedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AlarmSheetCoordinator.showAlarmSheet(
                      context,
                      editingAlarm: existingAlarm,
                      defaultWakeMinutes: 330,
                      sunriseMinutesFromMidnight: ephem.sunriseLocalMinutes,
                      sunsetMinutesFromMidnight: ephem.sunsetLocalMinutes,
                      customMusicName: null,
                      palette: palette,
                      onSelectPhoneMusic: () async => null,
                      onTriggerDawnPreview:
                          ({
                            alarmId,
                            title,
                            time,
                            soundMeta,
                            useCustomAudio,
                            isPreview = false,
                          }) {},
                      onDeleteAlarm: (id) => deletedId = id,
                      onSaveAlarm: (_) {},
                    );
                  },
                  child: const Text('Open Edit Alarm'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Edit Alarm'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Alarm'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletedId, 'test_alarm_42');
    });
  });

  group('CustomAudioSelectionSheet — Liquid Glass Audio Browser', () {
    testWidgets(
      'renders track presets, picks audio and returns selected track',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        String? selectedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      selectedResult = await showCustomAudioSelectionSheet(
                        context,
                        palette: palette,
                      );
                    },
                    child: const Text('Select Audio'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Select Audio'));
        await tester.pumpAndSettle();

        // Verify sheet content
        expect(find.text('Sound Selection & Custom Audio'), findsOneWidget);
        expect(find.text('432Hz Tibetan Bowl'), findsOneWidget);
        expect(find.text('528Hz Solfeggio Chime'), findsOneWidget);
        expect(find.text('Forest_Dawn.mp3'), findsOneWidget);

        // Select preset
        await tester.tap(find.text('528Hz Solfeggio Chime'));
        await tester.pumpAndSettle();

        // Confirm
        await tester.tap(find.text('Confirm Selection'));
        await tester.pumpAndSettle();

        expect(selectedResult, '528Hz Solfeggio Chime');
      },
    );

    testWidgets(
      'browsing phone audio files prepends picked track and selects it',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        String? selectedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      selectedResult = await showCustomAudioSelectionSheet(
                        context,
                        palette: palette,
                      );
                    },
                    child: const Text('Select Audio'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Select Audio'));
        await tester.pumpAndSettle();

        // Tap Browse Phone Audio Files...
        await tester.tap(find.text('Browse Phone Audio Files...'));
        await tester.pumpAndSettle();

        // Picked track should appear in the list
        expect(find.text('Picked_Chime.mp3'), findsOneWidget);

        // Confirm selection
        await tester.tap(find.text('Confirm Selection'));
        await tester.pumpAndSettle();

        expect(selectedResult, 'Picked_Chime.mp3');
      },
    );

    testWidgets('cancelling sheet returns null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      String? selectedResult = 'initial_not_null';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedResult = await showCustomAudioSelectionSheet(
                      context,
                      palette: palette,
                    );
                  },
                  child: const Text('Select Audio'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select Audio'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selectedResult, isNull);
    });
  });
}
