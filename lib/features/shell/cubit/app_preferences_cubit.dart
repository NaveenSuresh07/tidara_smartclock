import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/audio/horological_audio_engine.dart';

class AppPreferencesState {
  final String themePreference; // 'light', 'dark', 'system'
  final bool highContrastMode;
  final bool use24HourFormat;
  final bool plainLanguageVedic;
  final bool isMuted;
  final int activeTabIndex; // 0: Alarm, 1: World, 2: Chrono, 3: Focus
  final bool showSettingsModal;

  const AppPreferencesState({
    this.themePreference = 'light',
    this.highContrastMode = false,
    this.use24HourFormat = false,
    this.plainLanguageVedic = true,
    this.isMuted = false,
    this.activeTabIndex = 1,
    this.showSettingsModal = false,
  });

  AppPreferencesState copyWith({
    String? themePreference,
    bool? highContrastMode,
    bool? use24HourFormat,
    bool? plainLanguageVedic,
    bool? isMuted,
    int? activeTabIndex,
    bool? showSettingsModal,
  }) {
    return AppPreferencesState(
      themePreference: themePreference ?? this.themePreference,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      plainLanguageVedic: plainLanguageVedic ?? this.plainLanguageVedic,
      isMuted: isMuted ?? this.isMuted,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      showSettingsModal: showSettingsModal ?? this.showSettingsModal,
    );
  }
}

class AppPreferencesCubit extends Cubit<AppPreferencesState> {
  final void Function()? onStateChanged;

  AppPreferencesCubit({
    AppPreferencesState initialState = const AppPreferencesState(),
    this.onStateChanged,
  }) : super(initialState);

  void selectTab(int index) {
    if (state.activeTabIndex == index) return;
    emit(state.copyWith(activeTabIndex: index));
    onStateChanged?.call();
  }

  void toggleTheme() {
    HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1220);
    final nextTheme = state.themePreference == 'light'
        ? 'dark'
        : state.themePreference == 'dark'
        ? 'system'
        : 'light';
    emit(state.copyWith(themePreference: nextTheme));
    onStateChanged?.call();
  }

  void toggleHighContrast(bool enabled) {
    emit(state.copyWith(highContrastMode: enabled));
    onStateChanged?.call();
  }

  void toggle24HourFormat(bool enabled) {
    emit(state.copyWith(use24HourFormat: enabled));
    onStateChanged?.call();
  }

  void togglePlainLanguage(bool enabled) {
    emit(state.copyWith(plainLanguageVedic: enabled));
    onStateChanged?.call();
  }

  void toggleMute() {
    final nextMuted = !state.isMuted;
    HorologicalAudioEngine.instance.isMuted = nextMuted;
    if (nextMuted) {
      HorologicalAudioEngine.instance.stopBinauralFlow();
    } else {
      HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1200);
    }
    emit(state.copyWith(isMuted: nextMuted));
    onStateChanged?.call();
  }

  void toggleSettingsModal(bool show) {
    HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1150);
    emit(state.copyWith(showSettingsModal: show));
  }

  void hydrate({
    String? themePreference,
    bool? highContrastMode,
    bool? use24HourFormat,
    bool? plainLanguageVedic,
  }) {
    emit(
      state.copyWith(
        themePreference: themePreference ?? state.themePreference,
        highContrastMode: highContrastMode ?? state.highContrastMode,
        use24HourFormat: use24HourFormat ?? state.use24HourFormat,
        plainLanguageVedic: plainLanguageVedic ?? state.plainLanguageVedic,
      ),
    );
  }
}
