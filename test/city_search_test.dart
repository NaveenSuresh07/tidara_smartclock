import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/data/datasources/open_meteo_api_client.dart';
import 'package:tidara_smartclock/data/repositories/city_search_repository.dart';
import 'package:tidara_smartclock/features/world_clock/cubit/city_search_cubit.dart';
import 'package:tidara_smartclock/features/world_clock/ui/city_search_sheet.dart';
import 'package:tidara_smartclock/models/horological_models.dart';

void main() {
  ensureTimeZonesInitialized();

  const sampleGeocodingJson = '''
{
  "results": [
    {
      "id": 2988507,
      "name": "Paris",
      "latitude": 48.85341,
      "longitude": 2.3488,
      "elevation": 42.0,
      "feature_code": "PPLC",
      "country_code": "FR",
      "admin1_id": 3012874,
      "timezone": "Europe/Paris",
      "population": 2138551,
      "country_id": 3017382,
      "country": "France",
      "admin1": "Île-de-France"
    },
    {
      "id": 4717560,
      "name": "Paris",
      "latitude": 33.66094,
      "longitude": -95.55551,
      "country_code": "US",
      "timezone": "America/Chicago",
      "country": "United States",
      "admin1": "Texas"
    }
  ],
  "generationtime_ms": 0.543
}
''';

  const sampleWeatherJson = '''
{
  "latitude": 48.85,
  "longitude": 2.35,
  "generationtime_ms": 0.048,
  "utc_offset_seconds": 0,
  "timezone": "GMT",
  "timezone_abbreviation": "GMT",
  "elevation": 42.0,
  "current": {
    "time": "2026-11-13T12:00",
    "interval": 900,
    "temperature_2m": 14.2,
    "relative_humidity_2m": 68,
    "weather_code": 1,
    "wind_speed_10m": 9.4
  }
}
''';

  group('OpenMeteoApiClient - Unit Tests', () {
    test(
      'searchCities - 200 OK returns parsed GeocodingCityDto list',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.host, 'geocoding-api.open-meteo.com');
          expect(request.url.path, '/v1/search');
          expect(request.url.queryParameters['name'], 'Paris');
          return http.Response(
            sampleGeocodingJson,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final apiClient = OpenMeteoApiClient(client: mockClient);
        final results = await apiClient.searchCities('Paris');

        expect(results.length, 2);
        expect(results[0].name, 'Paris');
        expect(results[0].country, 'France');
        expect(results[0].latitude, 48.85341);
        expect(results[0].longitude, 2.3488);
        expect(results[0].timezone, 'Europe/Paris');
        expect(results[0].admin1, 'Île-de-France');

        // Conversion to WorldCity
        final worldCity = results[0].toWorldCity();
        expect(worldCity.name, 'Paris (Île-de-France)');
        expect(worldCity.country, 'France');
        expect(worldCity.isCustom, isTrue);
        expect(worldCity.ianaTimeZone, 'Europe/Paris');
      },
    );

    test(
      'searchCities - 200 OK with empty results returns empty list',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"results":[]}', 200);
        });

        final apiClient = OpenMeteoApiClient(client: mockClient);
        final results = await apiClient.searchCities('NonExistentPlaceXYZ');
        expect(results, isEmpty);
      },
    );

    test(
      'searchCities - empty query returns empty list immediately without HTTP request',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          return http.Response('{}', 200);
        });

        final apiClient = OpenMeteoApiClient(client: mockClient);
        final results = await apiClient.searchCities('   ');
        expect(results, isEmpty);
        expect(requestCount, 0);
      },
    );

    test('searchCities - 404 server error throws ApiException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final apiClient = OpenMeteoApiClient(client: mockClient);
      expect(
        () => apiClient.searchCities('Paris'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test(
      'searchCities - 500 internal server error throws ApiException',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Error', 500);
        });

        final apiClient = OpenMeteoApiClient(client: mockClient);
        expect(
          () => apiClient.searchCities('Paris'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      },
    );

    test(
      'searchCities - malformed JSON response throws MalformedResponseException',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('{ invalid json string ...', 200);
        });

        final apiClient = OpenMeteoApiClient(client: mockClient);
        expect(
          () => apiClient.searchCities('Paris'),
          throwsA(isA<MalformedResponseException>()),
        );
      },
    );

    test('searchCities - timeout throws NetworkTimeoutException', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(sampleGeocodingJson, 200);
      });

      final apiClient = OpenMeteoApiClient(client: mockClient);
      expect(
        () => apiClient.searchCities(
          'Paris',
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<NetworkTimeoutException>()),
      );
    });

    test(
      'getCurrentWeather - 200 OK parses weather attributes correctly',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.host, 'api.open-meteo.com');
          expect(request.url.path, '/v1/forecast');
          return http.Response(sampleWeatherJson, 200);
        });

        final apiClient = OpenMeteoApiClient(client: mockClient);
        final weather = await apiClient.getCurrentWeather(48.85, 2.35);

        expect(weather, isNotNull);
        expect(weather!.temperatureC, 14.2);
        expect(weather.relativeHumidity, 68);
        expect(weather.weatherCode, 1);
        expect(weather.windSpeedKmh, 9.4);
        expect(weather.description, 'Mainly clear');
        expect(weather.weatherEmoji, '🌤️');
        expect(weather.summary, contains('14.2°C'));
      },
    );

    test('getCurrentWeather - 500 error throws ApiException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final apiClient = OpenMeteoApiClient(
        client: mockClient,
        retryDelay: Duration.zero,
      );
      expect(
        () => apiClient.getCurrentWeather(10.0, 20.0),
        throwsA(isA<ApiException>()),
      );
    });

    test(
      'searchCities - retries on 503 transient error and succeeds on attempt 2',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            return http.Response('Service Temporarily Unavailable', 503);
          }
          return http.Response(sampleGeocodingJson, 200);
        });

        final apiClient = OpenMeteoApiClient(
          client: mockClient,
          retryDelay: Duration.zero,
        );
        final results = await apiClient.searchCities('Paris');

        expect(requestCount, 2);
        expect(results.length, 2);
        expect(results[0].name, 'Paris');
      },
    );

    test(
      'searchCities - retries up to maxRetries on 500 error and throws ApiException',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          return http.Response('Internal Server Error', 500);
        });

        final apiClient = OpenMeteoApiClient(
          client: mockClient,
          maxRetries: 2,
          retryDelay: Duration.zero,
        );

        await expectLater(
          () => apiClient.searchCities('Paris'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
        expect(requestCount, 3); // 1 initial + 2 retries = 3 attempts
      },
    );

    test('searchCities - does not retry on 404 client error', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('Not Found', 404);
      });

      final apiClient = OpenMeteoApiClient(
        client: mockClient,
        maxRetries: 2,
        retryDelay: Duration.zero,
      );

      await expectLater(
        () => apiClient.searchCities('UnknownCity'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
      expect(requestCount, 1); // Client error should not retry
    });

    test(
      'searchCities - retries on transient ClientException and succeeds',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            throw http.ClientException('Connection reset by peer');
          }
          return http.Response(sampleGeocodingJson, 200);
        });

        final apiClient = OpenMeteoApiClient(
          client: mockClient,
          retryDelay: Duration.zero,
        );
        final results = await apiClient.searchCities('Paris');

        expect(requestCount, 2);
        expect(results.length, 2);
      },
    );
  });

  group('CitySearchRepository - Unit Tests & Offline Fallback', () {
    test(
      'searchCities - successful search caches results and returns CitySearchResult',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.host.contains('geocoding')) {
            return http.Response(sampleGeocodingJson, 200);
          }
          return http.Response(sampleWeatherJson, 200);
        });

        final repo = CitySearchRepository(
          apiClient: OpenMeteoApiClient(
            client: mockClient,
            retryDelay: Duration.zero,
          ),
          defaultTtl: Duration.zero,
        );

        final result = await repo.searchCities('Paris');

        expect(result.isEmpty, isFalse);
        expect(result.isOfflineFallback, isFalse);
        expect(result.cities.length, 2);
        expect(result.cities[0].name, contains('Paris'));
        expect(result.cities[0].temperatureC, 14.2);
      },
    );

    test(
      'searchCities - offline fallback uses in-memory cache when network fails',
      () async {
        bool isOnline = true;
        final mockClient = MockClient((request) async {
          if (!isOnline) {
            throw http.ClientException('Connection refused');
          }
          if (request.url.host.contains('geocoding')) {
            return http.Response(sampleGeocodingJson, 200);
          }
          return http.Response(sampleWeatherJson, 200);
        });

        final repo = CitySearchRepository(
          apiClient: OpenMeteoApiClient(
            client: mockClient,
            retryDelay: Duration.zero,
          ),
          defaultTtl: Duration.zero,
        );

        // 1. Initial online search populates cache
        final onlineResult = await repo.searchCities('Paris');
        expect(onlineResult.isOfflineFallback, isFalse);
        expect(onlineResult.isCacheHit, isFalse);

        // 2. Go offline
        isOnline = false;

        // 3. Repeating search returns cached results with isOfflineFallback=true and isCacheHit=true
        final offlineResult = await repo.searchCities('Paris');
        expect(offlineResult.isOfflineFallback, isTrue);
        expect(offlineResult.isCacheHit, isTrue);
        expect(offlineResult.cities.length, 2);
        expect(offlineResult.errorMessage, contains('Offline mode'));
      },
    );

    test(
      'searchCities - offline fallback matches local bundled cities when cache is empty',
      () async {
        final mockClient = MockClient((request) async {
          throw http.ClientException('No network connection');
        });

        final repo = CitySearchRepository(
          apiClient: OpenMeteoApiClient(
            client: mockClient,
            retryDelay: Duration.zero,
          ),
          defaultTtl: Duration.zero,
        );

        // Search for Tokyo offline with empty cache
        final result = await repo.searchCities('Tokyo');
        expect(result.isOfflineFallback, isTrue);
        expect(result.isCacheHit, isFalse);
        expect(result.cities.any((c) => c.id == 'tokyo'), isTrue);
        expect(result.errorMessage, contains('Offline mode'));
      },
    );

    test(
      'customCities - adding custom city makes it queryable locally',
      () async {
        final repo = CitySearchRepository();
        const customCity = WorldCity(
          id: 'custom_helsinki',
          name: 'Helsinki',
          country: 'Finland',
          stdTzCode: 'EET',
          dstTzCode: 'EEST',
          stdOffsetMinutes: 120,
          dstOffsetMinutes: 180,
          dstRegion: 'EU',
          lat: 60.1699,
          lon: 24.9384,
          isCustom: true,
        );

        repo.addCustomCity(customCity);
        expect(repo.customCities.contains(customCity), isTrue);

        final emptySearch = await repo.searchCities('');
        expect(emptySearch.cities.contains(customCity), isTrue);
      },
    );

    test(
      'searchCities - cache hit within TTL returns cached result without making network call',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          if (request.url.host.contains('geocoding')) {
            return http.Response(sampleGeocodingJson, 200);
          }
          return http.Response(sampleWeatherJson, 200);
        });

        final cacheStore = InMemoryCitySearchCacheStore();
        final repo = CitySearchRepository(
          apiClient: OpenMeteoApiClient(
            client: mockClient,
            retryDelay: Duration.zero,
          ),
          cacheStore: cacheStore,
          defaultTtl: const Duration(hours: 1),
        );

        // First call fetches from network
        final result1 = await repo.searchCities('Paris');
        expect(result1.isCacheHit, isFalse);
        expect(requestCount, greaterThan(0));
        final initialRequests = requestCount;

        // Second call should be a cache hit within TTL
        final result2 = await repo.searchCities('Paris');
        expect(result2.isCacheHit, isTrue);
        expect(result2.cities.length, 2);
        expect(requestCount, initialRequests); // No additional network requests
      },
    );

    test(
      'searchCities - cache expiry triggers fresh network request after TTL',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          if (request.url.host.contains('geocoding')) {
            return http.Response(sampleGeocodingJson, 200);
          }
          return http.Response(sampleWeatherJson, 200);
        });

        final repo = CitySearchRepository(
          apiClient: OpenMeteoApiClient(
            client: mockClient,
            retryDelay: Duration.zero,
          ),
          cacheStore: InMemoryCitySearchCacheStore(),
          defaultTtl: const Duration(milliseconds: 30),
        );

        // 1. Initial search
        await repo.searchCities('Paris');
        final firstCount = requestCount;

        // 2. Wait for TTL to expire
        await Future.delayed(const Duration(milliseconds: 40));

        // 3. Second search should refresh from network
        final result2 = await repo.searchCities('Paris');
        expect(result2.isCacheHit, isFalse);
        expect(requestCount, greaterThan(firstCount));
      },
    );

    test(
      'searchCities - file cache persistence writes to File and loads across repo instances',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'tidara_cache_test_',
        );
        final cacheFile = File('${tempDir.path}/city_cache.json');

        try {
          int requestCount = 0;
          final mockClient = MockClient((request) async {
            requestCount++;
            if (request.url.host.contains('geocoding')) {
              return http.Response(sampleGeocodingJson, 200);
            }
            return http.Response(sampleWeatherJson, 200);
          });

          // Repo 1: searches and persists to cache file
          final repo1 = CitySearchRepository(
            apiClient: OpenMeteoApiClient(
              client: mockClient,
              retryDelay: Duration.zero,
            ),
            cacheStore: FileCitySearchCacheStore(cacheFile),
          );

          await repo1.searchCities('Paris');
          expect(requestCount, greaterThan(0));
          expect(await cacheFile.exists(), isTrue);

          // Repo 2: separate instance using the same cache file, offline
          final offlineClient = MockClient((request) async {
            throw http.ClientException('Offline');
          });

          final repo2 = CitySearchRepository(
            apiClient: OpenMeteoApiClient(
              client: offlineClient,
              retryDelay: Duration.zero,
            ),
            cacheStore: FileCitySearchCacheStore(cacheFile),
          );

          // Searching Paris on repo2 reads from the persisted file cache
          final cachedResult = await repo2.searchCities('Paris');
          expect(cachedResult.cities.length, 2);
          expect(cachedResult.isCacheHit, isTrue);
          expect(cachedResult.cities[0].name, contains('Paris'));
        } finally {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      },
    );

    test(
      'searchCities - expired cache is returned as offline fallback when network is unavailable',
      () async {
        bool isOnline = true;
        final mockClient = MockClient((request) async {
          if (!isOnline) {
            throw http.ClientException('Network down');
          }
          if (request.url.host.contains('geocoding')) {
            return http.Response(sampleGeocodingJson, 200);
          }
          return http.Response(sampleWeatherJson, 200);
        });

        final repo = CitySearchRepository(
          apiClient: OpenMeteoApiClient(
            client: mockClient,
            retryDelay: Duration.zero,
          ),
          cacheStore: InMemoryCitySearchCacheStore(),
          defaultTtl: const Duration(milliseconds: 25),
        );

        // Fetch while online
        await repo.searchCities('Paris');

        // Wait for TTL expiration and simulate offline
        await Future.delayed(const Duration(milliseconds: 35));
        isOnline = false;

        // Search offline: expired cache should still be returned as fallback
        final fallbackResult = await repo.searchCities('Paris');
        expect(fallbackResult.isOfflineFallback, isTrue);
        expect(fallbackResult.isCacheHit, isTrue);
        expect(fallbackResult.cities.length, 2);
        expect(fallbackResult.errorMessage, contains('Offline mode'));
      },
    );
  });

  group('CitySearchCubit - State Management Unit Tests', () {
    test('initial state is CitySearchInitial with default cities', () {
      final cubit = CitySearchCubit();
      expect(cubit.state, isA<CitySearchInitial>());
      final initial = cubit.state as CitySearchInitial;
      expect(initial.defaultCities, isNotEmpty);
      expect(initial.defaultCities.length, kWorldCities.length);
      cubit.close();
    });

    test('search emits Loading then Loaded on success', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('geocoding')) {
          return http.Response(sampleGeocodingJson, 200);
        }
        return http.Response(sampleWeatherJson, 200);
      });

      final repo = CitySearchRepository(
        apiClient: OpenMeteoApiClient(client: mockClient),
      );
      final cubit = CitySearchCubit(repository: repo);

      final states = <CitySearchState>[];
      final sub = cubit.stream.listen(states.add);

      cubit.search('Paris', debounce: false);
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<CitySearchLoading>());
      expect(states[1], isA<CitySearchLoaded>());

      final loaded = states[1] as CitySearchLoaded;
      expect(loaded.cities.length, 2);
      expect(loaded.isOffline, isFalse);

      await sub.cancel();
      await cubit.close();
    });

    test('search emits Empty state when no matches found', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"results":[]}', 200);
      });

      final repo = CitySearchRepository(
        apiClient: OpenMeteoApiClient(client: mockClient),
      );
      final cubit = CitySearchCubit(repository: repo);

      final states = <CitySearchState>[];
      final sub = cubit.stream.listen(states.add);

      cubit.search('NoSuchCityAnywhere123', debounce: false);
      await pumpEventQueue();

      expect(states.length, 2);
      expect(states[0], isA<CitySearchLoading>());
      expect(states[1], isA<CitySearchEmpty>());

      await sub.cancel();
      await cubit.close();
    });

    test('clearSearch resets state to CitySearchInitial', () async {
      final cubit = CitySearchCubit();
      cubit.clearSearch();
      expect(cubit.state, isA<CitySearchInitial>());
      await cubit.close();
    });
  });

  group('CitySearchSheet - Widget Tests', () {
    testWidgets('renders search sheet with input field and initial list', (
      tester,
    ) async {
      final palette = TidaraPalette(isDark: true, highContrast: false);
      final nowNotifier = ValueNotifier<DateTime>(
        DateTime(2026, 11, 13, 12, 0),
      );
      final cubit = CitySearchCubit();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitySearchSheet(
              palette: palette,
              nowNotifier: nowNotifier,
              use24HourFormat: true,
              pinnedCityIds: const ['bengaluru'],
              onCitySelected: (_) {},
              onTogglePinCity: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Global City Search'), findsOneWidget);
      expect(find.byKey(const ValueKey('city_search_input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('city_search_results_list')),
        findsOneWidget,
      );

      await cubit.close();
    });

    testWidgets('selecting a city triggers onCitySelected callback', (
      tester,
    ) async {
      final palette = TidaraPalette(isDark: false, highContrast: false);
      final nowNotifier = ValueNotifier<DateTime>(
        DateTime(2026, 11, 13, 12, 0),
      );
      WorldCity? selectedCity;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitySearchSheet(
              palette: palette,
              nowNotifier: nowNotifier,
              use24HourFormat: false,
              pinnedCityIds: const ['tokyo'],
              onCitySelected: (c) => selectedCity = c,
              onTogglePinCity: (_) {},
            ),
          ),
        ),
      );

      // Find first city (Bengaluru) and tap it
      final firstCityTile = find.text('Bengaluru, India');
      expect(firstCityTile, findsOneWidget);

      await tester.tap(firstCityTile);
      await tester.pumpAndSettle();

      expect(selectedCity, isNotNull);
      expect(selectedCity!.id, 'bengaluru');
    });

    testWidgets('pin button toggles pin for city', (tester) async {
      final palette = TidaraPalette(isDark: false, highContrast: false);
      final nowNotifier = ValueNotifier<DateTime>(
        DateTime(2026, 11, 13, 12, 0),
      );
      String? toggledPinId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitySearchSheet(
              palette: palette,
              nowNotifier: nowNotifier,
              use24HourFormat: false,
              pinnedCityIds: const ['stockholm'],
              onCitySelected: (_) {},
              onTogglePinCity: (id) => toggledPinId = id,
            ),
          ),
        ),
      );

      final pinButton = find.byIcon(Icons.push_pin_outlined).first;
      expect(pinButton, findsOneWidget);

      // Tap on the pin icon
      await tester.tap(pinButton);
      await tester.pump();

      expect(toggledPinId, isNotNull);
    });

    testWidgets(
      'renders offline cached data indicator banner when state is offline cache hit',
      (tester) async {
        final palette = TidaraPalette(isDark: true, highContrast: false);
        final nowNotifier = ValueNotifier<DateTime>(
          DateTime(2026, 11, 13, 12, 0),
        );

        final mockRepo = CitySearchRepository(
          apiClient: OpenMeteoApiClient(
            client: MockClient(
              (_) async => throw http.ClientException('offline'),
            ),
            retryDelay: Duration.zero,
          ),
          cacheStore: InMemoryCitySearchCacheStore({
            'paris': CachedSearchEntry(
              cities: [
                const WorldCity(
                  id: 'paris_test',
                  name: 'Paris',
                  country: 'France',
                  stdTzCode: 'CET',
                  dstTzCode: 'CEST',
                  stdOffsetMinutes: 60,
                  dstOffsetMinutes: 120,
                  dstRegion: 'EU',
                  lat: 48.8566,
                  lon: 2.3522,
                ),
              ],
              cachedAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ).toJson(),
          }),
        );

        final cubit = CitySearchCubit(repository: mockRepo);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CitySearchSheet(
                palette: palette,
                nowNotifier: nowNotifier,
                use24HourFormat: false,
                pinnedCityIds: const [],
                onCitySelected: (_) {},
                onTogglePinCity: (_) {},
                searchCubit: cubit,
              ),
            ),
          ),
        );

        // Perform search for 'paris' which will trigger offline fallback with cache hit
        cubit.search('paris', debounce: false);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('offline_cached_data_indicator')),
          findsOneWidget,
        );
        expect(
          find.text('Offline Mode: Displaying cached search results'),
          findsOneWidget,
        );

        await cubit.close();
      },
    );
  });
}
