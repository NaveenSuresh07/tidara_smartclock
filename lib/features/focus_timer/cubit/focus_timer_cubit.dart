import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/audio/horological_audio_engine.dart';
import '../../../models/horological_models.dart';

class FocusTimerState {
  final String activePresetId;
  final int? customTotalSec;
  final bool focusRunning;
  final double remainingSec;
  final double progress;
  final int hourglassFlipCount;
  final int completedGhatikas;
  final String activeSoundscapeId;
  final String? customMusicName;
  final bool isInverting;

  const FocusTimerState({
    this.activePresetId = '24m',
    this.customTotalSec,
    this.focusRunning = false,
    this.remainingSec = 24 * 60.0,
    this.progress = 0.0,
    this.hourglassFlipCount = 0,
    this.completedGhatikas = 0,
    this.activeSoundscapeId = 'bowl',
    this.customMusicName,
    this.isInverting = false,
  });

  int get effectiveTotalSec {
    if (customTotalSec != null) return customTotalSec!;
    final FocusPreset p = kFocusPresets.firstWhere(
      (x) => x.id == activePresetId,
      orElse: () => kFocusPresets[1],
    );
    return p.totalSec;
  }

  FocusTimerState copyWith({
    String? activePresetId,
    int? customTotalSec,
    bool clearCustomTotalSec = false,
    bool? focusRunning,
    double? remainingSec,
    double? progress,
    int? hourglassFlipCount,
    int? completedGhatikas,
    String? activeSoundscapeId,
    String? customMusicName,
    bool? isInverting,
  }) {
    return FocusTimerState(
      activePresetId: activePresetId ?? this.activePresetId,
      customTotalSec: clearCustomTotalSec
          ? null
          : (customTotalSec ?? this.customTotalSec),
      focusRunning: focusRunning ?? this.focusRunning,
      remainingSec: remainingSec ?? this.remainingSec,
      progress: progress ?? this.progress,
      hourglassFlipCount: hourglassFlipCount ?? this.hourglassFlipCount,
      completedGhatikas: completedGhatikas ?? this.completedGhatikas,
      activeSoundscapeId: activeSoundscapeId ?? this.activeSoundscapeId,
      customMusicName: customMusicName ?? this.customMusicName,
      isInverting: isInverting ?? this.isInverting,
    );
  }
}

class FocusTimerCubit extends Cubit<FocusTimerState> {
  final Stopwatch _stopwatch = Stopwatch();
  double _baseRemainingSec = 24 * 60.0;
  Timer? _inversionTimer;

  final ValueNotifier<double> remainingNotifier = ValueNotifier<double>(
    24 * 60.0,
  );
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  final void Function()? onStateChanged;

  FocusTimerCubit({this.onStateChanged}) : super(const FocusTimerState());

  bool get isRunning => state.focusRunning;

  void onTick() {
    if (!state.focusRunning || state.isInverting) return;
    final double elapsedSec = _stopwatch.elapsedMicroseconds / 1000000.0;
    final double nextRem = math.max(0.0, _baseRemainingSec - elapsedSec);
    remainingNotifier.value = nextRem;

    final int totalSec = state.effectiveTotalSec;
    final double nextProg = totalSec > 0
        ? (1.0 - (nextRem / totalSec)).clamp(0.0, 1.0)
        : 1.0;
    progressNotifier.value = nextProg;

    if (nextRem <= 0.0) {
      completeSession();
    }
  }

  void completeSession() {
    _stopwatch.stop();
    _stopwatch.reset();
    emit(
      state.copyWith(
        focusRunning: false,
        completedGhatikas: state.completedGhatikas + 1,
        remainingSec: 0.0,
        progress: 1.0,
      ),
    );
    remainingNotifier.value = 0.0;
    progressNotifier.value = 1.0;
    HorologicalAudioEngine.instance.stopBinauralFlow();
    HorologicalAudioEngine.instance.strikeSingingBowl(
      duration: 4.2,
      fundamental: 432.0,
      bypassMute: true,
    );
    onStateChanged?.call();
  }

