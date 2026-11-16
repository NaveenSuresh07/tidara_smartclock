import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../services/native_platform_bridge.dart';

typedef JsonMap = Map<String, dynamic>;

/// Source of the master 256-bit encryption key used by [EncryptedVault].
enum VaultKeySource {
  /// Key is stored in secure storage backed by Android Keystore (via flutter_secure_storage).
  secureStorageKeystore,

  /// Fallback in-memory key used when secure storage is unavailable (e.g. headless tests or Keystore error).
  ephemeralFallback,
}

/// Authenticated encrypted vault utilizing NIST FIPS-197 AES-256-GCM
/// authenticated encryption from package:cryptography.
///
/// State is encrypted with AES-256-GCM. The key is stored using Android
/// Keystore-backed secure storage (via flutter_secure_storage).
/// Payload confidentiality and integrity are protected with 128-bit
/// GCM MAC tags and fresh 96-bit CSPRNG nonces per write.
class EncryptedVault {
  static const int schemaVersion = 4;
  static const String _keyStorageName = 'tidara_aes256_gcm_master_key_v4';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static final DartAesGcm _gcm = DartAesGcm.with256bits();
  static String? _durableDirectoryPath;
  static String _persistedEnvelopeJson = '';
  static Uint8List _activeKeyBytes = _generateRandomBytes(32);
  static VaultKeySource _activeKeySource = VaultKeySource.ephemeralFallback;

  static Uint8List _generateRandomBytes(int length) {
    final rng = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  static Uint8List generateSecureKey() => _generateRandomBytes(32);

  static Uint8List get activeKeyBytes => Uint8List.fromList(_activeKeyBytes);

  /// Reports whether the active key was loaded from Keystore-backed secure storage
  /// or from the ephemeral in-memory fallback.
  static VaultKeySource get activeKeySource => _activeKeySource;

  /// Diagnostic security telemetry for debugging and verification.
  static Map<String, dynamic> get securityDiagnostics => {
    'algorithm': 'AES-256-GCM',
    'keySource': _activeKeySource.name,
    'keyLengthBits': _activeKeyBytes.length * 8,
    'schemaVersion': schemaVersion,
    'hasPersistedData': _persistedEnvelopeJson.isNotEmpty,
  };

  static void setActiveKeyForTesting(Uint8List keyBytes) {
    if (keyBytes.length != 32) {
      throw ArgumentError('AES-256-GCM key must be 32 bytes (256 bits).');
    }
    _activeKeyBytes = Uint8List.fromList(keyBytes);
  }

  static void configureDurableDirectory(String path) {
    if (path.trim().isNotEmpty) {
      _durableDirectoryPath = path.trim();
    }
  }

  static File _resolveVaultFile() {
    final dir = _durableDirectoryPath ?? Directory.systemTemp.path;
    return File('$dir${Platform.pathSeparator}tidara_encrypted_store_v4.json');
  }

  static Future<void> initDurablePersistenceAsync({
    FlutterSecureStorage? secureStorage,
  }) async {
    final storage = secureStorage ?? _secureStorage;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      _durableDirectoryPath = docsDir.path;
    } catch (_) {
      final nativeDir = await NativePlatformBridge.getDurableStorageDir();
      if (nativeDir != null && nativeDir.isNotEmpty) {
        _durableDirectoryPath = nativeDir;
      }
    }

    try {
      final existingKeyB64 = await storage.read(key: _keyStorageName);
      if (existingKeyB64 != null && existingKeyB64.isNotEmpty) {
        final decoded = base64Url.decode(existingKeyB64);
        if (decoded.length == 32) {
          _activeKeyBytes = Uint8List.fromList(decoded);
          _activeKeySource = VaultKeySource.secureStorageKeystore;
        } else {
          _activeKeyBytes = _generateRandomBytes(32);
          await storage.write(
            key: _keyStorageName,
            value: base64Url.encode(_activeKeyBytes),
          );
          _activeKeySource = VaultKeySource.secureStorageKeystore;
        }
      } else {
        _activeKeyBytes = _generateRandomBytes(32);
        await storage.write(
          key: _keyStorageName,
          value: base64Url.encode(_activeKeyBytes),
        );
        _activeKeySource = VaultKeySource.secureStorageKeystore;
      }
    } catch (_) {
      // Secure storage unavailable (e.g. headless unit tests or Keystore error).
      // Falls back to ephemeral in-memory 256-bit key.
      _activeKeySource = VaultKeySource.ephemeralFallback;
    }

    if (kDebugMode) {
      debugPrint(
        '[Tidara Security] EncryptedVault initialized with keySource: ${_activeKeySource.name}',
      );
    }

    initDiskPersistence();
  }

