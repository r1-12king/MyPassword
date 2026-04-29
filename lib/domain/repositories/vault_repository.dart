abstract class VaultRepository {
  Future<bool> hasVault();
  bool get hasVaultCached;
  bool get isUnlocked;
  Future<void> createVault({
    required String masterPassword,
    bool enableBiometricUnlock = false,
  });
  Future<bool> unlockVault({
    required String masterPassword,
  });
  Future<bool> verifyMasterPassword(String masterPassword);
  Future<void> changeMasterPassword({
    required String currentMasterPassword,
    required String newMasterPassword,
  });
  Future<bool> canUnlockWithBiometrics();
  Future<bool> unlockWithBiometrics();
  Future<void> enableBiometricUnlock();
  Future<void> disableBiometricUnlock();
  Future<void> lockVault();
  Future<void> resetVault();
}
