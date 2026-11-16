import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/native_platform_bridge.dart';

/// Procedural 432Hz/528Hz/639Hz WAV Synthesizer & Native Audio Bridge
class HorologicalAudioEngine {
  HorologicalAudioEngine._();
  static final HorologicalAudioEngine instance = HorologicalAudioEngine._();

  bool isMuted = false;
  String? customAudioName;
  String? customAudioPath;

  int _flowSessionId = 0;
  Timer? _pendulumTimer;
  Timer? _binauralPulseTimer;
  Timer? _alarmLoopTimer;
  Timer? _shimmerHapticTimer;
  DateTime? _alarmSwellStart;

  /// Ensures that validated 16-bit PCM WAV preset files exist in durable storage
  /// for background playback through TidaraAlarmReceiver.
  Future<Map<String, String>> ensurePresetWavFilesExist(
    String directoryPath,
  ) async {
    final dir = Directory(
      '$directoryPath${Platform.pathSeparator}preset_audio',
    );
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    NativePlatformBridge.setPresetAudioDirectory(dir.path);

    final preset432 = File(
      '${dir.path}${Platform.pathSeparator}preset_432hz.wav',
    );
    if (!preset432.existsSync() || preset432.lengthSync() < 100) {
      try {
        final bytes = synthesizeSingingBowlWav(
          fundamentalHz: 432.0,
          durationSec: 3.5,
        );
        preset432.writeAsBytesSync(bytes, flush: true);
      } catch (_) {}
    }

    final preset528 = File(
      '${dir.path}${Platform.pathSeparator}preset_528hz.wav',
    );
    if (!preset528.existsSync() || preset528.lengthSync() < 100) {
      try {
        final bytes = synthesizeSingingBowlWav(
          fundamentalHz: 528.0,
          durationSec: 3.5,
        );
        preset528.writeAsBytesSync(bytes, flush: true);
      } catch (_) {}
    }

    final preset639 = File(
      '${dir.path}${Platform.pathSeparator}preset_639hz.wav',
    );
    if (!preset639.existsSync() || preset639.lengthSync() < 100) {
      try {
        final bytes = synthesizeSingingBowlWav(
          fundamentalHz: 639.0,
          durationSec: 3.5,
        );
        preset639.writeAsBytesSync(bytes, flush: true);
      } catch (_) {}
    }

    final paths = <String, String>{
      '432Hz Tibetan Bowl': preset432.absolute.path,
      '528Hz Solfeggio Chime': preset528.absolute.path,
      '639Hz Dawn Resonance': preset639.absolute.path,
    };

    paths.forEach((label, p) {
      NativePlatformBridge.registerCustomAudioPath(label, p);
    });

    return paths;
  }

