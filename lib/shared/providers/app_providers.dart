import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/cloud_sync/cloud_sync_repository.dart';
import '../../data/datasources/local/daos/credential_dao.dart';
import '../../data/datasources/local/daos/import_history_dao.dart';
import '../../data/datasources/local/daos/vault_meta_dao.dart';
import '../../data/datasources/local/db/app_database.dart';
import '../../domain/cloud_sync/cloud_sync_automation_service.dart';
import '../../domain/cloud_sync/cloud_sync_coordinator.dart';
import '../../domain/cloud_sync/cloud_sync_provider.dart';
import '../../domain/repositories/credential_repository.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../security/biometric/biometric_service.dart';
import '../../security/crypto/crypto_service.dart';
import '../../security/session/vault_session_controller.dart';
import '../../security/storage/secure_key_storage.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError();
});

final vaultMetaDaoProvider = Provider<VaultMetaDao>((ref) {
  throw UnimplementedError();
});

final credentialDaoProvider = Provider<CredentialDao>((ref) {
  throw UnimplementedError();
});

final importHistoryDaoProvider = Provider<ImportHistoryDao>((ref) {
  throw UnimplementedError();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final secureKeyStorageProvider = Provider<SecureKeyStorage>((ref) {
  throw UnimplementedError();
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  throw UnimplementedError();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  throw UnimplementedError();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  throw UnimplementedError();
});

final credentialRepositoryProvider = Provider<CredentialRepository>((ref) {
  throw UnimplementedError();
});

final cloudSyncRepositoryProvider = Provider<CloudSyncRepository>((ref) {
  throw UnimplementedError();
});

final cloudSyncProviderRegistryProvider =
    Provider<Map<CloudSyncProviderType, CloudSyncProvider>>((ref) {
      throw UnimplementedError();
    });

final cloudSyncCoordinatorProvider = Provider<CloudSyncCoordinator>((ref) {
  throw UnimplementedError();
});

final vaultSessionControllerProvider =
    StateNotifierProvider<VaultSessionController, VaultSessionState>((ref) {
      throw UnimplementedError();
    });

final cloudSyncAutomationServiceProvider =
    Provider<CloudSyncAutomationService>((ref) {
      throw UnimplementedError();
    });