  /// Rotates the master AES-256 key used to encrypt the local vault payload.
  ///
  /// Steps:
  /// 1. Validates that [newKey] is 32 bytes (256 bits), or generates a fresh
  ///    CSPRNG 256-bit key if omitted.
  /// 2. If existing persisted data is present, decrypts and authenticates it
  ///    using current active credentials.
  /// 3. Re-encrypts the decrypted payload using the new master key.
  /// 4. Commits the new key to [_secureStorage] (or injected [secureStorage]).
  /// 5. Atomically writes the re-encrypted envelope to disk.
  /// 6. Updates [_activeKeyBytes] and [_persistedEnvelopeJson].
  ///
  /// Rollback safety: If decryption, re-encryption, secure storage write, or
  /// disk commit fails, the previous active key and payload remain intact.
  static Future<bool> rotateMasterKey({
    Uint8List? newKey,
    FlutterSecureStorage? secureStorage,
  }) async {
    final candidateKey = newKey ?? _generateRandomBytes(32);
    if (candidateKey.length != 32) {
      throw ArgumentError('AES-256-GCM key must be 32 bytes (256 bits).');
    }

    final storage = secureStorage ?? _secureStorage;
    String currentEnvelope = _persistedEnvelopeJson;

    // Check disk directly in case on-disk file was not cached due to integrity check
    final vaultFile = _resolveVaultFile();
    if (currentEnvelope.isEmpty && vaultFile.existsSync()) {
      try {
        final onDiskRaw = vaultFile.readAsStringSync().trim();
        if (onDiskRaw.isNotEmpty) {
          currentEnvelope = onDiskRaw;
        }
      } catch (_) {}
    }

    JsonMap? decryptedExisting;
    if (currentEnvelope.isNotEmpty) {
      decryptedExisting = await decryptPayloadAesGcmAsync(
        currentEnvelope,
        customKeyBytes: _activeKeyBytes,
      );
      decryptedExisting ??= decryptPayload(
        currentEnvelope,
        null,
        _activeKeyBytes,
      );
      // If persisted data cannot be authenticated or decrypted, abort safely
      if (decryptedExisting == null) {
        return false;
      }
    }

    String? newSerializedEnvelope;
    if (decryptedExisting != null) {
      try {
        newSerializedEnvelope = await encryptPayloadAesGcmAsync(
          decryptedExisting,
          customKeyBytes: candidateKey,
          persistToDisk: false,
        );
      } catch (_) {
        return false;
      }
    }

    final oldKeyBytes = Uint8List.fromList(_activeKeyBytes);

    try {
      await storage.write(
        key: _keyStorageName,
        value: base64Url.encode(candidateKey),
      );
    } catch (_) {
      // Secure storage write failed - abort before altering in-memory key or disk
      return false;
    }

    if (newSerializedEnvelope != null) {
      final targetFile = _resolveVaultFile();
      final tempFile = File('${targetFile.path}.tmp');
      try {
        await tempFile.writeAsString(newSerializedEnvelope, flush: true);
        await tempFile.rename(targetFile.path);
        _persistedEnvelopeJson = newSerializedEnvelope;
      } catch (_) {
        try {
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        } catch (_) {}
        // Rollback secure storage key if disk file write fails
        try {
          await storage.write(
            key: _keyStorageName,
            value: base64Url.encode(oldKeyBytes),
          );
        } catch (_) {}
        return false;
      }
    }

    _activeKeyBytes = Uint8List.fromList(candidateKey);
    _activeKeySource = VaultKeySource.secureStorageKeystore;
    return true;
  }

  static void initDiskPersistence() {
    try {
      final file = _resolveVaultFile();
      if (file.existsSync()) {
        final raw = file.readAsStringSync().trim();
        if (raw.isNotEmpty && decryptPayload(raw) != null) {
          _persistedEnvelopeJson = raw;
        }
      }
    } catch (_) {}
  }

  static String get persistedCipher => _persistedEnvelopeJson;
  static String get currentCipher => _persistedEnvelopeJson;

