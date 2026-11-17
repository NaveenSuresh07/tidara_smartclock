import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/services/native_platform_bridge.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
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

  group('Permission Banner UX Tests', () {
    testWidgets(
      'Displays notifications_permission_banner when POST_NOTIFICATIONS is denied (Condition A)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        bool openedSettings = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 360,
                alarms: const [],
                use24HourFormat: false,
                customMusicName: null,
                canScheduleExact: true,
                notificationsEnabled: false, // Condition A: denied
                alarmChannelValid: true,
                canUseFullScreenIntent: true,
                onOpenNotificationSettings: () => openedSettings = true,
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
                    }) {},
                onSelectPhoneMusic: () async => null,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notifications_permission_banner')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Notification permission required to display ringing alarms.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('alarm_channel_banner')), findsNothing);
        expect(
          find.byKey(const Key('full_screen_intent_banner')),
          findsNothing,
        );

        await tester.tap(find.widgetWithText(GlassButton, 'ENABLE'));
        expect(openedSettings, isTrue);
      },
    );

    testWidgets(
      'Displays alarm_channel_banner when notification channel is muted or lowered (Condition B)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        bool openedSettings = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 360,
                alarms: const [],
                use24HourFormat: false,
                customMusicName: null,
                canScheduleExact: true,
                notificationsEnabled: true,
                alarmChannelValid:
                    false, // Condition B: channel muted or lowered
                canUseFullScreenIntent: true,
                onOpenAlarmChannelSettings: () => openedSettings = true,
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
                    }) {},
                onSelectPhoneMusic: () async => null,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('alarm_channel_banner')), findsOneWidget);
        expect(
          find.text(
            'Alarm notification channel is muted or lowered. Set to High.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('notifications_permission_banner')),
          findsNothing,
        );

        await tester.tap(find.widgetWithText(GlassButton, 'CONFIGURE'));
        expect(openedSettings, isTrue);
      },
    );

    testWidgets(
      'Displays full_screen_intent_banner when canUseFullScreenIntent is false on Android 14+ (Condition C)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        bool openedSettings = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartAlarmTab(
                palette: palette,
                alarmEphem: ephem,
                alarmHomeCity: testCity,
                wakeMinutes: 360,
                alarms: const [],
                use24HourFormat: false,
                customMusicName: null,
                canScheduleExact: true,
                notificationsEnabled: true,
                alarmChannelValid: true,
                canUseFullScreenIntent:
                    false, // Condition C: Android 14+ permission denied
                onOpenFullScreenIntentSettings: () => openedSettings = true,
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
                    }) {},
                onSelectPhoneMusic: () async => null,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('full_screen_intent_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Full-screen alarm display over lock screen is disabled.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('notifications_permission_banner')),
          findsNothing,
        );

        await tester.tap(find.widgetWithText(GlassButton, 'ENABLE'));
        expect(openedSettings, isTrue);
      },
    );

    testWidgets('Renders no warning banners when all permissions are granted', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartAlarmTab(
              palette: palette,
              alarmEphem: ephem,
              alarmHomeCity: testCity,
              wakeMinutes: 360,
              alarms: const [],
              use24HourFormat: false,
              customMusicName: null,
              canScheduleExact: true,
              notificationsEnabled: true,
              alarmChannelValid: true,
              canUseFullScreenIntent: true,
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
                  }) {},
              onSelectPhoneMusic: () async => null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exact_alarm_banner')), findsNothing);
      expect(
        find.byKey(const Key('notifications_permission_banner')),
        findsNothing,
      );
      expect(find.byKey(const Key('alarm_channel_banner')), findsNothing);
      expect(find.byKey(const Key('full_screen_intent_banner')), findsNothing);
    });
  });

  group('Platform Bridge & Lock-Screen Intent Coordination', () {
    const channel = MethodChannel('com.tidara.smartclock/native_bridge');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getInitialRingingAlarm':
                return {
                  'alarmId': 'alarm-cold-start-99',
                  'title': 'Stockholm Departure Flight',
                  'time': '06:15 AM',
                  'soundMeta': '432Hz Singing Bowl | 15m dawn swell',
                  'useCustomAudio': false,
                  'isPreview': false,
                };
              case 'getAlarmPermissionStatus':
                return {
                  'canScheduleExact': true,
                  'notificationsEnabled': true,
                  'alarmChannelValid': true,
                  'canUseFullScreenIntent': true,
                };
              case 'clearKeepScreenOn':
                return true;
              case 'stopAudio':
                return true;
              case 'openNotificationSettings':
              case 'openAlarmChannelSettings':
              case 'openFullScreenIntentSettings':
              case 'openExactAlarmSettings':
                return true;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'getInitialRingingAlarm reads real alarm intent extras on launch',
      () async {
        final initialAlarm =
            await NativePlatformBridge.getInitialRingingAlarm();

        expect(initialAlarm, isNotNull);
        expect(initialAlarm!['alarmId'], 'alarm-cold-start-99');
        expect(initialAlarm['title'], 'Stockholm Departure Flight');
        expect(initialAlarm['time'], '06:15 AM');
        expect(initialAlarm['isPreview'], isFalse);
      },
    );

    test(
      'AlarmCubit.checkAlarmPermissions correctly populates permission state',
      () async {
        final cubit = AlarmCubit(initialHomeCity: testCity);

        await cubit.checkAlarmPermissions();

        expect(cubit.state.canScheduleExact, isTrue);
        expect(cubit.state.notificationsEnabled, isTrue);
        expect(cubit.state.alarmChannelValid, isTrue);
        expect(cubit.state.canUseFullScreenIntent, isTrue);
      },
    );

    test(
      'Platform bridge handler receives onNotificationAction and dispatches correctly',
      () {
        NativePlatformBridge.initializeMethodCallHandler();

        String? handledAction;
        int? handledAlarmId;

        NativePlatformBridge.onNotificationActionReceived = (action, alarmId) {
          handledAction = action;
          handledAlarmId = alarmId;
        };

        // Simulate native receiver sending notification action
        NativePlatformBridge.onNotificationActionReceived?.call('snooze', 1001);

        expect(handledAction, 'snooze');
        expect(handledAlarmId, 1001);
      },
    );

    test(
      'dismissRingingAlarm calls clearKeepScreenOn and stopAudio on bridge',
      () async {
        final cubit = AlarmCubit(initialHomeCity: testCity);
        cubit.triggerDawnAwakening(
          alarmId: 'alarm-test',
          title: 'Morning Meeting',
          time: '08:00 AM',
          isPreview: false,
        );
        expect(cubit.state.ringingAlarm, isNotNull);

        cubit.dismissRingingAlarm();
        expect(cubit.state.ringingAlarm, isNull);
      },
    );
  });
}
