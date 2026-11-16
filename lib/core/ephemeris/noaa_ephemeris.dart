import 'dart:math' as math;
import '../security/encrypted_vault.dart';
import '../../models/horological_models.dart';

enum PolarSolarState { normal, polarDay, polarNight }

class CircadianEphemeris {
  final double anonymizedLat;
  final double anonymizedLon;
  final int sunriseLocalMinutes;
  final int sunsetLocalMinutes;
  final String sunriseFormatted;
  final String sunsetFormatted;
  final int currentGhatika;
  final double equationOfTimeMin;
  final double solarDeclinationDeg;
  final PolarSolarState polarState;

  const CircadianEphemeris({
    required this.anonymizedLat,
    required this.anonymizedLon,
    required this.sunriseLocalMinutes,
    required this.sunsetLocalMinutes,
    required this.sunriseFormatted,
    required this.sunsetFormatted,
    required this.currentGhatika,
    required this.equationOfTimeMin,
    required this.solarDeclinationDeg,
    required this.polarState,
  });

  static String formatMinutes12h(int mins24, {bool use24Hour = false}) {
    return AlarmRhythm.formatMinutes(mins24, use24Hour: use24Hour);
  }

  static CircadianEphemeris compute({
    required double rawLat,
    required double rawLon,
    required DateTime utcNow,
    required int cityOffsetMinutes,
    bool use24Hour = false,
  }) {
    final Map<String, double> anon = EncryptedVault.anonymizeCoordinates(
      rawLat,
      rawLon,
    );
    final double lat = anon['lat']!;
    final double lon = anon['lon']!;

    final DateTime cityLocalNow = utcNow.toUtc().add(
      Duration(minutes: cityOffsetMinutes),
    );
    final DateTime startOfYear = DateTime.utc(cityLocalNow.year, 1, 1);
    final int dayOfYear = cityLocalNow.difference(startOfYear).inDays + 1;

    const double rad = math.pi / 180.0;
    const double deg = 180.0 / math.pi;

    final double gamma =
        (2.0 * math.pi / 365.0) *
        (dayOfYear - 1 + (cityLocalNow.hour - 12.0) / 24.0);

    final double eqtime =
        229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));

    final double decl =
        0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma);

    const double zenith = 90.833 * rad;
    final double latRad = lat * rad;

    final double cosH =
        (math.cos(zenith) / (math.cos(latRad) * math.cos(decl))) -
        math.tan(latRad) * math.tan(decl);

    PolarSolarState polarState = PolarSolarState.normal;
    if (cosH < -1.0) {
      polarState = PolarSolarState.polarDay;
    } else if (cosH > 1.0) {
      polarState = PolarSolarState.polarNight;
    }

    final double clampedCosH = cosH.clamp(-1.0, 1.0);
    final double hourAngle = math.acos(clampedCosH) * deg;

    final double sunriseMinsUtc = 720.0 - 4.0 * (lon + hourAngle) - eqtime;
    final double sunsetMinsUtc = 720.0 - 4.0 * (lon - hourAngle) - eqtime;

    final int sunriseLocal =
        (((sunriseMinsUtc + cityOffsetMinutes).round() % 1440) + 1440) % 1440;
    final int sunsetLocal =
        (((sunsetMinsUtc + cityOffsetMinutes).round() % 1440) + 1440) % 1440;

    final int cityNowMins = cityLocalNow.hour * 60 + cityLocalNow.minute;
    final int minsSinceSunrise =
        ((cityNowMins - sunriseLocal) % 1440 + 1440) % 1440;
    final int ghatika = ((minsSinceSunrise ~/ 24) + 1).clamp(1, 60);

    return CircadianEphemeris(
      anonymizedLat: lat,
      anonymizedLon: lon,
      sunriseLocalMinutes: sunriseLocal,
      sunsetLocalMinutes: sunsetLocal,
      sunriseFormatted: polarState == PolarSolarState.polarDay
          ? 'Polar Day'
          : polarState == PolarSolarState.polarNight
          ? 'Polar Night'
          : formatMinutes12h(sunriseLocal, use24Hour: use24Hour),
      sunsetFormatted: polarState == PolarSolarState.polarDay
          ? 'Midnight Sun'
          : polarState == PolarSolarState.polarNight
          ? 'Polar Night'
          : formatMinutes12h(sunsetLocal, use24Hour: use24Hour),
      currentGhatika: ghatika,
      equationOfTimeMin: double.parse(eqtime.toStringAsFixed(2)),
      solarDeclinationDeg: double.parse((decl * deg).toStringAsFixed(2)),
      polarState: polarState,
    );
  }
}
