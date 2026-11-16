import '../security/encrypted_vault.dart';

abstract class HorologicalStorageRepository {
  Future<void> initialize();
  Future<Map<String, dynamic>?> loadStateAsync();
  Map<String, dynamic>? loadState();
  Future<bool> saveState(Map<String, dynamic> state);
  Future<void> clearAll();
}

class DurableVaultStorageRepository implements HorologicalStorageRepository {
  const DurableVaultStorageRepository();

  @override
  Future<void> initialize() async {
    await EncryptedVault.initDurablePersistenceAsync();
  }

  @override
  Future<Map<String, dynamic>?> loadStateAsync() async {
    final cipher = EncryptedVault.currentCipher;
    if (cipher.isEmpty) {
      return null;
    }
    return EncryptedVault.decryptPayloadAesGcmAsync(cipher);
  }

  @override
  Map<String, dynamic>? loadState() {
    final cipher = EncryptedVault.currentCipher;
    if (cipher.isEmpty) {
      return null;
    }
    return EncryptedVault.decryptPayload(cipher);
  }

  @override
  Future<bool> saveState(Map<String, dynamic> state) async {
    final serialized = await EncryptedVault.encryptPayloadAesGcmAsync(
      state,
      persistToDisk: true,
    );
    return serialized.isNotEmpty;
  }

  @override
  Future<void> clearAll() async {
    EncryptedVault.clearVault();
  }
}
