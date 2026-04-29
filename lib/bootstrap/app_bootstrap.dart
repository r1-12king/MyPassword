import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cloud_sync/cloud_sync_repository_impl.dart';
import '../data/cloud_sync/providers/webdav/webdav_sync_provider.dart';
import '../core/localization/app_locale_controller.dart';
import '../core/settings/app_settings_controller.dart';
import '../data/datasources/local/daos/credential_dao.dart';
import '../data/datasources/local/daos/import_history_dao.dart';
import '../data/datasources/local/daos/vault_meta_dao.dart';
import '../data/datasources/local/db/app_database.dart';
import '../data/repositories/credential_repository_impl.dart';
import '../data/repositories/vault_repository_impl.dart';
import '../domain/cloud_sync/cloud_sync_automation_service.dart';
import '../domain/cloud_sync/cloud_sync_coordinator.dart';
import '../domain/cloud_sync/cloud_sync_models.dart';
import '../domain/cloud_sync/cloud_sync_provider.dart';
import '../security/biometric/biometric_service.dart';
import '../security/crypto/crypto_service.dart';
import '../security/session/vault_session_controller.dart';
import '../security/storage/secure_key_storage.dart';
import '../shared/providers/app_providers.dart';

class AppBootstrap {
  AppBootstrap._({
    required this.providerOverrides,
  });

  final List<Override> providerOverrides;

  static Future<AppBootstrap> initialize() async {
    final database = AppDatabase();
    await database.open();

    final vaultMetaDao = VaultMetaDaoImpl(database);
    final credentialDao = CredentialDaoImpl(database);
    final importHistoryDao = ImportHistoryDaoImpl(database);
    final sharedPreferences = await SharedPreferences.getInstance();
    final localeController = AppLocaleController(
      preferences: sharedPreferences,
    );
    final appSettingsController = AppSettingsController(
      preferences: sharedPreferences,
    );
    final vaultSessionController = VaultSessionController();
    final secureKeyStorage = SecureKeyStorageImpl();
    final cryptoService = CryptoServiceImpl(
      secureKeyStorage: secureKeyStorage,
    );
    final biometricService = BiometricService();
    final cloudSyncRepository = CloudSyncRepositoryImpl(
      preferences: sharedPreferences,
      secureKeyStorage: secureKeyStorage,
    );
    final webDavProvider = WebDavSyncProvider(
      loadConfig: () async => (await cloudSyncRepository.getCurrentConfig())?.webDavConfig,
    );

    final vaultRepository = VaultRepositoryImpl(
      vaultMetaDao: vaultMetaDao,
      credentialDao: credentialDao,
      cryptoService: cryptoService,
      secureKeyStorage: secureKeyStorage,
    );
    await vaultRepository.hasVault();

    final credentialRepository = CredentialRepositoryImpl(
      credentialDao: credentialDao,
      cryptoService: cryptoService,
      importHistoryDao: importHistoryDao,
      vaultMetaDao: vaultMetaDao,
    );
    final cloudSyncProviderRegistry = <CloudSyncProviderType, CloudSyncProvider>{
      CloudSyncProviderType.webdav: webDavProvider,
    };
    final cloudSyncCoordinator = CloudSyncCoordinatorImpl(
      loadConfig: cloudSyncRepository.getCurrentConfig,
      resolveProvider: (CloudSyncConfig config) async {
        return cloudSyncProviderRegistry[config.providerType];
      },
      credentialRepository: credentialRepository,
      loadSyncStatus: cloudSyncRepository.getStatus,
      markUploadSuccess: cloudSyncRepository.markUploadSuccess,
      markDownloadSuccess: cloudSyncRepository.markDownloadSuccess,
      setLastError: cloudSyncRepository.setLastError,
    );
    final cloudSyncAutomationService = CloudSyncAutomationServiceImpl(
      cloudSyncCoordinator: cloudSyncCoordinator,
      loadStatus: cloudSyncRepository.getStatus,
      markLocalChange: cloudSyncRepository.markLocalChange,
      readSettings: () => appSettingsController.currentState,
      readSessionMasterPassword: () => vaultSessionController.currentMasterPassword,
    );

    return AppBootstrap._(
      providerOverrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        appLocaleControllerProvider.overrideWith((ref) => localeController),
        appSettingsControllerProvider
            .overrideWith((ref) => appSettingsController),
        vaultSessionControllerProvider
            .overrideWith((ref) => vaultSessionController),
        vaultMetaDaoProvider.overrideWithValue(vaultMetaDao),
        credentialDaoProvider.overrideWithValue(credentialDao),
        importHistoryDaoProvider.overrideWithValue(importHistoryDao),
        secureKeyStorageProvider.overrideWithValue(secureKeyStorage),
        cryptoServiceProvider.overrideWithValue(cryptoService),
        biometricServiceProvider.overrideWithValue(biometricService),
        vaultRepositoryProvider.overrideWithValue(vaultRepository),
        credentialRepositoryProvider.overrideWithValue(credentialRepository),
        cloudSyncRepositoryProvider.overrideWithValue(cloudSyncRepository),
        cloudSyncProviderRegistryProvider.overrideWithValue(
          cloudSyncProviderRegistry,
        ),
        cloudSyncCoordinatorProvider.overrideWithValue(cloudSyncCoordinator),
        cloudSyncAutomationServiceProvider
            .overrideWithValue(cloudSyncAutomationService),
      ],
    );
  }
}
