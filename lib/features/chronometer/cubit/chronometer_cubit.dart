import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/audio/horological_audio_engine.dart';
import '../../../models/horological_models.dart';

class ChronometerState {
  final int elapsedMs;
  final bool isRunning;
  final List<ChronoLap> laps;

  const ChronometerState({
    this.elapsedMs = 0,
    this.isRunning = false,
    this.laps = const [],
  });

  ChronometerState copyWith({
    int? elapsedMs,
    bool? isRunning,
    List<ChronoLap>? laps,
  }) {
    return ChronometerState(
      elapsedMs: elapsedMs ?? this.elapsedMs,
      isRunning: isRunning ?? this.isRunning,
      laps: laps ?? this.laps,
    );
  }
}

class ChronometerCubit extends Cubit<ChronometerState> {
  final Stopwatch _stopwatch = Stopwatch();
  int _baseAccumulatedMs = 0;
  final ValueNotifier<int> elapsedNotifier = ValueNotifier<int>(0);
  final void Function()? onStateChanged;

  ChronometerCubit({this.onStateChanged}) : super(const ChronometerState());

  bool get isRunning => _stopwatch.isRunning;

  void onTick() {
    if (_stopwatch.isRunning) {
      final current = _baseAccumulatedMs + _stopwatch.elapsedMilliseconds;
      elapsedNotifier.value = current;
    }
  }

  void toggle() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _baseAccumulatedMs += _stopwatch.elapsedMilliseconds;
      _stopwatch.reset();
      elapsedNotifier.value = _baseAccumulatedMs;
      HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 840);
      emit(state.copyWith(isRunning: false, elapsedMs: _baseAccumulatedMs));
    } else {
      _stopwatch.reset();
      _stopwatch.start();
      HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1320);
      emit(state.copyWith(isRunning: true));
    }
    onStateChanged?.call();
  }

  void reset() {
    HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 940);
    _stopwatch.stop();
    _stopwatch.reset();
    _baseAccumulatedMs = 0;
    elapsedNotifier.value = 0;
    emit(state.copyWith(elapsedMs: 0, isRunning: false, laps: const []));
    onStateChanged?.call();
  }

  void recordLap() {
    if (!_stopwatch.isRunning) {
      if (elapsedNotifier.value > 0 || state.laps.isNotEmpty) {
        reset();
      }
      return;
    }

    final int totalMs = (elapsedNotifier.value ~/ 10) * 10;
    final int prevSum = state.laps.fold<int>(0, (acc, l) => acc + l.durationMs);
    final int lapDur = math.max(0, totalMs - prevSum);
    if (lapDur < 10) return;

    HorologicalAudioEngine.instance.playEscapementClick(pitchHz: 1120);
    final int nextNum = state.laps.length + 1;

    final int hrs = lapDur ~/ 3600000;
    final int mins = (lapDur % 3600000) ~/ 60000;
    final int secs = (lapDur % 60000) ~/ 1000;
    final int centis = (lapDur % 1000) ~/ 10;
    final String formatted = hrs > 0
        ? '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}'
        : '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}';

    final List<ChronoLap> rawList = [
      ChronoLap(
        id: DateTime.now().millisecondsSinceEpoch,
        number: nextNum.toString().padLeft(2, '0'),
        durationMs: lapDur,
        formatted: formatted,
      ),
      ...state.laps,
    ];

    final int minDur = rawList.map((l) => l.durationMs).reduce(math.min);
    final int maxDur = rawList.map((l) => l.durationMs).reduce(math.max);

    final updatedLaps = rawList.map((l) {
      return ChronoLap(
        id: l.id,
        number: l.number,
        durationMs: l.durationMs,
        formatted: l.formatted,
        isFastest: l.durationMs == minDur,
        isSlowest:
            rawList.length >= 3 && l.durationMs == maxDur && maxDur != minDur,
      );
    }).toList();

    emit(state.copyWith(laps: updatedLaps));
    onStateChanged?.call();
  }

  void hydrate(List<ChronoLap> laps) {
    emit(state.copyWith(laps: laps));
  }

  @override
  Future<void> close() {
    elapsedNotifier.dispose();
    return super.close();
  }
}