  static void clearVault() {
    _persistedEnvelopeJson = '';
    try {
      final file = _resolveVaultFile();
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  static Map<String, double> anonymizeCoordinates(double lat, double lon) {
    return {
      'lat': double.parse(lat.toStringAsFixed(4)),
      'lon': double.parse(lon.toStringAsFixed(4)),
    };
  }

  /// IEEE 802.3 32-bit Cyclic Redundancy Check (CRC-32)
  static int computeCrc32(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc ^= b;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >>> 1) ^ 0xEDB88320;
        } else {
          crc >>>= 1;
        }
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static String computeCrc32Hex(List<int> bytes) {
    final crc = computeCrc32(bytes);
    return crc.toRadixString(16).padLeft(8, '0');
  }

  /// Verifies authentic NIST SP 800-38D test vectors for AES-256-GCM.
  static bool verifyNistTestVectors() {
    try {
      final key = Uint8List(32);
      final iv = Uint8List(12);
      final pt = Uint8List(0);
      final aad = Uint8List(0);

      final box13 = _gcm.encryptSync(
        pt,
        secretKeyData: SecretKeyData(key),
        nonce: iv,
        aad: aad,
      );
      final tag13Hex = box13.mac.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (tag13Hex != '530f8afbc74536b9a963b4f1c4cb738b') {
        return false;
      }

      final pt14 = Uint8List(16);
      final box14 = _gcm.encryptSync(
        pt14,
        secretKeyData: SecretKeyData(key),
        nonce: iv,
        aad: aad,
      );
      final ct14Hex = box14.cipherText
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final tag14Hex = box14.mac.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      if (ct14Hex != 'cea7403d4d606b6e074ec5d3baf39d18' ||
          tag14Hex != 'd0d1c8a799996bf0265b98b5d48ab919') {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Encrypts [data] asynchronously using genuine AES-256-GCM authenticated encryption.
  static Future<String> encryptPayloadAesGcmAsync(
    JsonMap data, {
    Uint8List? customKeyBytes,
    bool persistToDisk = true,
  }) async {
    final keyBytes = customKeyBytes ?? _activeKeyBytes;
    final secretKey = SecretKey(keyBytes);
    final nonce = _generateRandomBytes(12);
    final aadStr = 'tidara_aes256_gcm_v$schemaVersion';
    final aadBytes = utf8.encode(aadStr);

    final enrichedData = <String, dynamic>{
      ...data,
      '_customAudioMapEmbedded': NativePlatformBridge.exportCustomAudioMap(),
    };
    final plainBytes = utf8.encode(jsonEncode(enrichedData));

    final secretBox = await _gcm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: aadBytes,
    );

    final envelope = <String, dynamic>{
      'v': schemaVersion,
      'alg': 'AES-256-GCM',
      'nonce': base64Url.encode(secretBox.nonce),
      'aad': aadStr,
      'tag': base64Url.encode(secretBox.mac.bytes),
      'ct': base64Url.encode(secretBox.cipherText),
    };

    final serialized = jsonEncode(envelope);

    if (persistToDisk) {
      _persistedEnvelopeJson = serialized;
      try {
        final targetFile = _resolveVaultFile();
        final tempFile = File('${targetFile.path}.tmp');
        await tempFile.writeAsString(serialized, flush: true);
        await tempFile.rename(targetFile.path);
      } catch (_) {}
    }

    return serialized;
  }

  /// Decrypts [serializedEnvelope] asynchronously with cryptographic authentication.
  static Future<JsonMap?> decryptPayloadAesGcmAsync(
    String serializedEnvelope, {
    Uint8List? customKeyBytes,
  }) async {
    if (serializedEnvelope.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(serializedEnvelope);
      if (decoded is! Map<String, dynamic>) return null;

      final version = decoded['v'] as int?;
      if (version == 1 || version == 2) {
        return _migrateLegacyEnvelope(decoded);
      }
      if (version != schemaVersion) return null;
      if (decoded['alg'] != 'AES-256-GCM') return null;

      final nonceB64 = decoded['nonce'] as String?;
      final aadStr = decoded['aad'] as String?;
      final tagB64 = decoded['tag'] as String?;
      final ctB64 = decoded['ct'] as String?;
      if (nonceB64 == null ||
          aadStr == null ||
          tagB64 == null ||
          ctB64 == null) {
        return null;
      }
      if (aadStr != 'tidara_aes256_gcm_v$schemaVersion') return null;

      final nonce = Uint8List.fromList(base64Url.decode(nonceB64));
      final tag = Uint8List.fromList(base64Url.decode(tagB64));
      final cipherText = Uint8List.fromList(base64Url.decode(ctB64));
      if (nonce.length != 12 || tag.length != 16) return null;

      final keyBytes = customKeyBytes ?? _activeKeyBytes;
      final secretKey = SecretKey(keyBytes);

      final decryptedBytes = await _gcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: secretKey,
        aad: utf8.encode(aadStr),
      );

      final payloadMap = jsonDecode(utf8.decode(decryptedBytes));
      if (payloadMap is JsonMap) {
        final embeddedAudio = payloadMap['_customAudioMapEmbedded'];
        if (embeddedAudio is Map<String, dynamic>) {
          NativePlatformBridge.importCustomAudioMap(embeddedAudio);
        }
        return payloadMap;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Synchronous authenticated encryption using package:cryptography's DartAesGcm engine.
  static String encryptPayload(
    JsonMap data, {
    Uint8List? customKeyBytes,
    bool persistToDisk = true,
  }) {
    final keyBytes = customKeyBytes ?? _activeKeyBytes;
    final secretKeyData = SecretKeyData(keyBytes);
    final nonce = _generateRandomBytes(12);
    final aadStr = 'tidara_aes256_gcm_v$schemaVersion';
    final aadBytes = utf8.encode(aadStr);

    final enrichedData = <String, dynamic>{
      ...data,
      '_customAudioMapEmbedded': NativePlatformBridge.exportCustomAudioMap(),
    };
    final plainBytes = utf8.encode(jsonEncode(enrichedData));

    final secretBox = _gcm.encryptSync(
      plainBytes,
      secretKeyData: secretKeyData,
      nonce: nonce,
      aad: aadBytes,
    );

    final envelope = <String, dynamic>{
      'v': schemaVersion,
      'alg': 'AES-256-GCM',
      'nonce': base64Url.encode(secretBox.nonce),
      'aad': aadStr,
      'tag': base64Url.encode(secretBox.mac.bytes),
      'ct': base64Url.encode(secretBox.cipherText),
    };

    final serialized = jsonEncode(envelope);

    if (persistToDisk) {
      _persistedEnvelopeJson = serialized;
      try {
        final targetFile = _resolveVaultFile();
        final tempFile = File('${targetFile.path}.tmp');
        tempFile.writeAsStringSync(serialized, flush: true);
        tempFile.renameSync(targetFile.path);
      } catch (_) {}
    }

    return serialized;
  }

  /// Synchronous authenticated decryption using package:cryptography's DartAesGcm engine.
  static JsonMap? decryptPayload(
    String serializedEnvelope, [
    String? legacySecret,
    Uint8List? customKeyBytes,
  ]) {
    if (serializedEnvelope.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(serializedEnvelope);
      if (decoded is! Map<String, dynamic>) return null;

      final version = decoded['v'] as int?;
      if (version == 1 || version == 2) {
        return _migrateLegacyEnvelope(decoded);
      }
      if (version != schemaVersion) return null;
      if (decoded['alg'] != 'AES-256-GCM') return null;

      final nonceB64 = decoded['nonce'] as String?;
      final aadStr = decoded['aad'] as String?;
      final tagB64 = decoded['tag'] as String?;
      final ctB64 = decoded['ct'] as String?;
      if (nonceB64 == null ||
          aadStr == null ||
          tagB64 == null ||
          ctB64 == null) {
        return null;
      }
      if (aadStr != 'tidara_aes256_gcm_v$schemaVersion') return null;

      final nonce = Uint8List.fromList(base64Url.decode(nonceB64));
      final tag = Uint8List.fromList(base64Url.decode(tagB64));
      final cipherText = Uint8List.fromList(base64Url.decode(ctB64));
      if (nonce.length != 12 || tag.length != 16) return null;

      final keyBytes = customKeyBytes ?? _activeKeyBytes;
      final secretKeyData = SecretKeyData(keyBytes);

      final plainBytes = _gcm.decryptSync(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKeyData: secretKeyData,
        aad: utf8.encode(aadStr),
      );

      final payloadMap = jsonDecode(utf8.decode(plainBytes));
      if (payloadMap is JsonMap) {
        final embeddedAudio = payloadMap['_customAudioMapEmbedded'];
        if (embeddedAudio is Map<String, dynamic>) {
          NativePlatformBridge.importCustomAudioMap(embeddedAudio);
        }
        return payloadMap;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Migrates legacy v1 and v2 records safely using authentic CRC-32 integrity validation.
  /// Corrupted payloads or checksum mismatches are strictly rejected.
  static JsonMap? _migrateLegacyEnvelope(Map<String, dynamic> decoded) {
    try {
      final legacyB64 = decoded['payload'] as String?;
      final legacySum = decoded['checksum'] as String?;
      if (legacyB64 == null || legacySum == null || legacySum.isEmpty) {
        return null;
      }

      final payloadBytes = base64Url.decode(legacyB64);
      final expectedCrcHex = computeCrc32Hex(payloadBytes);

      // Verify CRC-32 integrity against tampering or bit corruption.
      // If legacySum matches CRC-32, or a valid legacy test token created with legacy CRC,
      // validate payload structure before returning.
      final matchesCrc =
          legacySum.toLowerCase() == expectedCrcHex.toLowerCase();
      if (!matchesCrc) {
        return null;
      }

      final migratedMap = jsonDecode(utf8.decode(payloadBytes));
      if (migratedMap is JsonMap) {
        return migratedMap;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Creates a valid legacy v1 envelope with authentic CRC-32 integrity checksum for migration tests.
  static String createLegacyV1EnvelopeForTesting(JsonMap data) {
    final payloadBytes = utf8.encode(jsonEncode(data));
    final b64 = base64Url.encode(payloadBytes);
    final crcHex = computeCrc32Hex(payloadBytes);
    return jsonEncode({'v': 1, 'checksum': crcHex, 'payload': b64});
  }
}
