import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../models/horological_models.dart';
import '../datasources/open_meteo_api_client.dart';
import '../models/city_search_models.dart';

/// Storage abstraction for persisting cached city searches to disk or memory.
abstract class CitySearchCacheStore {
  Future<Map<String, dynamic>?> readCache();
  Future<void> writeCache(Map<String, dynamic> data);
  Future<void> clear();
}

/// In-memory cache store useful for testing or fast ephemeral sessions.
class InMemoryCitySearchCacheStore implements CitySearchCacheStore {
  Map<String, dynamic>? _storage;

  InMemoryCitySearchCacheStore([Map<String, dynamic>? initial])
    : _storage = initial != null ? Map<String, dynamic>.from(initial) : null;

  @override
  Future<Map<String, dynamic>?> readCache() async => _storage;

  @override
  Future<void> writeCache(Map<String, dynamic> data) async {
    _storage = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> clear() async {
    _storage = null;
  }
}

/// Local file-backed cache store for persisting city searches across app restarts.
class FileCitySearchCacheStore implements CitySearchCacheStore {
  final File file;

  FileCitySearchCacheStore(this.file);

  @override
  Future<Map<String, dynamic>?> readCache() async {
    try {
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCache(Map<String, dynamic> data) async {
    try {
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Best-effort write
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

/// Cache entry representing cached city search results with timestamp and TTL.
class CachedSearchEntry {
  final List<WorldCity> cities;
  final DateTime cachedAt;
  final Duration ttl;

  const CachedSearchEntry({
    required this.cities,
    required this.cachedAt,
    this.ttl = const Duration(hours: 24),
  });

  bool isExpired([DateTime? now]) {
    if (ttl <= Duration.zero) return true;
    final current = now ?? DateTime.now();
    return current.difference(cachedAt) >= ttl;
  }

  Map<String, dynamic> toJson() => {
    'cities': cities.map((c) => c.toJson()).toList(),
    'cachedAt': cachedAt.toIso8601String(),
    'ttlMs': ttl.inMilliseconds,
  };

  factory CachedSearchEntry.fromJson(Map<String, dynamic> json) {
    return CachedSearchEntry(
      cities:
          (json['cities'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(WorldCity.fromJson)
              .toList() ??
          [],
      cachedAt:
          DateTime.tryParse(json['cachedAt'] as String? ?? '') ??
          DateTime.now(),
      ttl: Duration(
        milliseconds:
            json['ttlMs'] as int? ?? const Duration(hours: 24).inMilliseconds,
      ),
    );
  }
}

/// Result wrapper returned by [CitySearchRepository].
class CitySearchResult {
  final List<WorldCity> cities;
  final bool isOfflineFallback;
  final String? errorMessage;
  final bool isCacheHit;

  const CitySearchResult({
    required this.cities,
    this.isOfflineFallback = false,
    this.errorMessage,
    this.isCacheHit = false,
  });

  bool get isEmpty => cities.isEmpty;
  bool get hasError => errorMessage != null;
}

/// Repository coordinating remote Open-Meteo geocoding & weather API queries
/// with TTL-based local caching and graceful local fallbacks.
class CitySearchRepository {
  final OpenMeteoApiClient _apiClient;
  final CitySearchCacheStore? _cacheStore;
  final Duration defaultTtl;

  final Map<String, CachedSearchEntry> _searchCache = {};
  final Map<String, ({CityWeatherDto weather, DateTime fetchedAt})>
  _weatherCache = {};
  final List<WorldCity> _customCities = [];
  bool _cacheLoaded = false;

  CitySearchRepository({
    OpenMeteoApiClient? apiClient,
    CitySearchCacheStore? cacheStore,
    this.defaultTtl = const Duration(hours: 24),
  }) : _apiClient = apiClient ?? OpenMeteoApiClient(),
       _cacheStore = cacheStore;

  List<WorldCity> get customCities => List.unmodifiable(_customCities);

  void addCustomCity(WorldCity city) {
    if (!_customCities.any((c) => c.id == city.id)) {
      _customCities.add(city);
    }
  }

  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded || _cacheStore == null) {
      _cacheLoaded = true;
      return;
    }
    final raw = await _cacheStore.readCache();
    if (raw != null) {
      for (final entry in raw.entries) {
        if (entry.value is Map<String, dynamic>) {
          _searchCache[entry.key] = CachedSearchEntry.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }
    _cacheLoaded = true;
  }

  Future<void> _persistCache() async {
    if (_cacheStore == null) return;
    final map = <String, dynamic>{};
    for (final entry in _searchCache.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await _cacheStore.writeCache(map);
  }

  /// Searches for cities matching [query].
  /// When online: queries Open-Meteo Geocoding API and caches results with TTL.
  /// When cached and valid (within TTL): returns cached results immediately.
  /// When expired or offline: attempts network, gracefully falling back to expired
  /// cached data or bundled local cities.
  Future<CitySearchResult> searchCities(
    String query, {
    bool includeWeather = true,
  }) async {
    final String clean = query.trim().toLowerCase();

    // Empty query returns default bundled cities + any custom added cities
    if (clean.isEmpty) {
      final defaultList = [...kWorldCities, ..._customCities];
      return CitySearchResult(cities: defaultList, isOfflineFallback: false);
    }

    await _ensureCacheLoaded();

    final cached = _searchCache[clean];
    if (cached != null && !cached.isExpired()) {
      return CitySearchResult(
        cities: cached.cities,
        isOfflineFallback: false,
        isCacheHit: true,
      );
    }

    try {
      final List<GeocodingCityDto> dtos = await _apiClient.searchCities(clean);

      if (dtos.isEmpty) {
        // Also check if any local city matches before declaring empty
        final localMatches = _findLocalMatches(clean);
        return CitySearchResult(cities: localMatches, isOfflineFallback: false);
      }

      final List<WorldCity> resolvedCities = [];
      for (final dto in dtos) {
        CityWeatherDto? weather;
        if (includeWeather && resolvedCities.isEmpty) {
          // Fetch live weather for the top match
          try {
            weather = await _apiClient.getCurrentWeather(
              dto.latitude,
              dto.longitude,
            );
          } catch (_) {
            // Weather fetch is best-effort; failure should not break geocoding
          }
        }
        resolvedCities.add(dto.toWorldCity(weather: weather));
      }

      // Update in-memory cache and persist to storage
      _searchCache[clean] = CachedSearchEntry(
        cities: resolvedCities,
        cachedAt: DateTime.now(),
        ttl: defaultTtl,
      );
      await _persistCache();

      return CitySearchResult(cities: resolvedCities, isOfflineFallback: false);
    } on NetworkException catch (e) {
      return _buildOfflineFallback(clean, e.message);
    } catch (e) {
      return _buildOfflineFallback(clean, 'Unexpected search error: $e');
    }
  }

  /// Retrieves weather for a specific [city], checking cache first.
  Future<CityWeatherDto?> getWeatherForCity(
    WorldCity city, {
    Duration cacheDuration = const Duration(minutes: 15),
  }) async {
    final String cacheKey =
        '${city.lat.toStringAsFixed(2)}_${city.lon.toStringAsFixed(2)}';
    final cached = _weatherCache[cacheKey];

    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < cacheDuration) {
      return cached.weather;
    }

    try {
      final weather = await _apiClient.getCurrentWeather(city.lat, city.lon);
      if (weather != null) {
        _weatherCache[cacheKey] = (weather: weather, fetchedAt: DateTime.now());
      }
      return weather;
    } catch (_) {
      // Return stale cache if available when offline
      return cached?.weather;
    }
  }

  CitySearchResult _buildOfflineFallback(String query, String errorDetail) {
    // 1. Check if we have cached results for this query (even if expired)
    if (_searchCache.containsKey(query)) {
      return CitySearchResult(
        cities: _searchCache[query]!.cities,
        isOfflineFallback: true,
        isCacheHit: true,
        errorMessage: 'Offline mode: Showing cached results ($errorDetail)',
      );
    }

    // 2. Fall back to local bundled cities
    final localMatches = _findLocalMatches(query);
    return CitySearchResult(
      cities: localMatches,
      isOfflineFallback: true,
      errorMessage: 'Offline mode: Showing offline cities ($errorDetail)',
    );
  }

  List<WorldCity> _findLocalMatches(String query) {
    final all = [...kWorldCities, ..._customCities];
    return all.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.country.toLowerCase().contains(query) ||
          c.stdTzCode.toLowerCase().contains(query) ||
          c.gmtOffset.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> clearCache() async {
    _searchCache.clear();
    _weatherCache.clear();
    await _cacheStore?.clear();
  }
}
