import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/audio/horological_audio_engine.dart';
import '../../core/ephemeris/noaa_ephemeris.dart';
import 'package:flutter/foundation.dart';
import 'security_diagnostics_modal.dart';
import '../../core/services/native_platform_bridge.dart';
import '../../core/services/state_coordinator.dart';
import '../../core/services/storage_repository.dart';
import '../../core/theme/tidara_palette.dart';
import '../../models/horological_models.dart';

import '../chronometer/chronometer_tab.dart';
import '../chronometer/cubit/chronometer_cubit.dart';
import '../focus_timer/custom_duration_dialog.dart';
import '../focus_timer/focus_timer_tab.dart';
import '../focus_timer/cubit/focus_timer_cubit.dart';
import '../shared/custom_audio_selection_sheet.dart';
import '../smart_alarm/alarm_sheet_coordinator.dart';
import '../smart_alarm/cubit/alarm_cubit.dart';
import '../smart_alarm/smart_alarm_tab.dart';
import '../world_clock/cubit/city_search_cubit.dart';
import '../world_clock/cubit/world_clock_cubit.dart';
import '../world_clock/world_clock_tab.dart';

import 'cubit/app_preferences_cubit.dart';
import 'dawn_awakening_overlay.dart';
import 'floating_dock.dart';
import 'settings_modal.dart';
import 'top_status_bar.dart';

/// Entry point root application configuring the BLoC/Cubit feature architecture
/// and persistent state coordination.
class TidaraSmartclockApp extends StatefulWidget {
  final HorologicalStorageRepository storageRepository;
  const TidaraSmartclockApp({
    super.key,
    this.storageRepository = const DurableVaultStorageRepository(),
  });

  @override
  State<TidaraSmartclockApp> createState() => _TidaraSmartclockAppState();
}

class _TidaraSmartclockAppState extends State<TidaraSmartclockApp>
    with WidgetsBindingObserver {
  late final AppPreferencesCubit _preferencesCubit;
  late final AlarmCubit _alarmCubit;
  late final WorldClockCubit _worldClockCubit;
  late final ChronometerCubit _chronometerCubit;
  late final FocusTimerCubit _focusTimerCubit;
  late final CitySearchCubit _citySearchCubit;
  late final HorologicalStateCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preferencesCubit = AppPreferencesCubit();
    _alarmCubit = AlarmCubit(initialHomeCity: kWorldCities[0]);
    _worldClockCubit = WorldClockCubit(initialCity: kWorldCities[0]);
    _chronometerCubit = ChronometerCubit();
    _focusTimerCubit = FocusTimerCubit();
    _citySearchCubit = CitySearchCubit();

    _coordinator = HorologicalStateCoordinator(
      storage: widget.storageRepository,
      alarmCubit: _alarmCubit,
      worldClockCubit: _worldClockCubit,
      chronometerCubit: _chronometerCubit,
      focusTimerCubit: _focusTimerCubit,
      preferencesCubit: _preferencesCubit,
    );

    _coordinator.hydrateAll();
    _alarmCubit.checkExactAlarmPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _alarmCubit.checkExactAlarmPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.dispose();
    _preferencesCubit.close();
    _alarmCubit.close();
    _worldClockCubit.close();
    _chronometerCubit.close();
    _focusTimerCubit.close();
    _citySearchCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppPreferencesCubit>.value(value: _preferencesCubit),
        BlocProvider<AlarmCubit>.value(value: _alarmCubit),
        BlocProvider<WorldClockCubit>.value(value: _worldClockCubit),
        BlocProvider<ChronometerCubit>.value(value: _chronometerCubit),
        BlocProvider<FocusTimerCubit>.value(value: _focusTimerCubit),
        BlocProvider<CitySearchCubit>.value(value: _citySearchCubit),
      ],
      child: BlocBuilder<AppPreferencesCubit, AppPreferencesState>(
        builder: (context, prefState) {
          return MaterialApp(
            title: 'Tidara Smartclock',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  foregroundColor: const Color(0xFF1E242B),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: const Color(0xFF1E242B),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.52),
                    width: 1.1,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFC59B27,
                  ).withValues(alpha: 0.28),
                  foregroundColor: const Color(0xFF1E242B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.42),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              fontFamily: 'Plus Jakarta Sans',
            ),
            builder: (context, child) {
              final MediaQueryData mq = MediaQuery.of(context);
              final TextScaler clampedScaler = mq.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.25,
              );
              return MediaQuery(
                data: mq.copyWith(textScaler: clampedScaler),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const TidaraShellScreen(),
          );
        },
      ),
    );
  }
}

