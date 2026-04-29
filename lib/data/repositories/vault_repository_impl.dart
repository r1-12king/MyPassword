import '../../domain/repositories/vault_repository.dart';
import '../../security/crypto/crypto_service.dart';
import '../../security/storage/secure_key_storage.dart';
import '../datasources/local/daos/credential_dao.dart';
import '../datasources/local/daos/vault_meta_dao.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl({
    required VaultMetaDao vaultMetaDao,
    required CredentialDao credentialDao,
    required CryptoService cryptoService,
    required SecureKeyStorage secureKeyStorage,
  })  : _vaultMetaDao = vaultMetaDao,
        _credentialDao = credentialDao,
        _cryptoService = cryptoService,
        _secureKeyStorage = secureKeyStorage;

  final VaultMetaDao _vaultMetaDao;
  final CredentialDao _credentialDao;
  final CryptoService _cryptoService;
  final SecureKeyStorage _secureKeyStorage;

  bool _hasVaultCached = false;

  @override
  bool get hasVaultCached => _hasVaultCached;

  @override
  bool get isUnlocked => _cryptoService.isUnlocked;

  @override
  Future<bool> hasVault() async {
    _hasVaultCached = await _vaultMetaDao.hasVault();
    return _hasVaultCached;
  }

  @override
  Future<void> createVault({
    required String masterPassword,
    bool enableBiometricUnlock = false,
  }) async {
    if (await _vaultMetaDao.hasVault()) {
      throw StateError('Vault already exists');
    }

    final setup = await _cryptoService.createVaultSetup(masterPassword);
    await _vaultMetaDao.insertVaultMeta(setup.vaultMetaRecord);
    _hasVaultCached = true;

    if (enableBiometricUnlock && setup.biometricEnvelope != null) {
      await _secureKeyStorage.writeBiometricEnvelope(
        setup.biometricEnvelope!,
      );
    }
  }

  @override
  Future<bool> unlockVault({
    required String masterPassword,
  }) async {
    final row = await _vaultMetaDao.getVaultMetaRow();
    if (row == null) {
      return false;
    }

    final vaultMeta = VaultMetaRecord.fromRow(row);
    return _cryptoService.unlock(
      masterPassword: masterPassword,
      vaultMeta: vaultMeta,
    );
  }

  @override
  Future<bool> verifyMasterPassword(String masterPassword) async {
    final row = await _vaultMetaDao.getVaultMetaRow();
    if (row == null) {
      return false;
    }

    return _cryptoService.verifyMasterPassword(
      masterPassword: masterPassword,
      vaultMeta: VaultMetaRecord.fromRow(row),
    );
  }

  @override
  Future<void> changeMasterPassword({
    required String currentMasterPassword,
    required String newMasterPassword,
  }) async {
    final row = await _vaultMetaDao.getVaultMetaRow();
    if (row == null) {
      throw StateError('Vault not found');
    }

    final updatedVaultMeta = await _cryptoService.changeMasterPassword(
      currentMasterPassword: currentMasterPassword,
      newMasterPassword: newMasterPassword,
      vaultMeta: VaultMetaRecord.fromRow(row),
    );

    await _vaultMetaDao.insertVaultMeta(updatedVaultMeta);
  }

  @override
  Future<bool> canUnlockWithBiometrics() async {
    final envelope = await _secureKeyStorage.readBiometricEnvelope();
    return envelope != null && envelope.isNotEmpty;
  }

  @override
  Future<bool> unlockWithBiometrics() async {
    final envelope = await _secureKeyStorage.readBiometricEnvelope();
    if (envelope == null || envelope.isEmpty) {
      return false;
    }

    return _cryptoService.unlockWithBiometricEnvelope(envelope);
  }

  @override
  Future<void> enableBiometricUnlock() async {
    if (!_cryptoService.isUnlocked) {
      throw StateError('Vault is locked');
    }

    final envelope = await _cryptoService.createBiometricEnvelope();
    await _secureKeyStorage.writeBiometricEnvelope(envelope);
  }

  @override
  Future<void> disableBiometricUnlock() {
    return _secureKeyStorage.deleteBiometricEnvelope();
  }

  @override
  Future<void> lockVault() async {
    await _cryptoService.lock();
    await _secureKeyStorage.deleteSessionMaterial();
  }

  @override
  Future<void> resetVault() async {
    await _cryptoService.lock();
    await _secureKeyStorage.clearAll();
    await _vaultMetaDao.deleteVaultMeta();
    await _credentialDao.deleteAll();
    _hasVaultCached = false;
  }
}
