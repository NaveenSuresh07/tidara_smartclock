import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/audio/horological_audio_engine.dart';
import '../../core/ephemeris/noaa_ephemeris.dart';
import '../../core/theme/tidara_palette.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/horological_models.dart';
import 'armillary_globe_widget.dart';
import 'cubit/city_search_cubit.dart';
import 'ui/city_search_sheet.dart';
import '../../shared/widgets/liquid_glass_components.dart';

class WorldClockTab extends StatefulWidget {
  final TidaraPalette palette;
  final CircadianEphemeris ephem;
  final WorldCity selectedCity;
  final List<String> pinnedCityIds;
  final List<WorldCity> customCities;
  final ValueNotifier<DateTime> nowNotifier;
  final bool use24HourFormat;
  final ValueChanged<WorldCity> onSelectCity;
  final ValueChanged<String> onTogglePinCity;

  const WorldClockTab({
    super.key,
    required this.palette,
    required this.ephem,
    required this.selectedCity,
    required this.pinnedCityIds,
    this.customCities = const [],
    required this.nowNotifier,
    required this.use24HourFormat,
    required this.onSelectCity,
    required this.onTogglePinCity,
  });

  @override
  State<WorldClockTab> createState() => _WorldClockTabState();
}

class _WorldClockTabState extends State<WorldClockTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchFocused = false;
  int _solarMinutesOffset = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final ephem = widget.ephem;
    final selectedCity = widget.selectedCity;
    final pinnedCityIds = widget.pinnedCityIds;

    final List<WorldCity> allAvailable = [
      ...kWorldCities,
      ...widget.customCities,
    ];
    final List<WorldCity> filtered = _searchQuery.trim().isEmpty
        ? allAvailable
        : allAvailable.where((c) {
            final String q = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.country.toLowerCase().contains(q) ||
                c.stdTzCode.toLowerCase().contains(q) ||
                c.dstTzCode.toLowerCase().contains(q) ||
                c.gmtOffset.toLowerCase().contains(q);
          }).toList();

    return GestureDetector(
      key: const ValueKey('screen-world'),
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_isSearchFocused) {
          _searchFocusNode.unfocus();
          setState(() => _isSearchFocused = false);
        }
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            Center(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: widget.nowNotifier,
                builder: (context, now, _) {
                  final DateTime utc = now.toUtc();
                  final int cityOffset = selectedCity.effectiveOffsetMinutes(
                    utc,
                  );
                  final DateTime cityNow = utc.add(
                    Duration(minutes: cityOffset),
                  );
                  final int liveBaseMins = cityNow.hour * 60 + cityNow.minute;

                  return ArmillaryGlobeWidget(
                    selectedCity: selectedCity,
                    isCompact: _isSearchFocused,
                    solarMinutesOffset: _solarMinutesOffset,
                    baseCityMinutes: liveBaseMins,
                    isDark: palette.isDark,
                    onChangeSolarOffset: (nextOffset) {
                      setState(() => _solarMinutesOffset = nextOffset);
                    },
                    onSelectCity: (city) {
                      _searchFocusNode.unfocus();
                      setState(() {
                        _solarMinutesOffset = 0;
                        _isSearchFocused = false;
                      });
                      widget.onSelectCity(city);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar
            Container(
              width: double.infinity,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: palette.strokeSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: palette.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: 'Search city, country, or timezone code',
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onTap: () => setState(() => _isSearchFocused = true),
                        onChanged: (v) {
                          setState(() {
                            _searchQuery = v;
                            _isSearchFocused = true;
                          });
                        },
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search city or timezone...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: palette.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _isSearchFocused)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                        setState(() {
                          _searchQuery = '';
                          _isSearchFocused = false;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  GlassButton.iconOnly(
                    tooltip: 'Search any world city online (Open-Meteo)',
                    semanticLabel: 'Search any world city online (Open-Meteo)',
                    icon: Icons.travel_explore,
                    iconSize: 20,
                    iconColor: palette.accentPrimary,
                    width: 36,
                    height: 36,
                    isCircle: true,
                    onPressed: () {
                      CitySearchSheet.show(
                        context,
                        palette: palette,
                        nowNotifier: widget.nowNotifier,
                        use24HourFormat: widget.use24HourFormat,
                        pinnedCityIds: widget.pinnedCityIds,
                        onCitySelected: widget.onSelectCity,
                        onTogglePinCity: widget.onTogglePinCity,
                      );
                    },
                  ),
                ],
              ),
            ),

            if (_isSearchFocused)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 190),
                decoration: BoxDecoration(
                  color: palette.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.strokeSubtle),
                ),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No local city found for "$_searchQuery".',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final q = _searchQuery;
                                _searchFocusNode.unfocus();
                                setState(() => _isSearchFocused = false);
                                CitySearchSheet.show(
                                  context,
                                  palette: palette,
                                  nowNotifier: widget.nowNotifier,
                                  use24HourFormat: widget.use24HourFormat,
                                  pinnedCityIds: widget.pinnedCityIds,
                                  onCitySelected: widget.onSelectCity,
                                  onTogglePinCity: widget.onTogglePinCity,
                                );
                                context.read<CitySearchCubit>().search(q);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.accentPrimary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: palette.accentPrimary.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.travel_explore,
                                      size: 14,
                                      color: palette.accentPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Search "$_searchQuery" online via Open-Meteo',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.accentPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: palette.strokeSubtle),
                        itemBuilder: (ctx, idx) {
                          final WorldCity city = filtered[idx];
                          final DateTime utc = widget.nowNotifier.value.toUtc();
                          final int off = city.effectiveOffsetMinutes(utc);
                          final DateTime cNow = utc.add(Duration(minutes: off));
                          final String cTime =
                              CircadianEphemeris.formatMinutes12h(
                                cNow.hour * 60 + cNow.minute,
                                use24Hour: widget.use24HourFormat,
                              );
                          final bool isPinned = pinnedCityIds.contains(city.id);

                          return ListTile(
                            dense: true,
                            onTap: () {
                              HorologicalAudioEngine.instance
                                  .playEscapementClick(pitchHz: 1260);
                              _searchFocusNode.unfocus();
                              setState(() {
                                _solarMinutesOffset = 0;
                                _searchQuery = '';
                                _searchController.clear();
                                _isSearchFocused = false;
                              });
                              widget.onSelectCity(city);
                            },
                            title: Text(
                              '${city.name}, ${city.country}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${city.effectiveTzCode(utc)} | GMT ${city.effectiveGmtOffset(utc)}',
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: palette.accentPrimary,
                                    fontFeatures: const [
                                      ui.FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                GlassButton.iconOnly(
                                  tooltip: isPinned ? 'Unpin City' : 'Pin City',
                                  semanticLabel: isPinned
                                      ? 'Unpin City'
                                      : 'Pin City',
                                  icon: isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  iconSize: 19,
                                  iconColor: isPinned
                                      ? palette.accentPrimary
                                      : palette.textSecondary,
                                  width: 36,
                                  height: 36,
                                  isCircle: true,
                                  onPressed: () {
                                    widget.onTogglePinCity(city.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

            const SizedBox(height: 16),

            // Live Clock Readout
            ValueListenableBuilder<DateTime>(
              valueListenable: widget.nowNotifier,
              builder: (context, now, _) {
                final DateTime utc = now.toUtc();
                final int cityOff = selectedCity.effectiveOffsetMinutes(utc);
                final DateTime cityNow = utc.add(Duration(minutes: cityOff));
                final int baseMins = cityNow.hour * 60 + cityNow.minute;
                final int effectiveMins =
                    ((baseMins + _solarMinutesOffset) % 1440 + 1440) % 1440;
                final String formatted = CircadianEphemeris.formatMinutes12h(
                  effectiveMins,
                  use24Hour: widget.use24HourFormat,
                );
                final List<String> parts = formatted.split(' ');
                final String digits = parts.first;
                final String period = parts.length > 1 ? parts.last : '';

                final int localOff = now.timeZoneOffset.inMinutes;
                final int diffMins = cityOff - localOff;
                String relHome = 'Same as local time';
                if (diffMins != 0) {
                  final int absD = diffMins.abs();
                  final int dh = absD ~/ 60;
                  final int dm = absD % 60;
                  final String dir = diffMins > 0 ? 'ahead' : 'behind';
                  relHome =
                      '${dh > 0 ? '${dh}h ' : ''}${dm > 0 ? '${dm}m ' : ''}$dir'
                          .trim();
                }

                String solarStatus;
                if (ephem.polarState == PolarSolarState.polarDay) {
                  solarStatus = ' Polar Day | Continuous Midnight Sun';
                } else if (ephem.polarState == PolarSolarState.polarNight) {
                  solarStatus = ' Polar Night | Sun below horizon';
                } else if (effectiveMins >= ephem.sunriseLocalMinutes &&
                    effectiveMins < ephem.sunsetLocalMinutes) {
                  final int rem = ephem.sunsetLocalMinutes - effectiveMins;
                  solarStatus =
                      ' Daylight | Sunset in ${rem ~/ 60 > 0 ? '${rem ~/ 60}h ' : ''}${rem % 60}m';
                } else {
                  final int until = effectiveMins < ephem.sunriseLocalMinutes
                      ? ephem.sunriseLocalMinutes - effectiveMins
                      : 1440 - effectiveMins + ephem.sunriseLocalMinutes;
                  solarStatus =
                      ' Nightfall | Sunrise in ${until ~/ 60}h ${until % 60}m';
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label:
                          '${selectedCity.name} time $formatted, $relHome, ${solarStatus.trim()}',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            digits,
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              letterSpacing: -1.0,
                              color: palette.textPrimary,
                              fontFeatures: const [
                                ui.FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (period.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              period,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: palette.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${selectedCity.name}, ${selectedCity.country} | GMT ${selectedCity.effectiveGmtOffset(utc)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$relHome • ${solarStatus.trim()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: palette.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daylight Cycle #${ephem.currentGhatika}/60 (24m interval)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.strokeSubtle),
                          ),
                          child: Text(
                            solarStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                        if (_solarMinutesOffset != 0)
                          GlassButton.chip(
                            label: 'Reset Orbit',
                            isSelected: true,
                            height: 28,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            textStyle: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              HorologicalAudioEngine.instance
                                  .playEscapementClick(pitchHz: 1180);
                              setState(() => _solarMinutesOffset = 0);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Multi-City Pinned Comparison Strip
                    SizedBox(
                      height: 58,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pinnedCityIds.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final String pid = pinnedCityIds[idx];
                          final WorldCity pCity =
                              [
                                ...kWorldCities,
                                ...widget.customCities,
                              ].firstWhere(
                                (c) => c.id == pid,
                                orElse: () => kWorldCities[0],
                              );
                          final int pOff = pCity.effectiveOffsetMinutes(utc);
                          final DateTime pNow = utc.add(
                            Duration(minutes: pOff),
                          );
                          final String pTime =
                              CircadianEphemeris.formatMinutes12h(
                                pNow.hour * 60 + pNow.minute,
                                use24Hour: widget.use24HourFormat,
                              );
                          final bool isSelected = pCity.id == selectedCity.id;

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              HorologicalAudioEngine.instance
                                  .playEscapementClick(pitchHz: 1220);
                              setState(() {
                                _solarMinutesOffset = 0;
                              });
                              widget.onSelectCity(pCity);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.surfaceDark
                                    : palette.surfaceCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? palette.surfaceDark
                                      : palette.strokeSubtle,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${pCity.name} (${pCity.effectiveTzCode(utc)})',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? palette.bgBase
                                          : palette.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pTime,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? palette.accentSolar
                                          : palette.accentPrimary,
                                      fontFeatures: const [
                                        ui.FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
