import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/ephemeris/noaa_ephemeris.dart';
import '../../core/theme/tidara_palette.dart';
import '../../models/horological_models.dart';
import '../../shared/widgets/liquid_glass_components.dart';

// Tactile Alarm Drum Sheet & Native Device Audio Browser
class TactileAlarmBottomSheet extends StatefulWidget {
  final AlarmRhythm? editingAlarm;
  final int defaultWakeMinutes;
  final int sunriseMinutesFromMidnight;
  final int sunsetMinutesFromMidnight;
  final String? customMusicName;
  final TidaraPalette palette;
  final Future<String?> Function() onSelectPhoneMusic;
  final ValueChanged<AlarmRhythm> onSave;
  final ValueChanged<String>? onDelete;
  final ValueChanged<Map<String, dynamic>> onTriggerDawnPreview;

  const TactileAlarmBottomSheet({
    super.key,
    required this.editingAlarm,
    required this.defaultWakeMinutes,
    required this.sunriseMinutesFromMidnight,
    required this.sunsetMinutesFromMidnight,
    required this.customMusicName,
    required this.palette,
    required this.onSelectPhoneMusic,
    required this.onSave,
    required this.onDelete,
    required this.onTriggerDawnPreview,
  });

  @override
  State<TactileAlarmBottomSheet> createState() =>
      _TactileAlarmBottomSheetState();
}

class _TactileAlarmBottomSheetState extends State<TactileAlarmBottomSheet> {
  late TextEditingController _titleController;
  late int _hour12;
  late int _minute;
  late String _period;
  late List<String> _selectedDays;
  late String _soundMeta;
  late bool _useCustomAudio;

  static const List<String> _kSoundProfiles = [
    'Soft gong | 15m gradual dawn light',
    'Chirping sitar & birds | No vibration',
    '432Hz Singing Bowl | 15m dawn swell',
    'Silent Nordic Haptic | Gentle pulse',
  ];

  static const List<String> _kWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _kQuickLabels = [
    'Solar Awakening',
    'Pre-Dawn Meditation',
    'Morning Run',
    'Flight / Travel',
  ];