  /// Synthesizes a 16-bit mono PCM WAV buffer with inharmonic Tibetan bowl partials
  Uint8List synthesizeSingingBowlWav({
    double fundamentalHz = 432.0,
    double durationSec = 2.6,
    double masterVolume = 0.65,
  }) {
    const int sampleRate = 22050;
    final int numSamples = (sampleRate * durationSec).round();
    final int dataSize = numSamples * 2;
    final ByteData buffer = ByteData(44 + dataSize);

    void writeAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    final List<List<double>> partials = [
      [1.0, 0.52, durationSec],
      [2.756, 0.24, durationSec * 0.72],
      [5.404, 0.11, durationSec * 0.48],
      [8.93, 0.05, durationSec * 0.28],
    ];

    final double vol = masterVolume.clamp(0.05, 1.0);
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double attack = (t / 0.035).clamp(0.0, 1.0);
      double sample = 0.0;

      for (final p in partials) {
        final double ratio = p[0];
        final double amp = p[1];
        final double decay = p[2];
        final double env = math.exp(-3.8 * t / decay);
        final double vibrato = 1.0 + 0.0018 * math.sin(2 * math.pi * 4.2 * t);
        sample +=
            amp *
            env *
            math.sin(2 * math.pi * fundamentalHz * ratio * vibrato * t);
      }

      sample *= attack * vol;
      final int pcm16 = (sample.clamp(-1.0, 1.0) * 32767.0).round();
      buffer.setInt16(44 + i * 2, pcm16, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// Synthesizes a crisp watch escapement click WAV
  Uint8List synthesizeEscapementClickWav({double pitchHz = 1100.0}) {
    const int sampleRate = 22050;
    const double durationSec = 0.032;
    final int numSamples = (sampleRate * durationSec).round();
    final int dataSize = numSamples * 2;
    final ByteData buffer = ByteData(44 + dataSize);

    void writeAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double freq = pitchHz * math.exp(-38.0 * t);
      final double env = math.exp(-110.0 * t);
      final double sample = 0.55 * env * math.sin(2 * math.pi * freq * t);
      final int pcm16 = (sample.clamp(-1.0, 1.0) * 32767.0).round();
      buffer.setInt16(44 + i * 2, pcm16, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  Future<bool> _dispatchWavToNative(
    Uint8List wavBytes, {
    bool bypassMute = false,
  }) async {
    try {
      return await NativePlatformBridge.playWavBytes(wavBytes);
    } catch (_) {
      return false;
    }
  }

  void triggerHaptic({bool heavy = false}) {
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void playEscapementClick({double pitchHz = 1100.0}) {
    triggerHaptic(heavy: pitchHz < 950);
    if (isMuted) return;
    final Uint8List wav = synthesizeEscapementClickWav(pitchHz: pitchHz);
    _dispatchWavToNative(wav).then((played) {
      if (!played) {
        HapticFeedback.selectionClick();
      }
    });
  }

  void strikeSingingBowl({
    double duration = 2.6,
    double fundamental = 432.0,
    bool bypassMute = false,
    double volume = 0.70,
  }) {
    triggerHaptic(heavy: true);
    if (isMuted && !bypassMute) return;

    final Uint8List wav = synthesizeSingingBowlWav(
      fundamentalHz: fundamental,
      durationSec: duration.clamp(0.4, 4.5),
      masterVolume: volume,
    );

    _dispatchWavToNative(wav, bypassMute: bypassMute).then((played) {
      if (!played) {
        HapticFeedback.selectionClick();
        _shimmerHapticTimer?.cancel();
        int pulses = 0;
        _shimmerHapticTimer = Timer.periodic(
          const Duration(milliseconds: 180),
          (t) {
            pulses++;
            if (pulses > 3 || (isMuted && !bypassMute)) {
              t.cancel();
              return;
            }
            HapticFeedback.lightImpact();
          },
        );
      }
    });
  }

  void setCustomPhoneAudio(String trackName, {String? path}) {
    customAudioName = trackName.trim();
    customAudioPath = path;
    triggerHaptic(heavy: true);
    if (path != null && path.isNotEmpty) {
      playCustomUriOrSynth(uri: path, fundamental: 528.0);
    } else {
      strikeSingingBowl(duration: 2.2, fundamental: 528.0);
    }
  }

  Future<Map<String, String>?> pickSystemAudioFile() async {
    try {
      final res = await NativePlatformBridge.pickAudioFileFromDevice();
      if (res != null) {
        setCustomPhoneAudio(res['name']!, path: res['path']);
        return res;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, String>>> scanDeviceAudioFiles() async {
    return NativePlatformBridge.listDeviceAudio();
  }

  Future<void> playCustomUriOrSynth({
    String? uri,
    double fundamental = 528.0,
    bool loop = false,
    bool bypassMute = false,
  }) async {
    if (isMuted && !bypassMute) return;
    final String? targetUri = uri ?? customAudioPath;
    if (targetUri != null &&
        targetUri.isNotEmpty &&
        !targetUri.startsWith('synth://')) {
      try {
        final ok = await NativePlatformBridge.playAudioFile(
          targetUri,
          loop: loop,
        );
        if (ok) return;
      } catch (_) {}
    }
    strikeSingingBowl(
      duration: 2.8,
      fundamental: fundamental,
      bypassMute: bypassMute,
      volume: 0.70,
    );
  }

  Future<void> stopNativeAudio() async {
    try {
      await NativePlatformBridge.stopAudio();
    } catch (_) {}
  }

  void toggleBinauralFlow(bool enable, {String mode = 'bowl'}) {
    stopBinauralFlow();
    if (isMuted || !enable || mode == 'silent') return;

    final int currentSession = ++_flowSessionId;
    if (mode == 'pendulum') {
      playEscapementClick(pitchHz: 1180);
      bool isTick = false;
      _pendulumTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isMuted && _flowSessionId == currentSession) {
          playEscapementClick(pitchHz: isTick ? 1180 : 940);
          isTick = !isTick;
        }
      });
    } else if (mode == 'custom' &&
        customAudioPath != null &&
        !customAudioPath!.startsWith('synth://')) {
      playCustomUriOrSynth(
        uri: customAudioPath,
        fundamental: 528.0,
        loop: true,
      );
    } else {
      final double freq = mode == 'tanpura'
          ? 528.0
          : mode == 'custom'
          ? 396.0
          : 432.0;
      strikeSingingBowl(duration: 3.0, fundamental: freq, volume: 0.55);
      _binauralPulseTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!isMuted && _flowSessionId == currentSession) {
          strikeSingingBowl(duration: 3.0, fundamental: freq, volume: 0.55);
        }
      });
    }
  }

  void stopBinauralFlow() {
    _flowSessionId++;
    _pendulumTimer?.cancel();
    _pendulumTimer = null;
    _binauralPulseTimer?.cancel();
    _binauralPulseTimer = null;
    _shimmerHapticTimer?.cancel();
    _shimmerHapticTimer = null;
    stopNativeAudio();
  }

  double get currentAlarmSwellProgress {
    if (_alarmSwellStart == null) return 0.35;
    final int elapsed = DateTime.now().difference(_alarmSwellStart!).inSeconds;
    return (0.35 + 0.65 * (elapsed / 900.0).clamp(0.0, 1.0)).clamp(0.35, 1.0);
  }

  void startDawnAlarmLoop({bool useCustom = false}) {
    stopDawnAlarmLoop();
    _alarmSwellStart = DateTime.now();
    if (useCustom &&
        customAudioPath != null &&
        !customAudioPath!.startsWith('synth://')) {
      playCustomUriOrSynth(uri: customAudioPath, loop: true, bypassMute: true);
      return;
    }
    strikeSingingBowl(
      duration: 3.8,
      fundamental: useCustom ? 528.0 : 432.0,
      bypassMute: true,
      volume: 0.50,
    );
    _alarmLoopTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      HapticFeedback.heavyImpact();
      strikeSingingBowl(
        duration: 3.8,
        fundamental: useCustom ? 528.0 : 432.0,
        bypassMute: true,
        volume: currentAlarmSwellProgress,
      );
    });
  }

