import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/city_search_models.dart';

/// Base class for all network-related failures.
sealed class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => message;
}

class NoInternetException extends NetworkException {
  const NoInternetException([
    super.message = 'No active internet connection detected.',
  ]);
}

class NetworkTimeoutException extends NetworkException {
  const NetworkTimeoutException([
    super.message = 'Network request timed out. Please check your connection.',
  ]);
}

class ApiException extends NetworkException {
  final int statusCode;
  final String responseBody;

  const ApiException(this.statusCode, this.responseBody, [String? message])
    : super(message ?? 'Server responded with status HTTP $statusCode');
}

class MalformedResponseException extends NetworkException {
  const MalformedResponseException([
    super.message = 'Received malformed JSON from the API server.',
  ]);
}

/// Robust HTTP client for Open-Meteo Geocoding and Weather APIs.
/// Fully mockable via [http.Client] dependency injection.
/// Supports exponential backoff retry for transient network and 5xx errors.
class OpenMeteoApiClient {
  static const String _geocodingHost = 'geocoding-api.open-meteo.com';
  static const String _forecastHost = 'api.open-meteo.com';

  final http.Client _client;
  final bool _isClientInternal;
  final int maxRetries;
  final Duration retryDelay;

  OpenMeteoApiClient({
    http.Client? client,
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 250),
  }) : _client = client ?? http.Client(),
       _isClientInternal = client == null;

  /// Searches for global cities matching [query] using Open-Meteo Geocoding API.
  Future<List<GeocodingCityDto>> searchCities(
    String query, {
    int count = 10,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final String clean = query.trim();
    if (clean.isEmpty) return const [];

    final Uri uri = Uri.https(_geocodingHost, '/v1/search', <String, String>{
      'name': clean,
      'count': count.toString(),
      'language': 'en',
      'format': 'json',
    });

    return _executeWithRetry(() async {
      try {
        final response = await _client.get(uri).timeout(timeout);

        if (response.statusCode != 200) {
          throw ApiException(response.statusCode, response.body);
        }

        final dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (e) {
          throw MalformedResponseException(
            'Failed to decode JSON response: $e',
          );
        }

        if (decoded is! Map<String, dynamic>) {
          throw const MalformedResponseException(
            'Root response must be a JSON object',
          );
        }

        final List<dynamic>? results = decoded['results'] as List<dynamic>?;
        if (results == null || results.isEmpty) {
          return const [];
        }

        return results
            .whereType<Map<String, dynamic>>()
            .map(GeocodingCityDto.fromJson)
            .toList();
      } on TimeoutException {
        throw const NetworkTimeoutException();
      } on SocketException {
        throw const NoInternetException();
      } on http.ClientException {
        throw const NoInternetException();
      } on NetworkException {
        rethrow;
      } catch (e) {
        if (e is FormatException) {
          throw MalformedResponseException(
            'Format exception parsing response: $e',
          );
        }
        throw NoInternetException('Network request failed: $e');
      }
    });
  }

  /// Fetches current weather for coordinates using Open-Meteo Weather Forecast API.
  Future<CityWeatherDto?> getCurrentWeather(
    double latitude,
    double longitude, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final Uri uri = Uri.https(_forecastHost, '/v1/forecast', <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
    });

    return _executeWithRetry(() async {
      try {
        final response = await _client.get(uri).timeout(timeout);

        if (response.statusCode != 200) {
          throw ApiException(response.statusCode, response.body);
        }

        final dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (e) {
          throw MalformedResponseException('Failed to decode weather JSON: $e');
        }

        if (decoded is! Map<String, dynamic>) {
          throw const MalformedResponseException(
            'Weather root response must be a JSON object',
          );
        }

        return CityWeatherDto.fromJson(decoded);
      } on TimeoutException {
        throw const NetworkTimeoutException();
      } on SocketException {
        throw const NoInternetException();
      } on http.ClientException {
        throw const NoInternetException();
      } on NetworkException {
        rethrow;
      } catch (e) {
        if (e is FormatException) {
          throw MalformedResponseException(
            'Format exception parsing weather: $e',
          );
        }
        throw NoInternetException('Weather request failed: $e');
      }
    });
  }

  Future<T> _executeWithRetry<T>(Future<T> Function() action) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await action();
      } catch (e) {
        final bool isTransient = _isTransient(e);
        if (!isTransient || attempt > maxRetries) {
          rethrow;
        }
        if (retryDelay > Duration.zero) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }
  }

  bool _isTransient(dynamic e) {
    if (e is ApiException) {
      return e.statusCode >= 500 && e.statusCode < 600;
    }
    if (e is NetworkTimeoutException || e is TimeoutException) {
      return true;
    }
    if (e is SocketException ||
        e is http.ClientException ||
        e is NoInternetException) {
      return true;
    }
    return false;
  }

  void dispose() {
    if (_isClientInternal) {
      _client.close();
    }
  }
}
