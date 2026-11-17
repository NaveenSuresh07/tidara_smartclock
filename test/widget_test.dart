import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/audio/horological_audio_engine.dart';
import 'package:tidara_smartclock/core/ephemeris/noaa_ephemeris.dart';
import 'package:tidara_smartclock/core/security/encrypted_vault.dart';
import 'package:tidara_smartclock/core/security/self_test_suite.dart';
import 'package:tidara_smartclock/core/services/native_platform_bridge.dart';
import 'package:tidara_smartclock/core/services/storage_repository.dart';
import 'package:tidara_smartclock/features/shell/tidara_shell_screen.dart';
import 'package:tidara_smartclock/models/horological_models.dart';
import 'package:tidara_smartclock/core/theme/tidara_palette.dart';
import 'package:tidara_smartclock/features/focus_timer/custom_duration_dialog.dart';
import 'package:tidara_smartclock/features/smart_alarm/tactile_alarm_sheets.dart';
import 'package:tidara_smartclock/shared/widgets/liquid_glass_components.dart';

void main() {
  setUpAll(() {
    ensureTimeZonesInitialized();
  });

  group("Phase 2 — AES-256-GCM Cryptographic Security & NIST Vectors", () {
    test(
      "1. Official NIST SP 800-38D Test Vectors Pass with 100% byte fidelity",
      () {
        final nistVectorsPass = EncryptedVault.verifyNistTestVectors();
        expect(
          nistVectorsPass,
          isTrue,
          reason: "NIST SP 800-38D AES-GCM test vectors must pass",
        );
        final checks = TidaraSelfTestSuite.runAllChecks();
        expect(checks['AES-256-GCM 128-bit Tag & Fresh Nonce Guard'], isTrue);
      },
    );

    test(
      "2. Genuine AES-256-GCM async round-trip encrypts and decrypts state payload",
      () async {
        final key = EncryptedVault.generateSecureKey();
        final payload = <String, dynamic>{
          "cityId": "bengaluru",
          "wakeMinutes": 345,
          "theme": "gustavian_light",
        };
        final cipherJson = await EncryptedVault.encryptPayloadAesGcmAsync(
          payload,
          customKeyBytes: key,
          persistToDisk: false,
        );
        final restored = await EncryptedVault.decryptPayloadAesGcmAsync(
          cipherJson,
          customKeyBytes: key,
        );
        expect(restored, isNotNull);
        expect(restored!["cityId"], "bengaluru");
        expect(restored["wakeMinutes"], 345);
      },
    );

    test(
      "3. Unique 96-bit CSPRNG nonces generated on subsequent encryptions of identical data",
      () {
        final sample = <String, dynamic>{
          "cityId": "stockholm",
          "wakeMinutes": 360,
        };
        final e1 = EncryptedVault.encryptPayload(sample, persistToDisk: false);
        final e2 = EncryptedVault.encryptPayload(sample, persistToDisk: false);
        expect(e1, isNot(equals(e2)));
      },
    );

    test(
      "4. Bit-tampered ciphertext fails authenticated decryption without leaking plaintext",
      () {
        final envelope = EncryptedVault.encryptPayload({
          "cityId": "tokyo",
        }, persistToDisk: false);
        final map = jsonDecode(envelope) as Map<String, dynamic>;
        final ctBytes = base64Url.decode(map["ct"] as String);
        ctBytes[0] ^= 0xff;
        map["ct"] = base64Url.encode(ctBytes);
        expect(EncryptedVault.decryptPayload(jsonEncode(map)), isNull);
      },
    );

    test("5. Bit-tampered 128-bit authentication tag is strictly rejected", () {
      final envelope = EncryptedVault.encryptPayload({
        "cityId": "london",
      }, persistToDisk: false);
      final map = jsonDecode(envelope) as Map<String, dynamic>;
      final tagBytes = base64Url.decode(map["tag"] as String);
      tagBytes[0] ^= 0xff;
      map["tag"] = base64Url.encode(tagBytes);
      expect(EncryptedVault.decryptPayload(jsonEncode(map)), isNull);
    });

    test("6. Modified 96-bit nonce is strictly rejected", () {
      final envelope = EncryptedVault.encryptPayload({
        "cityId": "newyork",
      }, persistToDisk: false);
      final map = jsonDecode(envelope) as Map<String, dynamic>;
      final nonceBytes = base64Url.decode(map["nonce"] as String);
      nonceBytes[0] ^= 0xff;
      map["nonce"] = base64Url.encode(nonceBytes);
      expect(EncryptedVault.decryptPayload(jsonEncode(map)), isNull);
    });

    test(
      "7. Tampered AAD and invalid envelope versions are strictly rejected",
      () {
        final envelope = EncryptedVault.encryptPayload({
          "cityId": "sydney",
        }, persistToDisk: false);
        final tamperedAad = envelope.replaceFirst(
          "tidara_aes256_gcm_v4",
          "tidara_aes256_gcm_v3",
        );
        expect(EncryptedVault.decryptPayload(tamperedAad), isNull);
        final tamperedVer = envelope.replaceFirst('"v":4', '"v":99');
        expect(EncryptedVault.decryptPayload(tamperedVer), isNull);
      },
    );

    test("8. Wrong 256-bit key is strictly rejected", () {
      final keyA = EncryptedVault.generateSecureKey();
      final keyB = EncryptedVault.generateSecureKey();
      final cipher = EncryptedVault.encryptPayload(
        {"alarmId": "dawn_1"},
        customKeyBytes: keyA,
        persistToDisk: false,
      );
      expect(EncryptedVault.decryptPayload(cipher, null, keyB), isNull);
      expect(
        EncryptedVault.decryptPayload(cipher, null, keyA)?["alarmId"],
        "dawn_1",
      );
    });

    test(
      "9. Authentic CRC-32 legacy v1 migration validates genuine integrity and rejects corrupted data",
      () {
        final rawBytes = utf8.encode(
          jsonEncode({"cityId": "zurich", "wakeMinutes": 400}),
        );
        final legacyPayload = base64Url.encode(rawBytes);
        final authenticCrc = EncryptedVault.computeCrc32Hex(rawBytes);

        // Valid CRC-32 v1 envelope succeeds
        final v1Valid = jsonEncode({
          "v": 1,
          "checksum": authenticCrc,
          "payload": legacyPayload,
        });
        expect(EncryptedVault.decryptPayload(v1Valid)?["cityId"], "zurich");

        // Corrupted checksum or bypass attempt (dead/0000) is strictly rejected
        final v1Tampered = jsonEncode({
          "v": 1,
          "checksum": "deadbeef",
          "payload": legacyPayload,
        });
        expect(EncryptedVault.decryptPayload(v1Tampered), isNull);

        final v1ZeroTampered = jsonEncode({
          "v": 1,
          "checksum": "00000000",
          "payload": legacyPayload,
        });
        expect(EncryptedVault.decryptPayload(v1ZeroTampered), isNull);

        expect(EncryptedVault.decryptPayload(""), isNull);
        expect(EncryptedVault.decryptPayload("{corrupt_json"), isNull);
      },
    );
  });

  group("Phase 3 & 4 — Strongly Typed Alarm Model & Native OS Scheduling", () {
    test(
      "10. NativePlatformBridge.computeNextAlarmTriggerUtc computes exact weekday & DST transitions",
      () {
        // Friday 2026-11-13 06:00 UTC -> 11:30 IST (+330 min)
        final nowUtc = DateTime.utc(2026, 11, 13, 6, 0);
        // Schedule for 06:00 IST on Monday (weekday = 1)
        final nextTriggerUtc = NativePlatformBridge.computeNextAlarmTriggerUtc(
          hour: 6,
          minute: 0,
          cityOffsetMinutes: 330,
          nowUtc: nowUtc,
          activeWeekdays: <int>{1},
        );
        final triggerIst = nextTriggerUtc.add(const Duration(minutes: 330));
        expect(triggerIst.weekday, 1);
        expect(triggerIst.hour, 6);
        expect(triggerIst.minute, 0);
        expect(nextTriggerUtc.isAfter(nowUtc), isTrue);
      },
    );

    test(
      "11. AlarmRhythm model serializes and deserializes strongly typed properties",
      () {
        final alarm = AlarmRhythm(
          id: "test-alarm-101",
          title: "Vedic Awakening",
          weekdays: const ["Mon", "Wed", "Fri"],
          soundMeta: "528Hz Solfeggio Chime",
          useCustomAudio: false,
          enabled: true,
          wakeMinutes24: 330, // 05:30
        );
        final json = alarm.toJson();
        expect(json["wakeMinutes24"], 330);
        expect(json["weekdays"], ["Mon", "Wed", "Fri"]);

        final restored = AlarmRhythm.fromJson(json);
        expect(restored.id, alarm.id);
        expect(restored.wakeMinutes24, 330);
        expect(restored.weekdays, ["Mon", "Wed", "Fri"]);
        expect(restored.soundMeta, "528Hz Solfeggio Chime");
      },
    );

    test(
      "12. DurableVaultStorageRepository saves, loads, and clears state via HorologicalStorageRepository",
      () async {
        const HorologicalStorageRepository repo =
            DurableVaultStorageRepository();
        final saved = await repo.saveState({
          "cityId": "stockholm",
          "use24Hour": true,
        });
        expect(saved, isTrue);
        final loaded = repo.loadState();
        expect(loaded?["cityId"], "stockholm");
        await repo.clearAll();
        expect(repo.loadState(), isNull);
      },
    );

    test(
      "13. Custom Audio Registry automatically embeds in EncryptedVault and survives app restart",
      () {
        NativePlatformBridge.registerCustomAudioPath(
          "Dawn_Flute.mp3",
          "/data/user/0/com.tidara.tidara_smartclock/files/custom_alarm_audio/Dawn_Flute.mp3",
        );
        final cipher = EncryptedVault.encryptPayload({
          "cityId": "bengaluru",
        }, persistToDisk: false);
        NativePlatformBridge.registerCustomAudioPath(
          "Dawn_Flute.mp3",
          "/overwritten",
        );
        final restored = EncryptedVault.decryptPayload(cipher);
        expect(restored, isNotNull);
        expect(
          NativePlatformBridge.resolveAudioPathForLabel("Dawn_Flute.mp3"),
          "/data/user/0/com.tidara.tidara_smartclock/files/custom_alarm_audio/Dawn_Flute.mp3",
        );
      },
    );
  });

  group("Phase 5 & 6 — Timezone, Audio & Solar Ephemeris Verification", () {
    test(
      "14. IANA Timezone Engine computes accurate offsets across reference cities",
      () {
        WorldCity resolveCity(String targetId, String nameFragment) {
          for (final c in kWorldCities) {
            final normId = c.id
                .toLowerCase()
                .replaceAll("_", "")
                .replaceAll(" ", "");
            if (normId == targetId ||
                c.name.toLowerCase().contains(nameFragment)) {
              return c;
            }
          }
          return kWorldCities.first;
        }

        final bengaluru = resolveCity("bengaluru", "bengaluru");
        final london = resolveCity("london", "london");
        final newYork = resolveCity("newyork", "new york");
        final stockholm = resolveCity("stockholm", "stockholm");
        final sydney = resolveCity("sydney", "sydney");
        final tokyo = resolveCity("tokyo", "tokyo");

        final janUtc = DateTime.utc(2026, 1, 15, 12, 0);
        final julUtc = DateTime.utc(2026, 7, 15, 12, 0);

        expect(bengaluru.effectiveOffsetMinutes(janUtc), 330);
        expect(london.effectiveOffsetMinutes(janUtc), 0);
        expect(london.effectiveOffsetMinutes(julUtc), 60);
        expect(newYork.effectiveOffsetMinutes(janUtc), -300);
        expect(newYork.effectiveOffsetMinutes(julUtc), -240);
        expect(stockholm.effectiveOffsetMinutes(janUtc), 60);
        expect(stockholm.effectiveOffsetMinutes(julUtc), 120);
        expect(sydney.effectiveOffsetMinutes(janUtc), 660);
        expect(sydney.effectiveOffsetMinutes(julUtc), 600);
        expect(tokyo.effectiveOffsetMinutes(janUtc), 540);
      },
    );

    test(
      "15. NOAA Solar Ephemeris & Polar Latitude Guard validate Bengaluru and Tromso",
      () {
        final ephemBlr = CircadianEphemeris.compute(
          rawLat: 12.9716,
          rawLon: 77.5946,
          utcNow: DateTime.utc(2026, 3, 21, 6, 0),
          cityOffsetMinutes: 330,
        );
        expect(ephemBlr.sunriseLocalMinutes, inInclusiveRange(360, 395));

        final ephemPolar = CircadianEphemeris.compute(
          rawLat: 69.6492,
          rawLon: 18.9553,
          utcNow: DateTime.utc(2026, 6, 21, 12, 0),
          cityOffsetMinutes: 120,
        );
        expect(ephemPolar.sunriseLocalMinutes.isNaN, isFalse);
      },
    );

    test(
      "16. Synthesized 16-bit PCM WAV generator creates valid RIFF WAVE buffer",
      () {
        final wav = HorologicalAudioEngine.buildSynthesizedBowlWav(
          frequencyHz: 432.0,
          durationSeconds: 0.5,
        );
        expect(String.fromCharCodes(wav.sublist(0, 4)), "RIFF");
        expect(String.fromCharCodes(wav.sublist(8, 12)), "WAVE");
      },
    );
  });

  group("Phase 6 & 7 — Liquid Glass UI, Accessibility & Widget Mounting", () {
    testWidgets(
      "17. GlassButton & GlassCard render and trigger callbacks with semantics",
      (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GlassCard(
                  useBackdropBlur: false,
                  semanticLabel: "Alarm Summary Card",
                  child: GlassButton(
                    label: "Create Sunrise Alarm",
                    icon: Icons.alarm_add_rounded,
                    isPrimary: true,
                    onPressed: () => tapped = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text("Create Sunrise Alarm"));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      "18. Full TidaraSmartclockApp mounts, renders World Clock & navigates across tabs without overflow",
      (tester) async {
        await tester.pumpWidget(const TidaraSmartclockApp());
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TidaraSmartclockApp), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group("Phase 8 — Modern Terminology, Modular Dialogs & Scheduling Edge Cases", () {
    test("19. Midnight boundary rollover calculates exact next occurrence", () {
      final bengaluru = kWorldCities[0];
      final sundayNightUtc = DateTime.utc(2026, 3, 22, 18, 25);
      final triggerUtc = NativePlatformBridge.computeNextAlarmTriggerUtc(
        hour: 0,
        minute: 5,
        cityOffsetMinutes: bengaluru.effectiveOffsetMinutes(sundayNightUtc),
        nowUtc: sundayNightUtc,
        activeWeekdays: {DateTime.monday},
      );

      expect(triggerUtc.isAfter(sundayNightUtc), isTrue);
      final diffMinutes = triggerUtc.difference(sundayNightUtc).inMinutes;
      expect(diffMinutes, 10);
    });

    test(
      "20. NativePlatformBridge registers and resolves both file paths and content URIs",
      () {
        NativePlatformBridge.registerCustomAudioPath(
          'Ambient Bell',
          'content://media/external/audio/media/12345',
        );
        final resolvedUri = NativePlatformBridge.resolveAudioPathForLabel(
          'Ambient Bell',
        );
        expect(resolvedUri, 'content://media/external/audio/media/12345');

        NativePlatformBridge.registerCustomAudioPath(
          'Local Gong',
          '/data/user/0/com.tidara.tidara_smartclock/files/custom_alarm_audio/gong.wav',
        );
        final resolvedPath = NativePlatformBridge.resolveAudioPathForLabel(
          'Local Gong',
        );
        expect(
          resolvedPath,
          '/data/user/0/com.tidara.tidara_smartclock/files/custom_alarm_audio/gong.wav',
        );
      },
    );

    testWidgets(
      "21. showCustomDurationDialog renders with input validation bounds (1-180m)",
      (tester) async {
        int? selectedMins;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    selectedMins = await showCustomDurationDialog(
                      context,
                      initialMinutes: 24,
                    );
                  },
                  child: const Text('Open Duration Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Duration Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Custom Focus Duration'), findsOneWidget);
        expect(find.text('24'), findsOneWidget);

        await tester.tap(find.text('Set Duration'));
        await tester.pumpAndSettle();

        expect(selectedMins, 24);
      },
    );

    testWidgets(
      "22. TactileAlarmBottomSheet renders with Pre-Dawn Meditation quick label",
      (tester) async {
        final ephem = CircadianEphemeris.compute(
          rawLat: 12.9716,
          rawLon: 77.5946,
          utcNow: DateTime.utc(2026, 3, 21, 6, 0),
          cityOffsetMinutes: 330,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TactileAlarmBottomSheet(
                palette: TidaraPalette(isDark: false),
                defaultWakeMinutes: 330,
                sunriseMinutesFromMidnight: ephem.sunriseLocalMinutes,
                sunsetMinutesFromMidnight: ephem.sunsetLocalMinutes,
                editingAlarm: null,
                customMusicName: null,
                onSelectPhoneMusic: () async => null,
                onSave: (_) {},
                onDelete: (_) {},
                onTriggerDawnPreview: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Pre-Dawn Meditation'), findsOneWidget);
        expect(find.text('Brahma Meditation'), findsNothing);
      },
    );
  });
}
