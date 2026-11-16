import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/services/native_platform_bridge.dart';
import '../../core/theme/tidara_palette.dart';
import '../../shared/widgets/liquid_glass_components.dart';

/// Shows a liquid glass modal bottom sheet for browsing phone audio or selecting preset singing bowls.
Future<String?> showCustomAudioSelectionSheet(
  BuildContext context, {
  required TidaraPalette palette,
}) async {
  final initialTracks = await NativePlatformBridge.listDeviceAudio();
  final tracks = List<AudioTrackItem>.from(initialTracks);
  if (!context.mounted) return null;

  String? pendingSelection;
  String? activePreviewName;
  String? errorBanner;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return GlassBottomSheet(
            palette: palette,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sound Selection & Custom Audio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Browse your device storage for audio files (MP3/WAV/AAC) or choose a calibrated resonance preset.',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton.primary(
                      label: 'Browse Phone Audio Files...',
                      icon: Icons.folder_open_rounded,
                      accentColor: palette.accentPrimary,
                      onPressed: () async {
                        await NativePlatformBridge.stopAudio();
                        setSheetState(() {
                          activePreviewName = null;
                          errorBanner = null;
                        });
                        final picked =
                            await NativePlatformBridge.pickAudioFileFromDevice();
                        if (picked != null) {
                          final name = picked['name']!;
                          final path = picked['path']!;
                          setSheetState(() {
                            tracks.removeWhere((t) => t['name'] == name);
                            tracks.insert(0, picked);
                            pendingSelection = name;
                            errorBanner = null;
                          });
                          final played =
                              await NativePlatformBridge.playAudioFile(
                                path,
                                loop: false,
                              );
                          if (played) {
                            setSheetState(() => activePreviewName = name);
                          }
                        } else {
                          setSheetState(
                            () => errorBanner =
                                'Selection cancelled or audio format is unsupported.',
                          );
                        }
                      },
                    ),
                  ),
                  if (errorBanner != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorBanner!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.errorColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Column(
                    children: [
                      for (final preset in [
                        ('432Hz Tibetan Bowl', 432.0),
                        ('528Hz Solfeggio Chime', 528.0),
                        ('639Hz Dawn Resonance', 639.0),
                      ]) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: pendingSelection == preset.$1
                                ? palette.accentPrimary.withValues(alpha: 0.15)
                                : palette.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: pendingSelection == preset.$1
                                  ? palette.accentPrimary
                                  : palette.strokeSubtle,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setSheetState(() {
                              pendingSelection = preset.$1;
                              errorBanner = null;
                            }),
                            child: Row(
                              children: [
                                Icon(
                                  pendingSelection == preset.$1
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18,
                                  color: pendingSelection == preset.$1
                                      ? palette.accentPrimary
                                      : palette.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    preset.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GlassButton.iconOnly(
                                  icon: activePreviewName == preset.$1
                                      ? Icons.stop_rounded
                                      : Icons.play_arrow_rounded,
                                  iconSize: 18,
                                  isPrimary: activePreviewName == preset.$1,
                                  iconColor: activePreviewName == preset.$1
                                      ? Colors.white
                                      : palette.accentPrimary,
                                  accentColor: palette.accentPrimary,
                                  palette: palette,
                                  width: 32,
                                  height: 32,
                                  minWidth: 48,
                                  minHeight: 48,
                                  isCircle: true,
                                  padding: EdgeInsets.zero,
                                  semanticLabel: activePreviewName == preset.$1
                                      ? 'Stop previewing ${preset.$1}'
                                      : 'Preview ${preset.$1}',
                                  tooltip: activePreviewName == preset.$1
                                      ? 'Stop'
                                      : 'Play',
                                  onPressed: () {
                                    if (activePreviewName == preset.$1) {
                                      NativePlatformBridge.stopAudio();
                                      setSheetState(
                                        () => activePreviewName = null,
                                      );
                                    } else {
                                      NativePlatformBridge.playWavBytes(
                                        HorologicalAudioEngine.buildSynthesizedBowlWav(
                                          frequencyHz: preset.$2,
                                          durationSeconds: 2.5,
                                        ),
                                      );
                                      setSheetState(() {
                                        pendingSelection = preset.$1;
                                        activePreviewName = preset.$1;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                  if (tracks.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final item = tracks[idx];
                          final name = item['name'] ?? 'Audio File';
                          final path = item['path'] ?? '';
                          final isSelected = pendingSelection == name;
                          final isPlaying = activePreviewName == name;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.accentPrimary.withValues(
                                      alpha: 0.15,
                                    )
                                  : palette.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? palette.accentPrimary
                                    : palette.strokeSubtle,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setSheetState(() => pendingSelection = name),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.library_music_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? palette.accentPrimary
                                        : palette.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  GlassButton.iconOnly(
                                    icon: isPlaying
                                        ? Icons.stop_rounded
                                        : Icons.play_arrow_rounded,
                                    iconSize: 18,
                                    isPrimary: isPlaying,
                                    iconColor: isPlaying
                                        ? Colors.white
                                        : palette.accentPrimary,
                                    accentColor: palette.accentPrimary,
                                    palette: palette,
                                    width: 32,
                                    height: 32,
                                    minWidth: 48,
                                    minHeight: 48,
                                    isCircle: true,
                                    padding: EdgeInsets.zero,
                                    semanticLabel: isPlaying
                                        ? 'Stop previewing $name'
                                        : 'Preview $name',
                                    tooltip: isPlaying ? 'Stop' : 'Play',
                                    onPressed: () async {
                                      if (isPlaying) {
                                        await NativePlatformBridge.stopAudio();
                                        setSheetState(
                                          () => activePreviewName = null,
                                        );
                                      } else {
                                        final ok =
                                            await NativePlatformBridge.playAudioFile(
                                              path,
                                              loop: false,
                                            );
                                        setSheetState(() {
                                          if (ok) {
                                            pendingSelection = name;
                                            activePreviewName = name;
                                          } else {
                                            errorBanner =
                                                'File is no longer accessible.';
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: GlassButton.secondary(
                          label: 'Cancel',
                          palette: palette,
                          onPressed: () {
                            NativePlatformBridge.stopAudio();
                            Navigator.of(ctx).pop(null);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassButton.primary(
                          label: 'Confirm Selection',
                          icon: Icons.check_rounded,
                          accentColor: palette.accentPrimary,
                          onPressed: () {
                            NativePlatformBridge.stopAudio();
                            Navigator.of(ctx).pop(pendingSelection);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
