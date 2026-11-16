import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/security/encrypted_vault.dart';
import 'package:tidara_smartclock/features/chronometer/cubit/chronometer_cubit.dart';
import 'package:tidara_smartclock/features/shell/tidara_shell_screen.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

Future<void> _pauseApp(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _resumeApp(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureTimeZonesInitialized();
    EncryptedVault.clearVault();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.tidara.smartclock/native_bridge'),
          (MethodCall call) async {
            switch (call.method) {
              case 'checkExactAlarmPermission':
                return true;
              case 'requestExactAlarmPermission':
                return true;
              case 'syncStateToPlatform':
                return true;
              case 'stopAudio':
                return true;
              default:
                return true;
            }
          },
        );
  });

  group('Lifecycle Throttling & Power Conservation Tests', () {
    testWidgets(
      'Ticker and periodic clock timer stop completely on AppLifecycleState.paused and resume on resumed',
      (tester) async {
        await tester.pumpWidget(const TidaraSmartclockApp());
        await tester.pumpAndSettle();

        // 1. Find TidaraShellScreen state
        final shellFinder = find.byType(TidaraShellScreen);
        expect(shellFinder, findsOneWidget);
        final state = tester.state<TidaraShellScreenState>(shellFinder);

        // 2. Verified initial state: clock timer running, frame ticker idle (chronometer stopped)
        expect(
          state.isClockTimerActive,
          isTrue,
          reason:
              '1Hz clock timer must be active when app is running in foreground',
        );
        expect(
          state.isFrameTickerActive,
          isFalse,
          reason:
              'Frame ticker must remain idle when chronometer and focus timer are inactive',
        );

        // 3. Start chronometer to activate dynamic frame ticker
        final chronoCubit = tester
            .element(shellFinder)
            .read<ChronometerCubit>();
        chronoCubit.toggle();
        await tester.pump();

        expect(
          state.isFrameTickerActive,
          isTrue,
          reason: 'Frame ticker must activate when chronometer is running',
        );

        // 4. Trigger background transition: resumed -> inactive -> hidden -> paused
        await _pauseApp(tester);

        // Verified: Both clock timer and frame ticker must be halted in background
        expect(
          state.isClockTimerActive,
          isFalse,
          reason:
              'Periodic clock timer must be cancelled when app transitions to paused',
        );
        expect(
          state.isFrameTickerActive,
          isFalse,
          reason:
              'Frame ticker must be stopped immediately when app transitions to paused',
        );

        // 5. Trigger foreground transition: paused -> hidden -> inactive -> resumed
        await _resumeApp(tester);

        // Verified: Both resume in foreground
        expect(
          state.isClockTimerActive,
          isTrue,
          reason: 'Periodic clock timer must restart when app resumes',
        );
        expect(
          state.isFrameTickerActive,
          isTrue,
          reason:
              'Frame ticker must resume if chronometer was running prior to pausing',
        );

        // 6. Stop chronometer while active
        chronoCubit.toggle();
        await tester.pump();

        expect(
          state.isFrameTickerActive,
          isFalse,
          reason: 'Frame ticker must halt once chronometer stops',
        );
        expect(
          state.isClockTimerActive,
          isTrue,
          reason: 'Clock timer stays active while app is in foreground',
        );

        // 7. Verify inactive state transitions also throttle timers
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(state.isClockTimerActive, isFalse);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(state.isClockTimerActive, isTrue);

        // 8. Verify hidden state transition (resumed -> inactive -> hidden)
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        expect(state.isClockTimerActive, isFalse);

        // Final restore
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(state.isClockTimerActive, isTrue);
      },
    );
  });
}