  @override
  void initState() {
    super.initState();
    final int baseMins =
        widget.editingAlarm?.wakeMinutes24 ?? widget.defaultWakeMinutes;
    final int h24 = (baseMins ~/ 60) % 24;
    _minute = baseMins % 60;
    _period = h24 >= 12 ? 'PM' : 'AM';
    _hour12 = h24 % 12 == 0 ? 12 : h24 % 12;
    _titleController = TextEditingController(
      text: widget.editingAlarm?.title ?? 'Solar Awakening',
    );
    _selectedDays = List<String>.from(
      widget.editingAlarm?.weekdays ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    );
    _soundMeta = widget.editingAlarm?.soundMeta ?? _kSoundProfiles[0];
    _useCustomAudio = widget.editingAlarm?.useCustomAudio ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _currentMins24 => _period == 'AM'
      ? (_hour12 % 12) * 60 + _minute
      : ((_hour12 % 12) + 12) * 60 + _minute;

  void _applyMins24(int mins24) {
    final int norm = ((mins24 % 1440) + 1440) % 1440;
    final int h24 = norm ~/ 60;
    setState(() {
      _minute = norm % 60;
      _period = h24 >= 12 ? 'PM' : 'AM';
      _hour12 = h24 % 12 == 0 ? 12 : h24 % 12;
    });
  }

  @override
  Widget build(BuildContext context) {
    final TidaraPalette palette = widget.palette;
    final int preDawnMins =
        (widget.sunriseMinutesFromMidnight - 96 + 1440) % 1440;
    final int dawnMins = (widget.sunriseMinutesFromMidnight - 42 + 1440) % 1440;
    final int udayaMins = widget.sunriseMinutesFromMidnight;
    final int sandhyaMins = widget.sunsetMinutesFromMidnight;

    final List<Map<String, dynamic>> circadianPresets = [
      {
        'label': 'Optimal Dawn Window',
        'sub':
            '${CircadianEphemeris.formatMinutes12h(preDawnMins)} | 96m before sunrise',
        'mins': preDawnMins,
        'title': 'Optimal Dawn Window Meditation',
        'sound': _kSoundProfiles[2],
      },
      {
        'label': 'Dawn Awakening',
        'sub':
            '${CircadianEphemeris.formatMinutes12h(dawnMins)} | 42m before sunrise',
        'mins': dawnMins,
        'title': 'Solar Awakening',
        'sound': _kSoundProfiles[0],
      },
      {
        'label': 'Solar Sunrise',
        'sub':
            '${CircadianEphemeris.formatMinutes12h(udayaMins)} | Exact Sunrise',
        'mins': udayaMins,
        'title': 'Solar Sunrise',
        'sound': _kSoundProfiles[1],
      },
      {
        'label': 'Dusk Reflection',
        'sub':
            '${CircadianEphemeris.formatMinutes12h(sandhyaMins)} | Dusk reflection',
        'mins': sandhyaMins,
        'title': 'Dusk Reflection',
        'sound': _kSoundProfiles[2],
      },
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: palette.bgBase,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.strokeSubtle),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: palette.strokeSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.editingAlarm == null ? 'New Alarm' : 'Edit Alarm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GlassButton.iconOnly(
                    icon: Icons.close,
                    semanticLabel: 'Close sheet',
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Time Drum Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.strokeSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Hour Drum
                        GestureDetector(
                          onVerticalDragUpdate: (d) {
                            if (d.primaryDelta != null &&
                                d.primaryDelta!.abs() > 6) {
                              HorologicalAudioEngine.instance
                                  .playEscapementClick(pitchHz: 1120);
                              setState(() {
                                _hour12 =
                                    ((_hour12 -
                                            1 +
                                            (d.primaryDelta! < 0 ? 1 : -1) +
                                            12) %
                                        12) +
                                    1;
                              });
                            }
                          },
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  HorologicalAudioEngine.instance
                                      .playEscapementClick(pitchHz: 1120);
                                  setState(() => _hour12 = (_hour12 % 12) + 1);
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                _hour12.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                  fontFeatures: const [
                                    ui.FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  HorologicalAudioEngine.instance
                                      .playEscapementClick(pitchHz: 1120);
                                  setState(
                                    () =>
                                        _hour12 = ((_hour12 - 2 + 12) % 12) + 1,
                                  );
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                        // Minute Drum
                        GestureDetector(
                          onVerticalDragUpdate: (d) {
                            if (d.primaryDelta != null &&
                                d.primaryDelta!.abs() > 5) {
                              HorologicalAudioEngine.instance
                                  .playEscapementClick(pitchHz: 1240);
                              setState(() {
                                _minute =
                                    (_minute +
                                        (d.primaryDelta! < 0 ? 1 : -1) +
                                        60) %
                                    60;
                              });
                            }
                          },
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  HorologicalAudioEngine.instance
                                      .playEscapementClick(pitchHz: 1240);
                                  setState(() => _minute = (_minute + 1) % 60);
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                _minute.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                  fontFeatures: const [
                                    ui.FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  HorologicalAudioEngine.instance
                                      .playEscapementClick(pitchHz: 1240);
                                  setState(
                                    () => _minute = (_minute - 1 + 60) % 60,
                                  );
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: ['AM', 'PM'].map((p) {
                            final bool active = _period == p;
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: GlassButton.chip(
                                label: p,
                                isSelected: active,
                                accentColor: palette.accentPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                onPressed: () {
                                  HorologicalAudioEngine.instance
                                      .playEscapementClick(pitchHz: 1180);
                                  setState(() => _period = p);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            GlassButton.chip(
                              label: '-5m',
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              onPressed: () => _applyMins24(_currentMins24 - 5),
                            ),
                            const SizedBox(width: 6),
                            GlassButton.chip(
                              label: '+5m',
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              onPressed: () => _applyMins24(_currentMins24 + 5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2x2 Dynamic Circadian Presets Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.6,
                children: circadianPresets.map((preset) {
                  final int pMins = preset['mins'] as int;
                  final bool matched = _currentMins24 == pMins;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HorologicalAudioEngine.instance.strikeSingingBowl(
                        duration: 2.2,
                      );
                      _applyMins24(pMins);
                      setState(() {
                        _titleController.text = preset['title'] as String;
                        _soundMeta = preset['sound'] as String;
                        _useCustomAudio = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: matched
                            ? palette.accentPrimary.withValues(alpha: 0.14)
                            : palette.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: matched
                              ? palette.accentPrimary
                              : palette.strokeSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            preset['label'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: palette.accentPrimary,
                            ),
                          ),
                          Text(
                            preset['sub'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Label + Quick Chips + Weekday Selector
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.strokeSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Alarm Label',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _kQuickLabels.map((lbl) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GlassButton.chip(
                              label: lbl,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              onPressed: () {
                                setState(() => _titleController.text = lbl);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _kWeekdays.map((day) {
                        final bool active = _selectedDays.contains(day);
                        return GlassButton.chip(
                          label: day,
                          isSelected: active,
                          accentColor: palette.accentPrimary,
                          width: 38,
                          height: 32,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              if (active) {
                                if (_selectedDays.length > 1) {
                                  _selectedDays.remove(day);
                                }
                              } else {
                                _selectedDays.add(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Soundscape & Browse Phone Audio Row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.strokeSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          final int nextIdx =
                              (_kSoundProfiles.indexOf(_soundMeta) + 1) %
                              _kSoundProfiles.length;
                          HorologicalAudioEngine.instance.strikeSingingBowl(
                            duration: 2.0,
                          );
                          setState(() {
                            _soundMeta = _kSoundProfiles[nextIdx];
                            _useCustomAudio = false;
                          });
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _soundMeta.split(' | ').first,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              'Tap to cycle built-in chimes',
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GlassButton.secondary(
                      label: 'Browse Audio',
                      icon: Icons.folder_open_rounded,
                      accentColor: palette.accentPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      onPressed: () async {
                        final String? picked = await widget
                            .onSelectPhoneMusic();
                        if (picked != null && mounted) {
                          setState(() {
                            _soundMeta = '$picked | Custom Phone Audio';
                            _useCustomAudio = true;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Bar
              Row(
                children: [
                  if (widget.editingAlarm != null &&
                      widget.onDelete != null) ...[
                    GlassButton.destructive(
                      label: 'Delete',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      onPressed: () =>
                          widget.onDelete!(widget.editingAlarm!.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GlassButton.iconOnly(
                    icon: Icons.wb_sunny_outlined,
                    semanticLabel: 'Preview Alarm Tone',
                    tooltip: 'Preview Tone',
                    accentColor: palette.accentSolar,
                    onPressed: () {
                      widget.onTriggerDawnPreview({
                        'title': _titleController.text.trim().isEmpty
                            ? 'Solar Awakening'
                            : _titleController.text.trim(),
                        'time': CircadianEphemeris.formatMinutes12h(
                          _currentMins24,
                        ),
                        'soundMeta': _soundMeta,
                        'useCustomAudio': _useCustomAudio,
                        'isPreview': true,
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton.largeCta(
                      label: 'Save Alarm',
                      icon: Icons.check,
                      isPrimary: true,
                      accentColor: palette.accentPrimary,
                      onPressed: () {
                        HorologicalAudioEngine.instance.strikeSingingBowl(
                          duration: 2.8,
                        );
                        widget.onSave(
                          AlarmRhythm(
                            id:
                                widget.editingAlarm?.id ??
                                'alarm-${DateTime.now().millisecondsSinceEpoch}',
                            title: _titleController.text.trim().isEmpty
                                ? 'Solar Awakening'
                                : _titleController.text.trim(),
                            weekdays: _selectedDays,
                            soundMeta: _soundMeta,
                            useCustomAudio: _useCustomAudio,
                            enabled: true,
                            wakeMinutes24: _currentMins24,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 10. INTERACTIVE DEVICE AUDIO FILE BROWSER & ACOUSTIC LIBRARY SHEET
// ============================================================================
class DeviceAudioBrowserSheet extends StatefulWidget {
  final TidaraPalette palette;
  final String? currentTrackName;

  const DeviceAudioBrowserSheet({
    super.key,
    required this.palette,
    this.currentTrackName,
  });

  @override
  State<DeviceAudioBrowserSheet> createState() =>
      _DeviceAudioBrowserSheetState();
}

class _DeviceAudioBrowserSheetState extends State<DeviceAudioBrowserSheet> {
  bool _isScanning = true;
  List<Map<String, String>> _deviceFiles = [];
  String? _previewingTrackName;

  static const List<Map<String, dynamic>> _kBuiltInMasterTracks = [
    {
      'name': 'Morning Raga Bhairav (528Hz Sitar)',
      'folder': 'Tidara Studio | Lossless Synthesis',
      'path': 'synth://528',
      'freq': 528.0,
    },
    {
      'name': 'Tibetan Singing Bowl (432Hz Resonance)',
      'folder': 'Tidara Studio | Harmonic Chime',
      'path': 'synth://432',
      'freq': 432.0,
    },
    {
      'name': 'Optimal Dawn Window Temple Gong (396Hz)',
      'folder': 'Tidara Studio | Deep Bronze',
      'path': 'synth://396',
      'freq': 396.0,
    },
    {
      'name': 'Nordic Cedar & Harmonic Resonance (639Hz)',
      'folder': 'Tidara Studio | Warm Overtones',
      'path': 'synth://639',
      'freq': 639.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalAudioFiles();
  }

  Future<void> _loadLocalAudioFiles() async {
    final List<Map<String, String>> found = await HorologicalAudioEngine
        .instance
        .scanDeviceAudioFiles();
    if (!mounted) return;
    setState(() {
      _deviceFiles = found;
      _isScanning = false;
    });
  }

  @override
  void dispose() {
    HorologicalAudioEngine.instance.stopNativeAudio();
    super.dispose();
  }

  Future<void> _handleOpenNativePicker() async {
    final Map<String, String>? picked = await HorologicalAudioEngine.instance
        .pickSystemAudioFile();
    if (picked != null && mounted) {
      Navigator.of(
        context,
      ).pop({'name': picked['name']!, 'path': picked['uri'] ?? ''});
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Custom audio picker cancelled or unavailable. Select a tone below.',
          ),
        ),
      );
    }
  }

  void _togglePreviewTrack(String name, String path, {double freq = 432.0}) {
    if (_previewingTrackName == name) {
      HorologicalAudioEngine.instance.stopNativeAudio();
      setState(() => _previewingTrackName = null);
      return;
    }
    setState(() => _previewingTrackName = name);
    if (path.startsWith('synth://')) {
      HorologicalAudioEngine.instance.strikeSingingBowl(
        duration: 2.8,
        fundamental: freq,
        volume: 0.75,
      );
    } else {
      HorologicalAudioEngine.instance.playCustomUriOrSynth(
        uri: path,
        fundamental: freq,
        loop: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TidaraPalette palette = widget.palette;

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: palette.bgBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.strokeSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: palette.strokeSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Alarm & Focus Audio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    'Browse phone storage or preview acoustic chimes',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              GlassButton.iconOnly(
                icon: Icons.close,
                semanticLabel: 'Close audio browser',
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          GlassButton.primary(
            onPressed: _handleOpenNativePicker,
            icon: Icons.folder_open_rounded,
            label: 'Browse Phone Storage (MP3 / WAV / FLAC / M4A)',
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_isScanning)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Scanning Music, Ringtones & Alarms folders...',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  )
                else if (_deviceFiles.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'DISCOVERED ON THIS PHONE (${_deviceFiles.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.accentPrimary,
                      ),
                    ),
                  ),
                  ..._deviceFiles.map((file) {
                    final String name = file['name'] ?? 'Audio Track';
                    final String path = file['path'] ?? '';
                    final String folder = file['folder'] ?? 'Storage';
                    final bool isPreviewing = _previewingTrackName == name;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPreviewing
                              ? palette.accentPrimary
                              : palette.strokeSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          GlassButton.iconOnly(
                            onPressed: () => _togglePreviewTrack(name, path),
                            icon: isPreviewing
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            accentColor: palette.accentPrimary,
                            semanticLabel: isPreviewing
                                ? 'Stop previewing $name'
                                : 'Preview $name',
                            tooltip: isPreviewing ? 'Stop' : 'Play',
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Folder: $folder',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GlassButton.chip(
                            label: 'Use',
                            isSelected: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pop({'name': name, 'path': path});
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'BUILT-IN LOSSLESS CHIMES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.accentPrimary,
                    ),
                  ),
                ),
                ..._kBuiltInMasterTracks.map((track) {
                  final String name = track['name'] as String;
                  final String folder = track['folder'] as String;
                  final String path = track['path'] as String;
                  final double freq = track['freq'] as double;
                  final bool isPreviewing = _previewingTrackName == name;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPreviewing
                            ? palette.accentPrimary
                            : palette.strokeSubtle,
                      ),
                    ),
                    child: Row(
                      children: [
                        GlassButton.iconOnly(
                          onPressed: () =>
                              _togglePreviewTrack(name, path, freq: freq),
                          icon: isPreviewing
                              ? Icons.volume_up_rounded
                              : Icons.play_circle_outline,
                          accentColor: palette.accentPrimary,
                          semanticLabel: isPreviewing
                              ? 'Stop previewing $name'
                              : 'Preview $name',
                          tooltip: isPreviewing ? 'Stop' : 'Play',
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textPrimary,
                                ),
                              ),
                              Text(
                                folder,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GlassButton.chip(
                          label: 'Use',
                          isSelected: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pop({'name': name, 'path': path});
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
