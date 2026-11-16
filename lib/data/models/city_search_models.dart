import '../../models/horological_models.dart';

/// Data transfer object for Open-Meteo Geocoding API responses.
/// API: https://geocoding-api.open-meteo.com/v1/search?name={query}&count=10&language=en&format=json
class GeocodingCityDto {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String country;
  final String? countryCode;
  final String? admin1;
  final String? timezone;

  const GeocodingCityDto({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.country,
    this.countryCode,
    this.admin1,
    this.timezone,
  });

  factory GeocodingCityDto.fromJson(Map<String, dynamic> json) {
    return GeocodingCityDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      country:
          json['country'] as String? ?? json['country_code'] as String? ?? '',
      countryCode: json['country_code'] as String?,
      admin1: json['admin1'] as String?,
      timezone: json['timezone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'country': country,
    if (countryCode != null) 'country_code': countryCode,
    if (admin1 != null) 'admin1': admin1,
    if (timezone != null) 'timezone': timezone,
  };

  /// Converts this DTO into Tidara's internal [WorldCity] model.
  WorldCity toWorldCity({CityWeatherDto? weather}) {
    final String cleanId =
        'geo_${id}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    // Derive approximate standard offset in minutes from longitude as a baseline
    final int approxOffset = ((longitude / 15.0).round() * 60).clamp(-720, 840);
    final String sign = approxOffset >= 0 ? '+' : '-';
    final int absH = approxOffset.abs() ~/ 60;
    final String approxTz = 'GMT$sign$absH';

    return WorldCity(
      id: cleanId,
      name: admin1 != null && admin1!.isNotEmpty ? '$name ($admin1)' : name,
      country: country,
      stdTzCode: timezone?.split('/').last.replaceAll('_', ' ') ?? approxTz,
      dstTzCode: timezone?.split('/').last.replaceAll('_', ' ') ?? approxTz,
      stdOffsetMinutes: approxOffset,
      dstOffsetMinutes: approxOffset,
      dstRegion: 'NONE',
      lat: latitude,
      lon: longitude,
      ianaTimeZone: timezone,
      temperatureC: weather?.temperatureC,
      weatherCode: weather?.weatherCode,
      currentWeatherSummary: weather?.summary,
      isCustom: true,
    );
  }
}

/// Data transfer object for Open-Meteo Current Weather forecast responses.
/// API: https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m
class CityWeatherDto {
  final double temperatureC;
  final int relativeHumidity;
  final int weatherCode;
  final double windSpeedKmh;
  final DateTime timestamp;

  const CityWeatherDto({
    required this.temperatureC,
    required this.relativeHumidity,
    required this.weatherCode,
    required this.windSpeedKmh,
    required this.timestamp,
  });

  factory CityWeatherDto.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? json;
    return CityWeatherDto(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      relativeHumidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      timestamp: current['time'] != null
          ? DateTime.tryParse(current['time'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature_2m': temperatureC,
    'relative_humidity_2m': relativeHumidity,
    'weather_code': weatherCode,
    'wind_speed_10m': windSpeedKmh,
    'time': timestamp.toIso8601String(),
  };

  /// WMO Weather interpretation code description.
  String get description {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snowfall';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Partly cloudy';
    }
  }

  /// Weather emoji representation.
  String get weatherEmoji {
    switch (weatherCode) {
      case 0:
        return '☀️';
      case 1:
      case 2:
        return '🌤️';
      case 3:
        return '☁️';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return '🌧️';
      case 71:
      case 73:
      case 75:
        return '❄️';
      case 95:
      case 96:
      case 99:
        return '⛈️';
      default:
        return '🌤️';
    }
  }

  /// Short summary e.g. "24.5°C 🌤️ Partly cloudy"
  String get summary =>
      '${temperatureC.toStringAsFixed(1)}°C $weatherEmoji $description';
}