  void toggleTimer() {
    if (!state.focusRunning && remainingNotifier.value <= 0.0) {
      final double fullSec = state.effectiveTotalSec.toDouble();
      HorologicalAudioEngine.instance.strikeSingingBowl(duration: 2.6);
      executeInversion(
        targetSec: fullSec,
        targetProgress: 0.0,
        autoStart: true,
      );
      return;
    }

    if (state.focusRunning) {
      final double elapsedSec = _stopwatch.elapsedMicroseconds / 1000000.0;
      _baseRemainingSec = math.max(0.0, _baseRemainingSec - elapsedSec);
      _stopwatch.stop();
      _stopwatch.reset();
      emit(
        state.copyWith(focusRunning: false, remainingSec: _baseRemainingSec),
      );
      HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 880);
      HorologicalAudioEngine.instance.stopBinauralFlow();
    } else {
      _baseRemainingSec = remainingNotifier.value;
      _stopwatch.reset();
      _stopwatch.start();
      emit(state.copyWith(focusRunning: true));
      HorologicalAudioEngine.instance.strikeSingingBowl(duration: 2.6);
      HorologicalAudioEngine.instance.toggleBinauralFlow(
        true,
        mode: state.activeSoundscapeId,
      );
    }
    onStateChanged?.call();
  }

  void selectPreset(FocusPreset preset) {
    _stopwatch.stop();
    _stopwatch.reset();
    HorologicalAudioEngine.instance.stopBinauralFlow();
    HorologicalAudioEngine.instance.strikeSingingBowl(duration: 2.8);

    emit(
      state.copyWith(
        activePresetId: preset.id,
        clearCustomTotalSec: true,
        focusRunning: false,
      ),
    );

    executeInversion(
      targetSec: preset.totalSec.toDouble(),
      targetProgress: 0.0,
      autoStart: false,
    );
    onStateChanged?.call();
  }

  void setCustomDuration(int minutes) {
    final int nextSec = minutes * 60;
    _stopwatch.stop();
    _stopwatch.reset();
    HorologicalAudioEngine.instance.stopBinauralFlow();

    emit(state.copyWith(customTotalSec: nextSec, focusRunning: false));

    executeInversion(
      targetSec: nextSec.toDouble(),
      targetProgress: 0.0,
      autoStart: false,
    );
    onStateChanged?.call();
  }

  void manualHourglassFlip() {
    final bool wasRunning = state.focusRunning;
    final double fullSec = state.effectiveTotalSec.toDouble();

    HorologicalAudioEngine.instance.strikeSingingBowl(duration: 2.4);
    _stopwatch.stop();
    _stopwatch.reset();

    executeInversion(
      targetSec: fullSec,
      targetProgress: 0.0,
      autoStart: wasRunning,
    );
  }

  void restoreSessionState({
    required double targetSec,
    required double targetProgress,
    required bool autoStart,
  }) {
    executeInversion(
      targetSec: targetSec,
      targetProgress: targetProgress,
      autoStart: autoStart,
    );
  }

  void executeInversion({
    required double targetSec,
    required double targetProgress,
    required bool autoStart,
  }) {
    _inversionTimer?.cancel();
    emit(
      state.copyWith(
        isInverting: true,
        hourglassFlipCount: state.hourglassFlipCount + 1,
      ),
    );
    remainingNotifier.value = targetSec;

    _inversionTimer = Timer(const Duration(milliseconds: 220), () {
      _baseRemainingSec = targetSec;
      remainingNotifier.value = targetSec;
      progressNotifier.value = targetProgress;
      _stopwatch.reset();

      if (autoStart) {
        _stopwatch.start();
        emit(
          state.copyWith(
            isInverting: false,
            focusRunning: true,
            remainingSec: targetSec,
            progress: targetProgress,
          ),
        );
        HorologicalAudioEngine.instance.toggleBinauralFlow(
          true,
          mode: state.activeSoundscapeId,
        );
      } else {
        emit(
          state.copyWith(
            isInverting: false,
            focusRunning: false,
            remainingSec: targetSec,
            progress: targetProgress,
          ),
        );
      }
      onStateChanged?.call();
    });
  }

  void changeSoundscape(String nextId) {
    emit(state.copyWith(activeSoundscapeId: nextId));
    if (state.focusRunning) {
      HorologicalAudioEngine.instance.toggleBinauralFlow(true, mode: nextId);
    } else if (nextId != 'silent') {
      HorologicalAudioEngine.instance.strikeSingingBowl(
        duration: 2.2,
        fundamental: nextId == 'tanpura' ? 528.0 : 432.0,
      );
    }
    onStateChanged?.call();
  }

  void setCustomMusic(String name) {
    emit(state.copyWith(customMusicName: name, activeSoundscapeId: 'custom'));
    HorologicalAudioEngine.instance.customAudioName = name;
    if (state.focusRunning) {
      HorologicalAudioEngine.instance.toggleBinauralFlow(true, mode: 'custom');
    }
    onStateChanged?.call();
  }

  void hydrate({
    String? activePresetId,
    int? customTotalSec,
    String? activeSoundscapeId,
    String? customMusicName,
    int? completedGhatikas,
  }) {
    emit(
      state.copyWith(
        activePresetId: activePresetId ?? state.activePresetId,
        customTotalSec: customTotalSec,
        activeSoundscapeId: activeSoundscapeId ?? state.activeSoundscapeId,
        customMusicName: customMusicName ?? state.customMusicName,
        completedGhatikas: completedGhatikas ?? state.completedGhatikas,
      ),
    );
    final double initSec = state.effectiveTotalSec.toDouble();
    _baseRemainingSec = initSec;
    remainingNotifier.value = initSec;
    progressNotifier.value = 0.0;
  }

  @override
  Future<void> close() {
    _inversionTimer?.cancel();
    remainingNotifier.dispose();
    progressNotifier.dispose();
    return super.close();
  }
}
