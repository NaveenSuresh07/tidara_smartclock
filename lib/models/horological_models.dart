import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// WorldCity, AlarmRhythm, ChronoLap, FocusPreset & Continent Polygons

bool _tzInitialized = false;
void ensureTimeZonesInitialized() {
  if (!_tzInitialized) {
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }
}

int? resolveIanaOffsetMinutes(String cityId, DateTime utcInstant) {
  try {
    ensureTimeZonesInitialized();
    const Map<String, String> ianaById = <String, String>{
      'bengaluru': 'Asia/Kolkata',
      'mumbai': 'Asia/Kolkata',
      'stockholm': 'Europe/Stockholm',
      'london': 'Europe/London',
      'new_york': 'America/New_York',
      'newyork': 'America/New_York',
      'nyc': 'America/New_York',
      'tokyo': 'Asia/Tokyo',
      'sydney': 'Australia/Sydney',
      'zurich': 'Europe/Zurich',
      'reykjavik': 'Atlantic/Reykjavik',
      'san_francisco': 'America/Los_Angeles',
      'sanfrancisco': 'America/Los_Angeles',
      'singapore': 'Asia/Singapore',
      'dubai': 'Asia/Dubai',
      'cairo': 'Africa/Cairo',
    };
    final zoneName = ianaById[cityId.toLowerCase().trim()];
    if (zoneName != null) {
      final loc = tz.getLocation(zoneName);
      return tz.TZDateTime.from(
        utcInstant.toUtc(),
        loc,
      ).timeZoneOffset.inMinutes;
    }
  } catch (_) {}
  return null;
}

class WorldCity {
  final String id;
  final String name;
  final String country;
  final String stdTzCode;
  final String dstTzCode;
  final int stdOffsetMinutes;
  final int dstOffsetMinutes;
  final String dstRegion; // 'NONE', 'US', 'EU', 'AU'
  final double lat;
  final double lon;
  final String? ianaTimeZone;
  final String? currentWeatherSummary;
  final double? temperatureC;
  final int? weatherCode;
  final bool isCustom;

  const WorldCity({
    required this.id,
    required this.name,
    required this.country,
    required this.stdTzCode,
    required this.dstTzCode,
    required this.stdOffsetMinutes,
    required this.dstOffsetMinutes,
    required this.dstRegion,
    required this.lat,
    required this.lon,
    this.ianaTimeZone,
    this.currentWeatherSummary,
    this.temperatureC,
    this.weatherCode,
    this.isCustom = false,
  });

  bool isDstActive(DateTime utcNow) {
    if (dstRegion == 'NONE') return false;
    final int m = utcNow.month;
    if (dstRegion == 'US') {
      return m >= 4 && m <= 10;
    } else if (dstRegion == 'EU') {
      return m >= 4 && m <= 10;
    } else if (dstRegion == 'AU') {
      return m >= 10 || m <= 3;
    }
    return false;
  }

  int effectiveOffsetMinutes(DateTime utcNow) {
    if (ianaTimeZone != null && ianaTimeZone!.isNotEmpty) {
      try {
        ensureTimeZonesInitialized();
        final loc = tz.getLocation(ianaTimeZone!);
        return tz.TZDateTime.from(utcNow.toUtc(), loc).timeZoneOffset.inMinutes;
      } catch (_) {}
    }
    return isDstActive(utcNow) ? dstOffsetMinutes : stdOffsetMinutes;
  }

  String effectiveTzCode(DateTime utcNow) =>
      isDstActive(utcNow) ? dstTzCode : stdTzCode;

  String effectiveGmtOffset(DateTime utcNow) {
    final int off = effectiveOffsetMinutes(utcNow);
    final String sign = off >= 0 ? '+' : '-';
    final int absOff = off.abs();
    final int h = absOff ~/ 60;
    final int m = absOff % 60;
    return '$sign$h:${m.toString().padLeft(2, '0')}';
  }