  void stopDawnAlarmLoop() {
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = null;
    _shimmerHapticTimer?.cancel();
    _shimmerHapticTimer = null;
    _alarmSwellStart = null;
    stopNativeAudio();
  }

  void dispose() {
    stopBinauralFlow();
    stopDawnAlarmLoop();
  }

  static Uint8List buildSynthesizedBowlWav({
    double frequencyHz = 432.0,
    double durationSeconds = 1.8,
  }) {
    const int sampleRate = 22050;
    final int numSamples = (sampleRate * durationSeconds).toInt();
    final int dataSize = numSamples * 2;
    final ByteData buffer = ByteData(44 + dataSize);

    // RIFF WAVE Header
    const List<int> riff = [0x52, 0x49, 0x46, 0x46];
    const List<int> wave = [0x57, 0x41, 0x56, 0x45];
    const List<int> fmt = [0x66, 0x6D, 0x74, 0x20];
    const List<int> data = [0x64, 0x61, 0x74, 0x61];
    for (int i = 0; i < 4; i++) {
      buffer.setUint8(i, riff[i]);
      buffer.setUint8(8 + i, wave[i]);
      buffer.setUint8(12 + i, fmt[i]);
      buffer.setUint8(36 + i, data[i]);
    }
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double env = math.exp(-2.2 * t);
      final double fundamental = math.sin(2.0 * math.pi * frequencyHz * t);
      final double overtone =
          0.35 * math.sin(2.0 * math.pi * (frequencyHz * 1.5) * t);
      final double sample = ((fundamental + overtone) * 0.65 * env).clamp(
        -1.0,
        1.0,
      );
      buffer.setInt16(44 + i * 2, (sample * 32767).toInt(), Endian.little);
    }
    return buffer.buffer.asUint8List();
  }
}
