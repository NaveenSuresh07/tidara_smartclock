import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/audio/horological_audio_engine.dart';
import '../../../core/ephemeris/noaa_ephemeris.dart';
import '../../../core/theme/tidara_palette.dart';
import '../../../models/horological_models.dart';
import '../../../shared/widgets/liquid_glass_components.dart';
import '../cubit/city_search_cubit.dart';

/// Modal bottom sheet allowing users to search and add any world city
/// using the Open-Meteo Geocoding & Weather API, with full offline fallback.
class CitySearchSheet extends StatefulWidget {
  final TidaraPalette palette;
  final ValueNotifier<DateTime> nowNotifier;
  final bool use24HourFormat;
  final List<String> pinnedCityIds;
  final ValueChanged<WorldCity> onCitySelected;
  final ValueChanged<String> onTogglePinCity;
  final CitySearchCubit? searchCubit;

  const CitySearchSheet({
    super.key,
    required this.palette,
    required this.nowNotifier,
    required this.use24HourFormat,
    required this.pinnedCityIds,
    required this.onCitySelected,
    required this.onTogglePinCity,
    this.searchCubit,
  });

  static Future<WorldCity?> show(
    BuildContext context, {
    required TidaraPalette palette,
    required ValueNotifier<DateTime> nowNotifier,
    required bool use24HourFormat,
    required List<String> pinnedCityIds,
    required ValueChanged<WorldCity> onCitySelected,
    required ValueChanged<String> onTogglePinCity,
    CitySearchCubit? searchCubit,
  }) {
    return showModalBottomSheet<WorldCity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        CitySearchCubit? cubit = searchCubit;
        if (cubit == null) {
          try {
            cubit = ctx.read<CitySearchCubit>();
          } catch (_) {
            cubit = null;
          }
        }
        return CitySearchSheet(
          palette: palette,
          nowNotifier: nowNotifier,
          use24HourFormat: use24HourFormat,
          pinnedCityIds: pinnedCityIds,
          onCitySelected: onCitySelected,
          onTogglePinCity: onTogglePinCity,
          searchCubit: cubit,
        );
      },
    );
  }

  @override
  State<CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<CitySearchSheet> {
  final TextEditingController _controller = TextEditingController();
  late CitySearchCubit _internalCubit;
  bool _ownsCubit = false;

  @override
  void initState() {
    super.initState();
    if (widget.searchCubit != null) {
      _internalCubit = widget.searchCubit!;
      _ownsCubit = false;
    } else {
      try {
        _internalCubit = context.read<CitySearchCubit>();
        _ownsCubit = false;
      } catch (_) {
        _internalCubit = CitySearchCubit();
        _ownsCubit = true;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsCubit) {
      _internalCubit.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.78,
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: palette.strokeSubtle),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: palette.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global City Search',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Powered by Open-Meteo API • Full Offline Fallback',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GlassButton.iconOnly(
                  icon: Icons.close,
                  semanticLabel: 'Close search',
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.strokeSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: palette.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('city_search_input'),
                      controller: _controller,
                      autofocus: false,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search city name (e.g. Oslo, Chicago, Nairobi)...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        _internalCubit.search(val, debounce: true);
                      },
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _controller.clear();
                        _internalCubit.clearSearch();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.clear,
                          size: 18,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content body based on Cubit state
          Expanded(
            child: BlocBuilder<CitySearchCubit, CitySearchState>(
              bloc: _internalCubit,
              builder: (context, state) {
                if (state is CitySearchLoading) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(
                              palette.accentPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Searching global coordinates for "${state.query}"...',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (state is CitySearchEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 40,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No cities found for "${state.query}"',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          if (state.isOffline) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Device is currently offline. Connect to internet to search any city worldwide.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                if (state is CitySearchError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 40,
                            color: palette.accentPrimary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            state.isOffline
                                ? 'Network Unavailable'
                                : 'Search Error',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final List<WorldCity> cities = state is CitySearchLoaded
                    ? state.cities
                    : (state is CitySearchInitial
                          ? state.defaultCities
                          : kWorldCities);

                final bool isOffline =
                    state is CitySearchLoaded && state.isOffline;
                final bool isCacheHit =
                    state is CitySearchLoaded && state.isCacheHit;
                final bool showBanner = isOffline || isCacheHit;

                return Column(
                  children: [
                    if (showBanner)
                      Container(
                        key: ValueKey(
                          isCacheHit
                              ? 'offline_cached_data_indicator'
                              : 'offline_bundled_data_indicator',
                        ),
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: palette.accentPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOffline
                                  ? Icons.wifi_off
                                  : Icons.storage_rounded,
                              size: 14,
                              color: palette.accentPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isCacheHit
                                    ? 'Offline Mode: Displaying cached search results'
                                    : 'Offline Mode: Showing bundled local horological cities',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        key: const ValueKey('city_search_results_list'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: cities.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: palette.strokeSubtle),
                        itemBuilder: (ctx, idx) {
                          final city = cities[idx];
                          final bool isPinned = widget.pinnedCityIds.contains(
                            city.id,
                          );

                          return ValueListenableBuilder<DateTime>(
                            valueListenable: widget.nowNotifier,
                            builder: (context, now, _) {
                              final DateTime utc = now.toUtc();
                              final int off = city.effectiveOffsetMinutes(utc);
                              final DateTime cNow = utc.add(
                                Duration(minutes: off),
                              );
                              final String cTime =
                                  CircadianEphemeris.formatMinutes12h(
                                    cNow.hour * 60 + cNow.minute,
                                    use24Hour: widget.use24HourFormat,
                                  );

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                onTap: () {
                                  HorologicalAudioEngine.instance
                                      .playEscapementClick(pitchHz: 1260);
                                  widget.onCitySelected(city);
                                  Navigator.of(context).pop(city);
                                },
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${city.name}, ${city.country}',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: palette.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (city.currentWeatherSummary != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.surfaceCard,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: palette.strokeSubtle,
                                          ),
                                        ),
                                        child: Text(
                                          city.currentWeatherSummary!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: palette.accentPrimary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${city.effectiveTzCode(utc)} • GMT ${city.effectiveGmtOffset(utc)} • ${city.lat.toStringAsFixed(1)}°, ${city.lon.toStringAsFixed(1)}°',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: palette.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cTime,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: palette.accentPrimary,
                                        fontFeatures: const [
                                          ui.FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    GlassButton.iconOnly(
                                      icon: isPinned
                                          ? Icons.push_pin
                                          : Icons.push_pin_outlined,
                                      semanticLabel: isPinned
                                          ? 'Unpin ${city.name}'
                                          : 'Pin ${city.name}',
                                      tooltip: isPinned ? 'Unpin' : 'Pin',
                                      accentColor: isPinned
                                          ? palette.accentPrimary
                                          : null,
                                      onPressed: () {
                                        widget.onTogglePinCity(city.id);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
