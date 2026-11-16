import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/shell/dawn_awakening_overlay.dart';
import 'package:tidara_smartclock/features/smart_alarm/cubit/alarm_cubit.dart';
import 'package:tidara_smartclock/features/smart_alarm/smart_alarm_tab.dart';
import 'package:tidara_smartclock/models/horological_models.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final palette = TidaraPalette(isDark: false);
  final testCity = kWorldCities.firstWhere((c) => c.name == 'Stockholm');
  final ephem = CircadianEphemeris.compute(
    rawLat: testCity.lat,
    rawLon: testCity.lon,
    utcNow: DateTime.utc(2026, 6, 21, 6, 0),
    cityOffsetMinutes: testCity.stdOffsetMinutes,
  );

  group('DawnAwakeningOverlay Preview vs Real Alarm UI', () {
    testWidgets(
      'Dawn Ring / Preview trigger clearly displays Preview badge and Close preview button',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        final nowNotifier = ValueNotifier<DateTime>(
          DateTime(2026, 6, 21, 5, 30),
        );
        int? dismissedSnooze;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  DawnAwakeningOverlay(
                    palette: palette,
                    ringingAlarm: const {
                      'alarmId': 'alarm-1',
                      'title': 'Morning Flight',
                      'time': '05:30 AM',
                      'soundMeta': 'Soft gong | 15m gradual dawn swell',
                      'isPreview': true,
                    },
                    nowNotifier: nowNotifier,
                    onDismiss: ({required snoozeMinutes}) {
                      dismissedSnooze = snoozeMinutes;
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Preview mode badge MUST be visible
        expect(find.byKey(const Key('preview_mode_badge')), findsOneWidget);
        expect(find.text('PREVIEW MODE'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

        // 2. Banner clearly states SIMULATED / PREVIEW
        expect(find.textContaining('DAWN SWELL PREVIEW'), findsOneWidget);
        expect(find.textContaining('SIMULATED'), findsOneWidget);

        // 3. Displays title and time
        expect(find.text('Morning Flight'), findsOneWidget);
        expect(find.text('05:30 AM'), findsOneWidget);

        // 4. Distinct dismiss label "Close preview"
        expect(find.text('Close preview'), findsOneWidget);
        expect(find.text('Dismiss Alarm'), findsNothing);

        // 5. Snooze button present
        expect(find.text('Snooze 12 minutes'), findsOneWidget);

        // 6. Test interaction: Close preview dispatches snoozeMinutes: 0
        await tester.tap(find.text('Close preview'));
        expect(dismissedSnooze, 0);

        // 7. Test interaction: Snooze dispatches snoozeMinutes: 12
        await tester.tap(find.text('Snooze 12 minutes'));
        expect(dismissedSnooze, 12);
      },
    );

    testWidgets(
      'Real scheduled alarm trigger displays actual alarm title and time without preview badge',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        final nowNotifier = ValueNotifier<DateTime>(
          DateTime(2026, 6, 21, 7, 15),
        );
        int? dismissedSnooze;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  DawnAwakeningOverlay(
                    palette: palette,
                    ringingAlarm: const {
                      'alarmId': 'scheduled-alarm-99',
                      'title': 'Critical Stock Market Open',
                      'time': '07:15 AM',
                      'soundMeta': '432Hz Singing Bowl',
                      'isPreview': false,
                    },
                    nowNotifier: nowNotifier,
                    onDismiss: ({required snoozeMinutes}) {
                      dismissedSnooze = snoozeMinutes;
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Preview badge MUST NOT be visible on live alarm
        expect(find.byKey(const Key('preview_mode_badge')), findsNothing);
        expect(find.text('PREVIEW MODE'), findsNothing);
        expect(find.textContaining('SIMULATED'), findsNothing);

        // 2. Banner indicates live alarm bypassing mute
        expect(find.textContaining('GRADUAL DAWN SWELL'), findsOneWidget);
        expect(find.textContaining('BYPASSES MUTE'), findsOneWidget);

        // 3. Displays exact scheduled alarm title and time
        expect(find.text('Critical Stock Market Open'), findsOneWidget);
        expect(find.text('07:15 AM'), findsOneWidget);
        expect(find.text('432Hz Singing Bowl'), findsOneWidget);

        // 4. Live alarm uses "Dismiss Alarm"
        expect(find.text('Dismiss Alarm'), findsOneWidget);
        expect(find.text('Close preview'), findsNothing);

        // 5. Test interaction: Dismiss Alarm dispatches snoozeMinutes: 0
        await tester.tap(find.text('Dismiss Alarm'));
        expect(dismissedSnooze, 0);

        // 6. Test interaction: Snooze dispatches snoozeMinutes: 12
        await tester.tap(find.text('Snooze 12 minutes'));
        expect(dismissedSnooze, 12);
      },
    );

    testWidgets(
      'DawnAwakeningOverlay uses liquid glass buttons for snooze and dismiss',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        final nowNotifier = ValueNotifier<DateTime>(
          DateTime(2026, 6, 21, 6, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  DawnAwakeningOverlay(
                    palette: palette,
                    ringingAlarm: const {
                      'alarmId': 'alarm-glass',
                      'title': 'Glass Button Check',
                      'time': '06:00 AM',
                      'isPreview': false,
                    },
                    nowNotifier: nowNotifier,
                    onDismiss: ({required snoozeMinutes}) {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final glassButtons = find.byType(GlassButton);
        expect(glassButtons, findsAtLeastNWidgets(2));
      },
    );
  });

  group('AlarmCubit Scheduled Evaluation and Snooze/Dismiss Bridge', () {
    test(
      'evaluateScheduledAlarms triggers live alarm with exact title, formatted time, and isPreview=false',
      () {
        final cubit = AlarmCubit(initialHomeCity: testCity);

        // Alarm scheduled for 06:45 AM (405 mins from midnight) on Sunday
        const scheduled = AlarmRhythm(
          id: 'alarm-sun-645',
          title: 'Sunday Morning Flight',
          wakeMinutes24: 405, // 06:45 AM
          weekdays: ['Sun'],
          enabled: true,
          soundMeta: 'Nordic Cedar & Harmonic Resonance',
          useCustomAudio: false,
        );

        cubit.addAlarm(scheduled);

        // Evaluate at exactly 06:45 AM on Sunday 2026-06-21
        final sundayMorning = DateTime(2026, 6, 21, 6, 45);
        cubit.evaluateScheduledAlarms(sundayMorning, use24HourFormat: false);

        expect(cubit.state.ringingAlarm, isNotNull);
        expect(cubit.state.ringingAlarm!['alarmId'], 'alarm-sun-645');
        expect(cubit.state.ringingAlarm!['title'], 'Sunday Morning Flight');
        expect(cubit.state.ringingAlarm!['time'], '06:45 AM');
        expect(cubit.state.ringingAlarm!['isPreview'], isFalse);
      },
    );

    test('evaluateScheduledAlarms ignores disabled alarms', () {
      final cubit = AlarmCubit(initialHomeCity: testCity);

      const disabledAlarm = AlarmRhythm(
        id: 'alarm-disabled',
        title: 'Sleep In',
        wakeMinutes24: 480, // 08:00 AM
        weekdays: ['Sun'],
        soundMeta: 'Soft gong',
        useCustomAudio: false,
        enabled: false,
      );

      cubit.addAlarm(disabledAlarm);

      final sundayEight = DateTime(2026, 6, 21, 8, 0);
      cubit.evaluateScheduledAlarms(sundayEight);

      expect(cubit.state.ringingAlarm, isNull);
    });

    test('dismissRingingAlarm with snoozeMinutes > 0 snoozes live alarm', () {
      final cubit = AlarmCubit(initialHomeCity: testCity);

      const liveAlarm = AlarmRhythm(
        id: 'alarm-live-1',
        title: 'Meeting Alarm',
        wakeMinutes24: 540, // 09:00 AM
        weekdays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        soundMeta: 'Soft gong',
        useCustomAudio: false,
        enabled: true,
      );
      cubit.addAlarm(liveAlarm);

      // Trigger live alarm
      cubit.triggerDawnAwakening(
        alarmId: 'alarm-live-1',
        title: 'Meeting Alarm',
        time: '09:00 AM',
        isPreview: false,
      );
      expect(cubit.state.ringingAlarm, isNotNull);

      // Snooze for 12 minutes
      cubit.dismissRingingAlarm(snoozeMinutes: 12);

      // Ringing alarm is cleared
      expect(cubit.state.ringingAlarm, isNull);

      // Scheduled alarm has snoozedUntilMinutes24 set
      final updated = cubit.state.alarms.firstWhere(
        (a) => a.id == 'alarm-live-1',
      );
      expect(updated.snoozedUntilMinutes24, isNotNull);
    });

    test(
      'dismissRingingAlarm on preview does NOT modify live alarm snooze state',
      () {
        final cubit = AlarmCubit(initialHomeCity: testCity);

        const realAlarm = AlarmRhythm(
          id: 'alarm-real-99',
          title: 'Actual Scheduled Alarm',
          wakeMinutes24: 420, // 07:00 AM
          weekdays: ['Mon'],
          soundMeta: 'Soft gong',
          useCustomAudio: false,
          enabled: true,
          snoozedUntilMinutes24: null,
        );
        cubit.addAlarm(realAlarm);

        // Trigger a PREVIEW referencing this alarmId
        cubit.triggerDawnAwakening(
          alarmId: 'alarm-real-99',
          title: 'Actual Scheduled Alarm',
          time: '07:00 AM',
          isPreview: true,
        );

        // Dismiss / Close preview with snoozeMinutes: 12 (simulating snooze button in preview)
        cubit.dismissRingingAlarm(snoozeMinutes: 12);

        // Ringing alarm cleared
        expect(cubit.state.ringingAlarm, isNull);

        // Real alarm was NOT snoozed
        final real = cubit.state.alarms.firstWhere(
          (a) => a.id == 'alarm-real-99',
        );
        expect(real.snoozedUntilMinutes24, isNull);
      },
    );
  });

  group('SmartAlarmTab Preview Tone Button', () {
    testWidgets(
      'Tapping Dawn Ring chip calls onTriggerDawnPreview with isPreview: true',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));

        bool previewCalled = false;
        bool? isPreviewReceived;
        String? previewTitle;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 360,
                alarms: const [
                  AlarmRhythm(
                    id: 'alarm-tab-test',
                    title: 'Sunrise Meditation',
                    wakeMinutes24: 360,
                    weekdays: ['Mon'],
                    soundMeta: 'Soft gong',
                    useCustomAudio: false,
                    enabled: true,
                  ),
                ],
                use24HourFormat: false,
                plainLanguageVedic: false,
                customMusicName: null,
                onWakeMinutesChanged: (_) {},
                onSaveAlarm: (_) {},
                onAddAlarm: (_) {},
                onDeleteAlarm: (_) {},
                onInsertAlarmAt: (_, __) {},
                onToggleAlarm: (_, __, ___) {},
                onTriggerDawnPreview:
                    ({
                      alarmId,
                      title,
                      time,
                      soundMeta,
                      useCustomAudio,
                      isPreview = false,
                    }) {
                      previewCalled = true;
                      isPreviewReceived = isPreview;
                      previewTitle = title;
                    },
                onSelectPhoneMusic: () async => null,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find Sunrise Tone chip
        final dawnRingFinder = find.widgetWithText(GlassButton, 'Sunrise Tone');
        expect(dawnRingFinder, findsOneWidget);

        await tester.tap(dawnRingFinder);
        await tester.pumpAndSettle();

        expect(previewCalled, isTrue);
        expect(isPreviewReceived, isTrue);
        expect(previewTitle, 'Sunrise Meditation');
      },
    );
  });
}