  String get tzCode => stdTzCode;
  String get gmtOffset => effectiveGmtOffset(DateTime.now().toUtc());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'stdTzCode': stdTzCode,
    'dstTzCode': dstTzCode,
    'stdOffsetMinutes': stdOffsetMinutes,
    'dstOffsetMinutes': dstOffsetMinutes,
    'dstRegion': dstRegion,
    'lat': lat,
    'lon': lon,
    if (ianaTimeZone != null) 'ianaTimeZone': ianaTimeZone,
    if (currentWeatherSummary != null)
      'currentWeatherSummary': currentWeatherSummary,
    if (temperatureC != null) 'temperatureC': temperatureC,
    if (weatherCode != null) 'weatherCode': weatherCode,
    'isCustom': isCustom,
  };

  factory WorldCity.fromJson(Map<String, dynamic> json) => WorldCity(
    id: json['id'] as String? ?? 'unknown',
    name: json['name'] as String? ?? 'Unknown City',
    country: json['country'] as String? ?? '',
    stdTzCode: json['stdTzCode'] as String? ?? 'UTC',
    dstTzCode: json['dstTzCode'] as String? ?? 'UTC',
    stdOffsetMinutes: (json['stdOffsetMinutes'] as num?)?.toInt() ?? 0,
    dstOffsetMinutes: (json['dstOffsetMinutes'] as num?)?.toInt() ?? 0,
    dstRegion: json['dstRegion'] as String? ?? 'NONE',
    lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
    lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
    ianaTimeZone: json['ianaTimeZone'] as String?,
    currentWeatherSummary: json['currentWeatherSummary'] as String?,
    temperatureC: (json['temperatureC'] as num?)?.toDouble(),
    weatherCode: (json['weatherCode'] as num?)?.toInt(),
    isCustom: json['isCustom'] as bool? ?? false,
  );

  WorldCity copyWith({
    String? id,
    String? name,
    String? country,
    String? stdTzCode,
    String? dstTzCode,
    int? stdOffsetMinutes,
    int? dstOffsetMinutes,
    String? dstRegion,
    double? lat,
    double? lon,
    String? ianaTimeZone,
    String? currentWeatherSummary,
    double? temperatureC,
    int? weatherCode,
    bool? isCustom,
  }) => WorldCity(
    id: id ?? this.id,
    name: name ?? this.name,
    country: country ?? this.country,
    stdTzCode: stdTzCode ?? this.stdTzCode,
    dstTzCode: dstTzCode ?? this.dstTzCode,
    stdOffsetMinutes: stdOffsetMinutes ?? this.stdOffsetMinutes,
    dstOffsetMinutes: dstOffsetMinutes ?? this.dstOffsetMinutes,
    dstRegion: dstRegion ?? this.dstRegion,
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    ianaTimeZone: ianaTimeZone ?? this.ianaTimeZone,
    currentWeatherSummary: currentWeatherSummary ?? this.currentWeatherSummary,
    temperatureC: temperatureC ?? this.temperatureC,
    weatherCode: weatherCode ?? this.weatherCode,
    isCustom: isCustom ?? this.isCustom,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldCity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const List<WorldCity> kWorldCities = [
  WorldCity(
    id: 'bengaluru',
    name: 'Bengaluru',
    country: 'India',
    stdTzCode: 'IST',
    dstTzCode: 'IST',
    stdOffsetMinutes: 330,
    dstOffsetMinutes: 330,
    dstRegion: 'NONE',
    lat: 12.97,
    lon: 77.59,
  ),
  WorldCity(
    id: 'mumbai',
    name: 'Mumbai',
    country: 'India',
    stdTzCode: 'IST',
    dstTzCode: 'IST',
    stdOffsetMinutes: 330,
    dstOffsetMinutes: 330,
    dstRegion: 'NONE',
    lat: 19.08,
    lon: 72.88,
  ),
  WorldCity(
    id: 'stockholm',
    name: 'Stockholm',
    country: 'Sweden',
    stdTzCode: 'CET',
    dstTzCode: 'CEST',
    stdOffsetMinutes: 60,
    dstOffsetMinutes: 120,
    dstRegion: 'EU',
    lat: 59.33,
    lon: 18.06,
  ),
  WorldCity(
    id: 'tokyo',
    name: 'Tokyo',
    country: 'Japan',
    stdTzCode: 'JST',
    dstTzCode: 'JST',
    stdOffsetMinutes: 540,
    dstOffsetMinutes: 540,
    dstRegion: 'NONE',
    lat: 35.68,
    lon: 139.77,
  ),
  WorldCity(
    id: 'newyork',
    name: 'New York',
    country: 'United States',
    stdTzCode: 'EST',
    dstTzCode: 'EDT',
    stdOffsetMinutes: -300,
    dstOffsetMinutes: -240,
    dstRegion: 'US',
    lat: 40.71,
    lon: -74.01,
  ),
  WorldCity(
    id: 'london',
    name: 'London',
    country: 'United Kingdom',
    stdTzCode: 'GMT',
    dstTzCode: 'BST',
    stdOffsetMinutes: 0,
    dstOffsetMinutes: 60,
    dstRegion: 'EU',
    lat: 51.51,
    lon: -0.13,
  ),
  WorldCity(
    id: 'dubai',
    name: 'Dubai',
    country: 'UAE',
    stdTzCode: 'GST',
    dstTzCode: 'GST',
    stdOffsetMinutes: 240,
    dstOffsetMinutes: 240,
    dstRegion: 'NONE',
    lat: 25.20,
    lon: 55.27,
  ),
  WorldCity(
    id: 'singapore',
    name: 'Singapore',
    country: 'Singapore',
    stdTzCode: 'SGT',
    dstTzCode: 'SGT',
    stdOffsetMinutes: 480,
    dstOffsetMinutes: 480,
    dstRegion: 'NONE',
    lat: 1.35,
    lon: 103.82,
  ),
  WorldCity(
    id: 'paris',
    name: 'Paris',
    country: 'France',
    stdTzCode: 'CET',
    dstTzCode: 'CEST',
    stdOffsetMinutes: 60,
    dstOffsetMinutes: 120,
    dstRegion: 'EU',
    lat: 48.86,
    lon: 2.35,
  ),
  WorldCity(
    id: 'zurich',
    name: 'Zurich',
    country: 'Switzerland',
    stdTzCode: 'CET',
    dstTzCode: 'CEST',
    stdOffsetMinutes: 60,
    dstOffsetMinutes: 120,
    dstRegion: 'EU',
    lat: 47.37,
    lon: 8.54,
  ),
  WorldCity(
    id: 'sanfrancisco',
    name: 'San Francisco',
    country: 'United States',
    stdTzCode: 'PST',
    dstTzCode: 'PDT',
    stdOffsetMinutes: -480,
    dstOffsetMinutes: -420,
    dstRegion: 'US',
    lat: 37.77,
    lon: -122.42,
  ),
  WorldCity(
    id: 'cairo',
    name: 'Cairo',
    country: 'Egypt',
    stdTzCode: 'EET',
    dstTzCode: 'EEST',
    stdOffsetMinutes: 120,
    dstOffsetMinutes: 180,
    dstRegion: 'NONE',
    lat: 30.04,
    lon: 31.24,
  ),
  WorldCity(
    id: 'sydney',
    name: 'Sydney',
    country: 'Australia',
    stdTzCode: 'AEST',
    dstTzCode: 'AEDT',
    stdOffsetMinutes: 600,
    dstOffsetMinutes: 660,
    dstRegion: 'AU',
    lat: -33.87,
    lon: 151.21,
  ),
  WorldCity(
    id: 'saopaulo',
    name: 'São Paulo',
    country: 'Brazil',
    stdTzCode: 'BRT',
    dstTzCode: 'BRT',
    stdOffsetMinutes: -180,
    dstOffsetMinutes: -180,
    dstRegion: 'NONE',
    lat: -23.55,
    lon: -46.63,
  ),
  WorldCity(
    id: 'reykjavik',
    name: 'Reykjavik',
    country: 'Iceland',
    stdTzCode: 'GMT',
    dstTzCode: 'GMT',
    stdOffsetMinutes: 0,
    dstOffsetMinutes: 0,
    dstRegion: 'NONE',
    lat: 64.15,
    lon: -21.94,
  ),
  WorldCity(
    id: 'tromso',
    name: 'Tromsø',
    country: 'Norway',
    stdTzCode: 'CET',
    dstTzCode: 'CEST',
    stdOffsetMinutes: 60,
    dstOffsetMinutes: 120,
    dstRegion: 'EU',
    lat: 69.65,
    lon: 18.96,
  ),
];

class AlarmRhythm {
  final String id;
  final String title;
  final List<String> weekdays;
  final String soundMeta;
  final bool useCustomAudio;
  final bool enabled;
  final int wakeMinutes24;
  final int? snoozedUntilMinutes24;

  const AlarmRhythm({
    required this.id,
    required this.title,
    required this.weekdays,
    required this.soundMeta,
    required this.useCustomAudio,
    required this.enabled,
    required this.wakeMinutes24,
    this.snoozedUntilMinutes24,
  });

  static String formatMinutes(int mins24, {bool use24Hour = false}) {
    final int norm = ((mins24 % 1440) + 1440) % 1440;
    final int h24 = norm ~/ 60;
    final int m = norm % 60;
    final String mStr = m.toString().padLeft(2, '0');
    if (use24Hour) {
      return '${h24.toString().padLeft(2, '0')}:$mStr';
    }
    final String period = h24 >= 12 ? 'PM' : 'AM';
    final int h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '${h12.toString().padLeft(2, '0')}:$mStr $period';
  }

  String formatSchedule({bool use24Hour = false}) {
    final String timeStr = formatMinutes(wakeMinutes24, use24Hour: use24Hour);
    final String daysStr = weekdays.length >= 7
        ? 'Every day'
        : weekdays.join(', ');
    if (snoozedUntilMinutes24 != null) {
      final String snoozeStr = formatMinutes(
        snoozedUntilMinutes24!,
        use24Hour: use24Hour,
      );
      return '$timeStr | Snoozed to $snoozeStr';
    }
    return '$timeStr | $daysStr';
  }

  AlarmRhythm copyWith({
    String? title,
    List<String>? weekdays,
    String? soundMeta,
    bool? useCustomAudio,
    bool? enabled,
    int? wakeMinutes24,
    int? snoozedUntilMinutes24,
    bool clearSnooze = false,
  }) {
    return AlarmRhythm(
      id: id,
      title: title ?? this.title,
      weekdays: weekdays ?? this.weekdays,
      soundMeta: soundMeta ?? this.soundMeta,
      useCustomAudio: useCustomAudio ?? this.useCustomAudio,
      enabled: enabled ?? this.enabled,
      wakeMinutes24: wakeMinutes24 ?? this.wakeMinutes24,
      snoozedUntilMinutes24: clearSnooze
          ? null
          : (snoozedUntilMinutes24 ?? this.snoozedUntilMinutes24),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'weekdays': weekdays,
    'soundMeta': soundMeta,
    'useCustomAudio': useCustomAudio,
    'enabled': enabled,
    'wakeMinutes24': wakeMinutes24,
    'snoozedUntilMinutes24': snoozedUntilMinutes24,
  };

  factory AlarmRhythm.fromJson(Map<String, dynamic> json) {
    final List<String> parsedDays =
        (json['weekdays'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    return AlarmRhythm(
      id: json['id']?.toString() ?? 'alarm-0',
      title: json['title']?.toString() ?? 'Solar Awakening',
      weekdays: parsedDays,
      soundMeta:
          json['soundMeta']?.toString() ?? 'Soft gong | 15m gradual dawn swell',
      useCustomAudio: json['useCustomAudio'] == true,
      enabled: json['enabled'] != false,
      wakeMinutes24: (json['wakeMinutes24'] as num?)?.toInt() ?? 330,
      snoozedUntilMinutes24: (json['snoozedUntilMinutes24'] as num?)?.toInt(),
    );
  }
}

class ChronoLap {
  final int id;
  final String number;
  final int durationMs;
  final String formatted;
  final bool isFastest;
  final bool isSlowest;

  const ChronoLap({
    required this.id,
    required this.number,
    required this.durationMs,
    required this.formatted,
    this.isFastest = false,
    this.isSlowest = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'durationMs': durationMs,
    'formatted': formatted,
    'isFastest': isFastest,
    'isSlowest': isSlowest,
  };

  factory ChronoLap.fromJson(Map<String, dynamic> json) => ChronoLap(
    id: (json['id'] as num?)?.toInt() ?? 0,
    number: json['number']?.toString() ?? '01',
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    formatted: json['formatted']?.toString() ?? '00:00.00',
    isFastest: json['isFastest'] == true,
    isSlowest: json['isSlowest'] == true,
  );
}

class FocusPreset {
  final String id;
  final String label;
  final String activeLabel;
  final int totalSec;
  final String badge;

  const FocusPreset({
    required this.id,
    required this.label,
    required this.activeLabel,
    required this.totalSec,
    required this.badge,
  });
}

const List<FocusPreset> kFocusPresets = [
  FocusPreset(
    id: '12m',
    label: '12m',
    activeLabel: '12m (Sprint)',
    totalSec: 12 * 60,
    badge: '12m Focus Session',
  ),
  FocusPreset(
    id: '24m',
    label: '24m',
    activeLabel: '24m (Focus)',
    totalSec: 24 * 60,
    badge: '24m Focus Session',
  ),
  FocusPreset(
    id: '25m',
    label: '25m',
    activeLabel: '25m (Pomodoro)',
    totalSec: 25 * 60,
    badge: '25m Focus Session',
  ),
  FocusPreset(
    id: '48m',
    label: '48m',
    activeLabel: '48m (Double)',
    totalSec: 48 * 60,
    badge: '48m Focus Session',
  ),
  FocusPreset(
    id: '90m',
    label: '90m',
    activeLabel: '90m (Deep Flow)',
    totalSec: 90 * 60,
    badge: '90m Focus Session',
  ),
];

const List<List<List<double>>> kContinentPolygons = [
  [
    [-9, 36],
    [-5, 48],
    [10, 60],
    [26, 71],
    [65, 70],
    [105, 73],
    [170, 66],
    [142, 52],
    [140, 36],
    [122, 31],
    [108, 21],
    [103, 2],
    [96, 16],
    [88, 22],
    [77, 8],
    [68, 24],
    [55, 24],
    [48, 30],
    [36, 36],
    [28, 41],
    [15, 38],
    [-9, 36],
  ],
  [
    [-17, 15],
    [-6, 35],
    [10, 37],
    [32, 31],
    [43, 12],
    [51, 11],
    [40, -11],
    [35, -25],
    [20, -35],
    [14, -22],
    [9, 4],
    [-8, 5],
    [-17, 15],
  ],
  [
    [-166, 65],
    [-130, 70],
    [-78, 72],
    [-55, 50],
    [-75, 35],
    [-81, 25],
    [-97, 19],
    [-83, 9],
    [-105, 20],
    [-124, 48],
    [-166, 65],
  ],
  [
    [-52, 60],
    [-20, 65],
    [-18, 78],
    [-55, 81],
    [-52, 60],
  ],
  [
    [-80, 9],
    [-60, 10],
    [-35, -6],
    [-48, -28],
    [-68, -54],
    [-75, -46],
    [-71, -18],
    [-81, -4],
    [-80, 9],
  ],
  [
    [114, -22],
    [132, -12],
    [153, -26],
    [146, -38],
    [130, -32],
    [115, -34],
    [114, -22],
  ],
];
