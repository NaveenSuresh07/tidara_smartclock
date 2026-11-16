import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidara_smartclock/core/security/encrypted_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStore = <String, String>{};
  bool mockSecureStorageShouldThrow = false;
  bool mockSecureStorageShouldThrowOnWrite = false;
  late Directory tempDir;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall call) async {
            if (mockSecureStorageShouldThrow) {
              throw PlatformException(
                code: 'KEYSTORE_ERROR',
                message: 'Simulated keystore error',
              );
            }
            if (call.method == 'write' && mockSecureStorageShouldThrowOnWrite) {
              throw PlatformException(
                code: 'KEYSTORE_WRITE_FAIL',
                message: 'Simulated write failure',
              );
            }
            switch (call.method) {
              case 'read':
                final key = call.arguments['key'] as String?;
                return mockSecureStore[key];
              case 'write':
                final key = call.arguments['key'] as String;
                final val = call.arguments['value'] as String;
                mockSecureStore[key] = val;
                return null;
              case 'delete':
                final key = call.arguments['key'] as String;
                mockSecureStore.remove(key);
                return null;
              case 'deleteAll':
                mockSecureStore.clear();
                return null;
              default:
                return null;
            }
          },
        );
  });

  setUp(() {
    mockSecureStore.clear();
    mockSecureStorageShouldThrow = false;
    mockSecureStorageShouldThrowOnWrite = false;
    tempDir = Directory.systemTemp.createTempSync('tidara_sec_test_');
    EncryptedVault.configureDurableDirectory(tempDir.path);
    EncryptedVault.clearVault();
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('EncryptedVault — Master Key Rotation & Integrity Verification', () {
    test(
      '1. Validates key length constraints strictly (rejects non-32-byte keys)',
      () async {
        final invalidShortKey = Uint8List(16);
        expect(
          () => EncryptedVault.rotateMasterKey(newKey: invalidShortKey),
          throwsArgumentError,
        );

        final invalidLongKey = Uint8List(64);
        expect(
          () => EncryptedVault.rotateMasterKey(newKey: invalidLongKey),
          throwsArgumentError,
        );
      },
    );

    test(
      '2. Rotates master key on empty vault without persisted data',
      () async {
        final initialKey = EncryptedVault.activeKeyBytes;
        expect(initialKey.length, 32);

        final newKey = EncryptedVault.generateSecureKey();
        final success = await EncryptedVault.rotateMasterKey(newKey: newKey);

        expect(success, isTrue);
        expect(EncryptedVault.activeKeyBytes, equals(newKey));
        expect(EncryptedVault.activeKeyBytes, isNot(equals(initialKey)));
      },
    );

    test(
      '3. Re-encrypts existing persisted vault payload across key rotation',
      () async {
        // 1. Establish initial state
        final keyA = EncryptedVault.generateSecureKey();
        EncryptedVault.setActiveKeyForTesting(keyA);

        final originalData = <String, dynamic>{
          'cityId': 'stockholm',
          'wakeMinutes': 390,
          'label': 'Dawn Meditation',
        };
        final initialCipher = EncryptedVault.encryptPayload(
          originalData,
          persistToDisk: true,
        );
        expect(initialCipher.isNotEmpty, isTrue);

        // Verify keyA decrypts
        final decryptedWithA = EncryptedVault.decryptPayload(initialCipher);
        expect(decryptedWithA, isNotNull);
        expect(decryptedWithA!['cityId'], 'stockholm');

        // 2. Perform key rotation to keyB
        final keyB = EncryptedVault.generateSecureKey();
        final rotated = await EncryptedVault.rotateMasterKey(newKey: keyB);
        expect(rotated, isTrue);
        expect(EncryptedVault.activeKeyBytes, equals(keyB));

        // 3. Newly persisted ciphertext should decrypt cleanly with active key (keyB)
        final newCipher = EncryptedVault.persistedCipher;
        expect(newCipher, isNot(equals(initialCipher)));

        final decryptedWithB = EncryptedVault.decryptPayload(newCipher);
        expect(decryptedWithB, isNotNull);
        expect(decryptedWithB!['cityId'], 'stockholm');
        expect(decryptedWithB['wakeMinutes'], 390);
        expect(decryptedWithB['label'], 'Dawn Meditation');

        // 4. Old key (keyA) MUST fail to decrypt the rotated ciphertext (cryptographic authentication)
        final failedDecryptOldKey = EncryptedVault.decryptPayload(
          newCipher,
          null,
          keyA,
        );
        expect(failedDecryptOldKey, isNull);
      },
    );

    test(
      '4. Aborts rotation safely if persisted ciphertext is corrupted (rollback guard)',
      () async {
        final keyOriginal = EncryptedVault.generateSecureKey();
        EncryptedVault.setActiveKeyForTesting(keyOriginal);

        // Write corrupted envelope to disk
        final targetFile = File(
          '${tempDir.path}${Platform.pathSeparator}tidara_encrypted_store_v4.json',
        );
        targetFile.writeAsStringSync(
          '{"v":4,"alg":"AES-256-GCM","ct":"corrupted","tag":"corrupted","nonce":"corrupted"}',
        );
        EncryptedVault.initDiskPersistence();

        final keyCandidate = EncryptedVault.generateSecureKey();
        final rotated = await EncryptedVault.rotateMasterKey(
          newKey: keyCandidate,
        );

        // Should return false and preserve original key
        expect(rotated, isFalse);
        expect(EncryptedVault.activeKeyBytes, equals(keyOriginal));
      },
    );

    test(
      '5. Auto-generates cryptographically secure 256-bit key when newKey parameter is omitted',
      () async {
        final keyBefore = EncryptedVault.activeKeyBytes;
        final ok = await EncryptedVault.rotateMasterKey();

        expect(ok, isTrue);
        final keyAfter = EncryptedVault.activeKeyBytes;
        expect(keyAfter.length, 32);
        expect(keyAfter, isNot(equals(keyBefore)));
      },
    );

    test(
      '6. Mid-way failure: Secure storage write fails during rotation -> returns false and preserves readable old data',
      () async {
        final keyA = EncryptedVault.generateSecureKey();
        EncryptedVault.setActiveKeyForTesting(keyA);

        final originalData = <String, dynamic>{
          'userId': 'pilot_12',
          'theme': 'glass',
        };
        final initialCipher = EncryptedVault.encryptPayload(
          originalData,
          persistToDisk: true,
        );
        expect(initialCipher.isNotEmpty, isTrue);

        // Simulate secure storage write failure
        mockSecureStorageShouldThrowOnWrite = true;

        final candidateKey = EncryptedVault.generateSecureKey();
        final success = await EncryptedVault.rotateMasterKey(
          newKey: candidateKey,
        );

        expect(success, isFalse);
        // Active key remains keyA
        expect(EncryptedVault.activeKeyBytes, equals(keyA));

        // Old data on disk is still readable and decodable
        final decrypted = EncryptedVault.decryptPayload(
          EncryptedVault.persistedCipher,
        );
        expect(decrypted, isNotNull);
        expect(decrypted!['userId'], 'pilot_12');
      },
    );

    test(
      '7. Mid-way failure: Disk commit fails during rotation -> rolls back secure storage, active key, and preserves old data',
      () async {
        final keyA = EncryptedVault.generateSecureKey();
        EncryptedVault.setActiveKeyForTesting(keyA);

        final originalData = <String, dynamic>{
          'sensorId': 'gyro_44',
          'status': 'nominal',
        };
        final initialCipher = EncryptedVault.encryptPayload(
          originalData,
          persistToDisk: true,
        );
        expect(initialCipher.isNotEmpty, isTrue);

        // Block temp file write by creating a directory where .tmp file would be written
        final targetFilePath =
            '${tempDir.path}${Platform.pathSeparator}tidara_encrypted_store_v4.json.tmp';
        final blockingDir = Directory(targetFilePath);
        blockingDir.createSync(recursive: true);

        final candidateKey = EncryptedVault.generateSecureKey();
        final success = await EncryptedVault.rotateMasterKey(
          newKey: candidateKey,
        );

        expect(success, isFalse);
        // Active key remains keyA
        expect(EncryptedVault.activeKeyBytes, equals(keyA));

        // Clean up blocking directory
        blockingDir.deleteSync(recursive: true);

        // Old data is still readable
        final decrypted = EncryptedVault.decryptPayload(
          EncryptedVault.persistedCipher,
        );
        expect(decrypted, isNotNull);
        expect(decrypted!['sensorId'], 'gyro_44');
      },
    );

    test(
      '7b. Mid-way failure: Old-data decrypt fails during rotation (corrupted/mismatched key) -> returns false, preserves active key and leaves old data readable with its original key',
      () async {
        final originalKey = EncryptedVault.generateSecureKey();
        final payload = {'alarmId': 'dawn_chime', 'volume': 0.8};
        final cipher = EncryptedVault.encryptPayload(
          payload,
          customKeyBytes: originalKey,
          persistToDisk: true,
        );

        // Set mismatched active key in EncryptedVault
        final wrongKey = EncryptedVault.generateSecureKey();
        EncryptedVault.setActiveKeyForTesting(wrongKey);

        // Attempt key rotation - old-data decrypt will fail with wrongKey
        final candidateKey = EncryptedVault.generateSecureKey();
        final success = await EncryptedVault.rotateMasterKey(
          newKey: candidateKey,
        );

        expect(success, isFalse);
        // Active key was NOT changed to candidateKey
        expect(EncryptedVault.activeKeyBytes, equals(wrongKey));

        // Original persisted ciphertext is intact and decodable by originalKey
        final decrypted = EncryptedVault.decryptPayload(
          cipher,
          null,
          originalKey,
        );
        expect(decrypted, isNotNull);
        expect(decrypted!['alarmId'], 'dawn_chime');
      },
    );

    test(
      '8. Fallback decision logic: Uses Keystore when storage succeeds, falls back to ephemeral key when storage fails',
      () async {
        // Normal storage success
        mockSecureStorageShouldThrow = false;
        await EncryptedVault.initDurablePersistenceAsync();
        expect(
          EncryptedVault.activeKeySource,
          equals(VaultKeySource.secureStorageKeystore),
        );

        // When secure storage throws (e.g. headless tests or OS keystore unavailable)
        mockSecureStorageShouldThrow = true;
        await EncryptedVault.initDurablePersistenceAsync();
        expect(
          EncryptedVault.activeKeySource,
          equals(VaultKeySource.ephemeralFallback),
        );
      },
    );

    test(
      '9. Security regression: Legacy bypass payloads (startsWith dead or 0000) are strictly rejected',
      () {
        // Tampered v1 envelope with pseudo-valid 'deadbeef' checksum
        final fakeDeadEnvelope = jsonEncode({
          'v': 1,
          'checksum': 'deadbeef',
          'payload': base64Url.encode(utf8.encode('{"secret":"bypass"}')),
        });
        expect(EncryptedVault.decryptPayload(fakeDeadEnvelope), isNull);

        // Tampered v1 envelope with pseudo-valid '00000000' checksum
        final fakeZeroEnvelope = jsonEncode({
          'v': 1,
          'checksum': '00000000',
          'payload': base64Url.encode(utf8.encode('{"secret":"bypass"}')),
        });
        expect(EncryptedVault.decryptPayload(fakeZeroEnvelope), isNull);

        // Tampered v4 envelope with invalid nonce length
        final fakeDeadNonceEnvelope = jsonEncode({
          'v': 4,
          'alg': 'AES-256-GCM',
          'nonce': 'deadbeef0000',
          'aad': 'tidara_aes256_gcm_v4',
          'tag': base64Url.encode(Uint8List(16)),
          'ct': base64Url.encode(Uint8List(32)),
        });
        expect(EncryptedVault.decryptPayload(fakeDeadNonceEnvelope), isNull);
      },
    );

    test(
      '10. Security diagnostics getter reports complete cryptographic telemetry',
      () {
        final diag = EncryptedVault.securityDiagnostics;
        expect(diag['algorithm'], equals('AES-256-GCM'));
        expect(diag['keyLengthBits'], equals(256));
        expect(diag['schemaVersion'], equals(4));
        expect(diag.containsKey('keySource'), isTrue);
        expect(diag.containsKey('hasPersistedData'), isTrue);
      },
    );
  });
}