class TidaraShellScreen extends StatefulWidget {
  const TidaraShellScreen({super.key});

  @override
  State<TidaraShellScreen> createState() => TidaraShellScreenState();
}

class TidaraShellScreenState extends State<TidaraShellScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ValueNotifier<DateTime> _nowNotifier;
  late final Ticker _frameTicker;
  Timer? _clockSecondTimer;
  StreamSubscription? _chronoSub;
  StreamSubscription? _focusSub;
  bool _showDebugDiagnostics = false;

  @visibleForTesting
  bool get isFrameTickerActive => _frameTicker.isActive;

  @visibleForTesting
  bool get isClockTimerActive =>
      _clockSecondTimer != null && _clockSecondTimer!.isActive;

  void _syncFrameTicker() {
    if (!mounted) return;
    final bool chronoRunning = context.read<ChronometerCubit>().state.isRunning;
    final bool focusRunning = context
        .read<FocusTimerCubit>()
        .state
        .focusRunning;
    final bool needsTicker = chronoRunning || focusRunning;
    if (needsTicker && !_frameTicker.isActive) {
      _frameTicker.start();
    } else if (!needsTicker && _frameTicker.isActive) {
      _frameTicker.stop();
    }
  }

  void _startClockTimer() {
    _clockSecondTimer?.cancel();
    _clockSecondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      _nowNotifier.value = now;
      final prefState = context.read<AppPreferencesCubit>().state;
      context.read<AlarmCubit>().evaluateScheduledAlarms(
        now,
        use24HourFormat: prefState.use24HourFormat,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nowNotifier = ValueNotifier<DateTime>(DateTime.now());

    NativePlatformBridge.initializeMethodCallHandler();
    NativePlatformBridge.onRingingAlarmTriggered = (alarmData) {
      if (!mounted) return;
      context.read<AlarmCubit>().triggerDawnAwakening(
        alarmId: alarmData['alarmId']?.toString(),
        title: alarmData['title']?.toString() ?? 'Solar Awakening',
        time: alarmData['time']?.toString() ?? '05:30 AM',
        soundMeta:
            alarmData['soundMeta']?.toString() ??
            'Soft gong | 15m gradual dawn swell',
        useCustomAudio: alarmData['useCustomAudio'] == true,
        isPreview: false,
      );
    };
    NativePlatformBridge.onNotificationActionReceived = (action, alarmId) {
      if (!mounted) return;
      if (action == 'snooze') {
        context.read<AlarmCubit>().dismissRingingAlarm(snoozeMinutes: 12);
      } else {
        context.read<AlarmCubit>().dismissRingingAlarm(snoozeMinutes: 0);
      }
    };
    NativePlatformBridge.getInitialRingingAlarm().then((alarmData) {
      if (alarmData != null && mounted) {
        context.read<AlarmCubit>().triggerDawnAwakening(
          alarmId: alarmData['alarmId']?.toString(),
          title: alarmData['title']?.toString() ?? 'Solar Awakening',
          time: alarmData['time']?.toString() ?? '05:30 AM',
          soundMeta:
              alarmData['soundMeta']?.toString() ??
              'Soft gong | 15m gradual dawn swell',
          useCustomAudio: alarmData['useCustomAudio'] == true,
          isPreview: false,
        );
      }
    });

    _frameTicker = createTicker((_) {
      if (!mounted) return;
      context.read<ChronometerCubit>().onTick();
      context.read<FocusTimerCubit>().onTick();
    });

    _startClockTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AlarmCubit>().checkAlarmPermissions();
      _chronoSub = context.read<ChronometerCubit>().stream.listen(
        (_) => _syncFrameTicker(),
      );
      _focusSub = context.read<FocusTimerCubit>().stream.listen(
        (_) => _syncFrameTicker(),
      );
      _syncFrameTicker();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chronoSub?.cancel();
    _focusSub?.cancel();
    _clockSecondTimer?.cancel();
    _frameTicker.dispose();
    _nowNotifier.dispose();
    HorologicalAudioEngine.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final now = DateTime.now();
      _nowNotifier.value = now;
      final prefState = context.read<AppPreferencesCubit>().state;
      context.read<AlarmCubit>().evaluateScheduledAlarms(
        now,
        use24HourFormat: prefState.use24HourFormat,
      );
      context.read<AlarmCubit>().checkAlarmPermissions();
      _startClockTimer();
      _syncFrameTicker();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _clockSecondTimer?.cancel();
      _clockSecondTimer = null;
      if (_frameTicker.isActive) {
        _frameTicker.stop();
      }
    }
  }

  Widget _buildActiveTab({
    required int activeIndex,
    required TidaraPalette palette,
    required CircadianEphemeris ephem,
    required CircadianEphemeris alarmEphem,
    required WorldCity alarmHomeCity,
    required bool use24HourFormat,
    required bool plainLanguageVedic,
  }) {
    switch (activeIndex) {
      case 0:
        return BlocBuilder<AlarmCubit, AlarmState>(
          builder: (context, alarmState) {
            final alarmCubit = context.read<AlarmCubit>();
            return SmartAlarmTab(
              palette: palette,
              alarmEphem: alarmEphem,
              alarmHomeCity: alarmHomeCity,
              wakeMinutes: alarmState.wakeMinutes,
              alarms: alarmState.alarms,
              use24HourFormat: use24HourFormat,
              plainLanguageVedic: plainLanguageVedic,
              customMusicName: context
                  .read<FocusTimerCubit>()
                  .state
                  .customMusicName,
              onWakeMinutesChanged: alarmCubit.setWakeMinutes,
              onSaveAlarm: alarmCubit.saveAlarm,
              onAddAlarm: alarmCubit.addAlarm,
              onDeleteAlarm: alarmCubit.deleteAlarm,
              onInsertAlarmAt: alarmCubit.insertAlarmAt,
              onToggleAlarm: (idx, alarm, next) =>
                  alarmCubit.toggleAlarm(idx, alarm, next),
              onTriggerDawnPreview:
                  ({
                    alarmId,
                    title,
                    time,
                    soundMeta,
                    useCustomAudio,
                    isPreview = true,
                  }) {
                    alarmCubit.triggerDawnAwakening(
                      alarmId: alarmId,
                      title: title ?? 'Solar Awakening',
                      time: time ?? '05:30 AM',
                      soundMeta:
                          soundMeta ?? 'Soft gong | 15m gradual dawn light',
                      useCustomAudio: useCustomAudio ?? false,
                      isPreview: isPreview,
                    );
                  },
              onSelectPhoneMusic: () =>
                  showCustomAudioSelectionSheet(context, palette: palette),
              canScheduleExact: alarmState.canScheduleExact,
              notificationsEnabled: alarmState.notificationsEnabled,
              alarmChannelValid: alarmState.alarmChannelValid,
              canUseFullScreenIntent: alarmState.canUseFullScreenIntent,
              onOpenExactAlarmSettings:
                  NativePlatformBridge.openExactAlarmSettings,
              onOpenNotificationSettings:
                  NativePlatformBridge.openNotificationSettings,
              onOpenAlarmChannelSettings:
                  NativePlatformBridge.openAlarmChannelSettings,
              onOpenFullScreenIntentSettings:
                  NativePlatformBridge.openFullScreenIntentSettings,
              onOpenAlarmSheet: (ctx, {editingAlarm}) {
                AlarmSheetCoordinator.showAlarmSheet(
                  ctx,
                  editingAlarm: editingAlarm,
                  defaultWakeMinutes: alarmState.wakeMinutes,
                  sunriseMinutesFromMidnight: alarmEphem.sunriseLocalMinutes,
                  sunsetMinutesFromMidnight: alarmEphem.sunsetLocalMinutes,
                  customMusicName: context
                      .read<FocusTimerCubit>()
                      .state
                      .customMusicName,
                  palette: palette,
                  onSelectPhoneMusic: () =>
                      showCustomAudioSelectionSheet(context, palette: palette),
                  onTriggerDawnPreview:
                      ({
                        alarmId,
                        title,
                        time,
                        soundMeta,
                        useCustomAudio,
                        isPreview = true,
                      }) {
                        alarmCubit.triggerDawnAwakening(
                          alarmId: alarmId,
                          title: title ?? 'Solar Awakening',
                          time: time ?? '05:30 AM',
                          soundMeta:
                              soundMeta ?? 'Soft gong | 15m gradual dawn light',
                          useCustomAudio: useCustomAudio ?? false,
                          isPreview: isPreview,
                        );
                      },
                  onDeleteAlarm: alarmCubit.deleteAlarm,
                  onSaveAlarm: alarmCubit.saveAlarm,
                );
              },
            );
          },
        );
      case 1:
        return BlocBuilder<WorldClockCubit, WorldClockState>(
          builder: (context, worldState) {
            final worldCubit = context.read<WorldClockCubit>();
            return WorldClockTab(
              palette: palette,
              ephem: ephem,
              selectedCity: worldState.selectedCity,
              pinnedCityIds: worldState.pinnedCityIds,
              customCities: worldState.customCities,
              nowNotifier: _nowNotifier,
              use24HourFormat: use24HourFormat,
              onSelectCity: worldCubit.selectCity,
              onTogglePinCity: worldCubit.togglePinCity,
            );
          },
        );
      case 2:
        return BlocBuilder<ChronometerCubit, ChronometerState>(
          builder: (context, chronoState) {
            final chronoCubit = context.read<ChronometerCubit>();
            return ChronometerTab(
              palette: palette,
              chronoElapsedMsNotifier: chronoCubit.elapsedNotifier,
              isRunning: chronoState.isRunning,
              laps: chronoState.laps,
              onToggleChrono: chronoCubit.toggle,
              onLapOrReset: chronoCubit.recordLap,
              onResetChrono: chronoCubit.reset,
            );
          },
        );
      case 3:
        return BlocBuilder<FocusTimerCubit, FocusTimerState>(
          builder: (context, focusState) {
            final focusCubit = context.read<FocusTimerCubit>();
            return FocusTimerTab(
              palette: palette,
              activePresetId: focusState.activePresetId,
              customTotalSec: focusState.customTotalSec,
              focusRunning: focusState.focusRunning,
              completedGhatikas: focusState.completedGhatikas,
              hourglassFlipCount: focusState.hourglassFlipCount,
              activeSoundscapeId: focusState.activeSoundscapeId,
              customMusicName: focusState.customMusicName,
              focusProgressNotifier: focusCubit.progressNotifier,
              focusRemainingSecNotifier: focusCubit.remainingNotifier,
              effectiveFocusTotalSec: focusState.effectiveTotalSec,
              onToggleFocus: focusCubit.toggleTimer,
              onManualHourglassFlip: focusCubit.manualHourglassFlip,
              onSelectPreset: focusCubit.selectPreset,
              onPromptCustomDuration: () async {
                final int currentMins =
                    (focusCubit.remainingNotifier.value / 60.0).ceil().clamp(
                      1,
                      180,
                    );
                final chosen = await showCustomDurationDialog(
                  context,
                  initialMinutes: currentMins,
                );
                if (chosen != null) {
                  focusCubit.setCustomDuration(chosen);
                }
              },
              onChangeSoundscape: focusCubit.changeSoundscape,
              onBrowseAudio: () async {
                final picked = await showCustomAudioSelectionSheet(
                  context,
                  palette: palette,
                );
                if (picked != null) {
                  focusCubit.setCustomMusic(picked);
                }
              },
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppPreferencesCubit, AppPreferencesState>(
      builder: (context, prefState) {
        final Brightness sysBrightness = MediaQuery.platformBrightnessOf(
          context,
        );
        final bool isDarkEffective =
            prefState.themePreference == 'dark' ||
            (prefState.themePreference == 'system' &&
                sysBrightness == Brightness.dark);
        final TidaraPalette palette = TidaraPalette(
          isDark: isDarkEffective,
          highContrast: prefState.highContrastMode,
        );

        final worldState = context.watch<WorldClockCubit>().state;
        final alarmState = context.watch<AlarmCubit>().state;
        final chronoState = context.watch<ChronometerCubit>().state;
        final focusState = context.watch<FocusTimerCubit>().state;

        final DateTime utc = _nowNotifier.value.toUtc();
        final CircadianEphemeris ephem = CircadianEphemeris.compute(
          rawLat: worldState.selectedCity.lat,
          rawLon: worldState.selectedCity.lon,
          utcNow: utc,
          cityOffsetMinutes: worldState.selectedCity.effectiveOffsetMinutes(
            utc,
          ),
          use24Hour: prefState.use24HourFormat,
        );

        final CircadianEphemeris alarmEphem = CircadianEphemeris.compute(
          rawLat: alarmState.homeCity.lat,
          rawLon: alarmState.homeCity.lon,
          utcNow: utc,
          cityOffsetMinutes: alarmState.homeCity.effectiveOffsetMinutes(utc),
          use24Hour: prefState.use24HourFormat,
        );

        final prefCubit = context.read<AppPreferencesCubit>();
        final alarmCubit = context.read<AlarmCubit>();

        return PopScope(
          canPop:
              alarmState.ringingAlarm == null && !prefState.showSettingsModal,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (alarmState.ringingAlarm != null) {
              alarmCubit.dismissRingingAlarm(snoozeMinutes: 0);
            } else if (prefState.showSettingsModal) {
              prefCubit.toggleSettingsModal(false);
            }
          },
          child: Scaffold(
            backgroundColor: palette.bgBase,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TopStatusBar(
                              palette: palette,
                              nowNotifier: _nowNotifier,
                              use24HourFormat: prefState.use24HourFormat,
                              activeTabIndex: prefState.activeTabIndex,
                              isChronoRunning: chronoState.isRunning,
                              isFocusRunning: focusState.focusRunning,
                              themePreference: prefState.themePreference,
                              isMuted: prefState.isMuted,
                              showSettingsModal: prefState.showSettingsModal,
                              onSelectTab: prefCubit.selectTab,
                              onToggleTheme: prefCubit.toggleTheme,
                              onToggleMute: prefCubit.toggleMute,
                              onToggleSettings: () =>
                                  prefCubit.toggleSettingsModal(
                                    !prefState.showSettingsModal,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                layoutBuilder:
                                    (currentChild, previousChildren) {
                                      return Stack(
                                        alignment: Alignment.topCenter,
                                        children: <Widget>[
                                          ...previousChildren,
                                          if (currentChild != null)
                                            currentChild,
                                        ],
                                      );
                                    },
                                child: _buildActiveTab(
                                  activeIndex: prefState.activeTabIndex,
                                  palette: palette,
                                  ephem: ephem,
                                  alarmEphem: alarmEphem,
                                  alarmHomeCity: alarmState.homeCity,
                                  use24HourFormat: prefState.use24HourFormat,
                                  plainLanguageVedic:
                                      prefState.plainLanguageVedic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: FloatingDock(
                                palette: palette,
                                activeTabIndex: prefState.activeTabIndex,
                                hasActiveAlarms: alarmState.alarms.any(
                                  (a) => a.enabled,
                                ),
                                isChronoRunning: chronoState.isRunning,
                                isFocusRunning: focusState.focusRunning,
                                onSelectTab: prefCubit.selectTab,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (prefState.showSettingsModal)
                        SettingsAndGlossaryModal(
                          palette: palette,
                          alarmEphem: alarmEphem,
                          alarmHomeCity: alarmState.homeCity,
                          use24HourFormat: prefState.use24HourFormat,
                          highContrastMode: prefState.highContrastMode,
                          plainLanguageVedic: prefState.plainLanguageVedic,
                          enableDebugDiagnostics:
                              kDebugMode && kShowSecurityDiagnostics,
                          onOpenSecurityDiagnostics: () {
                            prefCubit.toggleSettingsModal(false);
                            setState(() => _showDebugDiagnostics = true);
                          },
                          onToggle24Hour: prefCubit.toggle24HourFormat,
                          onToggleHighContrast: prefCubit.toggleHighContrast,
                          onTogglePlainLanguage: prefCubit.togglePlainLanguage,
                          onSelectAlarmHomeCity: alarmCubit.setHomeCity,
                          onClose: () => prefCubit.toggleSettingsModal(false),
                        ),
                      if (kDebugMode &&
                          kShowSecurityDiagnostics &&
                          _showDebugDiagnostics)
                        SecurityDiagnosticsModal(
                          palette: palette,
                          onClose: () =>
                              setState(() => _showDebugDiagnostics = false),
                        ),
                      if (alarmState.ringingAlarm != null)
                        DawnAwakeningOverlay(
                          palette: palette,
                          ringingAlarm: alarmState.ringingAlarm!,
                          nowNotifier: _nowNotifier,
                          onDismiss: ({required snoozeMinutes}) =>
                              alarmCubit.dismissRingingAlarm(
                                snoozeMinutes: snoozeMinutes,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
