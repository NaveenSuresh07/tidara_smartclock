import 'encrypted_vault.dart';
import '../ephemeris/noaa_ephemeris.dart';
import '../../models/horological_models.dart';

class TidaraSelfTestSuite {
  static Map<String, bool> runAllChecks() {
    final results = <String, bool>{};

    final previousData = EncryptedVault.persistedCipher;
    try {
      final nistVectorsPass = EncryptedVault.verifyNistTestVectors();

      final sample = <String, dynamic>{
        'cityId': 'bengaluru',
        'wakeMinutes': 330,
      };
      final c1 = EncryptedVault.encryptPayload(sample, persistToDisk: false);
      final c2 = EncryptedVault.encryptPayload(sample, persistToDisk: false);
      final restored = EncryptedVault.decryptPayload(c1);

      final corrupted = c1.replaceFirst('"tag":"', '"tag":"0000');
      final rejected = EncryptedVault.decryptPayload(corrupted);

      results['AES-256-GCM 128-bit Tag & Fresh Nonce Guard'] =
          nistVectorsPass &&
          c1 != c2 &&
          restored != null &&
          restored['cityId'] == 'bengaluru' &&
          rejected == null;
    } catch (_) {
      results['AES-256-GCM 128-bit Tag & Fresh Nonce Guard'] = false;
    } finally {
      if (previousData.isNotEmpty) {
        EncryptedVault.decryptPayload(previousData);
      }
    }

    try {
      final sydney = kWorldCities.firstWhere((c) => c.id == 'sydney');
      final janOffset = sydney.effectiveOffsetMinutes(
        DateTime.utc(2026, 1, 15, 12),
      );
      final julOffset = sydney.effectiveOffsetMinutes(
        DateTime.utc(2026, 7, 15, 12),
      );
      results['DST Timezone Rules (Sydney AEDT/AEST)'] =
          janOffset == 660 && julOffset == 600;
    } catch (_) {
      results['DST Timezone Rules (Sydney AEDT/AEST)'] = false;
    }

    try {
      final ephem = CircadianEphemeris.compute(
        rawLat: 12.9716,
        rawLon: 77.5946,
        utcNow: DateTime.utc(2026, 3, 21, 6, 0),
        cityOffsetMinutes: 330,
      );
      results['Sunrise-Anchored Solar Ephemeris'] =
          ephem.sunriseLocalMinutes >= 360 &&
          ephem.sunriseLocalMinutes <= 395 &&
          ephem.currentGhatika >= 1 &&
          ephem.currentGhatika <= 60;
    } catch (_) {
      results['Sunrise-Anchored Solar Ephemeris'] = false;
    }

    return results;
  }
}
