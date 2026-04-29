import '../repositories/credential_repository.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_provider.dart';

abstract class CloudSyncCoordinator {
  Future<SyncStatusSnapshot> getStatus();
  Future<void> validateConnection();
  Future<RemoteSyncPackageMeta?> fetchRemoteMeta();
  Future<void> uploadCurrentVault({
    required String currentMasterPassword,
  });
  Future<DownloadedSyncPackage?> downloadLatestPackage();
}

class CloudSyncCoordinatorImpl implements CloudSyncCoordinator {
  CloudSyncCoordinatorImpl({
    required Future<CloudSyncConfig?> Function() loadConfig,
    required Future<CloudSyncProvider?> Function(CloudSyncConfig config) resolveProvider,
    required CredentialRepository credentialRepository,
    required Future<SyncStatusSnapshot> Function() loadSyncStatus,
    required Future<void> Function({DateTime? at}) markUploadSuccess,
    required Future<void> Function({DateTime? at}) markDownloadSuccess,
    required Future<void> Function(String? error) setLastError,
  })  : _loadConfig = loadConfig,
        _resolveProvider = resolveProvider,
        _credentialRepository = credentialRepository,
        _loadSyncStatus = loadSyncStatus,
        _markUploadSuccess = markUploadSuccess,
        _markDownloadSuccess = markDownloadSuccess,
        _setLastError = setLastError;

  final Future<CloudSyncConfig?> Function() _loadConfig;
  final Future<CloudSyncProvider?> Function(CloudSyncConfig config) _resolveProvider;
  final CredentialRepository _credentialRepository;
  final Future<SyncStatusSnapshot> Function() _loadSyncStatus;
  final Future<void> Function({DateTime? at}) _markUploadSuccess;
  final Future<void> Function({DateTime? at}) _markDownloadSuccess;
  final Future<void> Function(String? error) _setLastError;

  @override
  Future<SyncStatusSnapshot> getStatus() async {
    final config = await _loadConfig();
    if (config == null) {
      return const SyncStatusSnapshot(isConfigured: false);
    }

    final provider = await _resolveProvider(config);
    final configured = provider != null && await provider.isConfigured();
    final persisted = await _loadSyncStatus();
    return SyncStatusSnapshot(
      isConfigured: configured,
      lastLocalChangeAt: persisted.lastLocalChangeAt,
      lastUploadedAt: persisted.lastUploadedAt,
      lastDownloadedAt: persisted.lastDownloadedAt,
      lastError: persisted.lastError,
    );
  }

  @override
  Future<void> validateConnection() async {
    final config = await _loadConfig();
    if (config == null || !config.isValid) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.notConfigured,
      );
    }

    final provider = await _resolveProvider(config);
    if (provider == null) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.providerUnavailable,
      );
    }

    await provider.validateConnection();
  }

  @override
  Future<RemoteSyncPackageMeta?> fetchRemoteMeta() async {
    final config = await _loadConfig();
    if (config == null || !config.isValid) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.notConfigured,
      );
    }

    final provider = await _resolveProvider(config);
    if (provider == null) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.providerUnavailable,
      );
    }

    return provider.getRemoteMeta();
  }

  @override
  Future<void> uploadCurrentVault({
    required String currentMasterPassword,
  }) async {
    final config = await _loadConfig();
    if (config == null || !config.isValid) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.notConfigured,
      );
    }

    final provider = await _resolveProvider(config);
    if (provider == null) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.providerUnavailable,
      );
    }

    try {
      final exportData = await _credentialRepository.exportBackup(
        currentMasterPassword: currentMasterPassword,
      );

      await provider.uploadPackage(
        SyncPackageUpload(
          path: config.remotePath,
          bytes: exportData.bytes,
        ),
      );
      await _markUploadSuccess();
      await _setLastError(null);
    } on StateError catch (error) {
      if (error.message == 'Invalid master password') {
        await _setLastError(CloudSyncExceptionCode.invalidMasterPassword.name);
        throw const CloudSyncException(
          CloudSyncExceptionCode.invalidMasterPassword,
        );
      }
      rethrow;
    } on CloudSyncException catch (error) {
      await _setLastError(error.code.name);
      rethrow;
    } catch (_) {
      await _setLastError(CloudSyncExceptionCode.unknown.name);
      rethrow;
    }
  }

  @override
  Future<DownloadedSyncPackage?> downloadLatestPackage() async {
    final config = await _loadConfig();
    if (config == null || !config.isValid) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.notConfigured,
      );
    }

    final provider = await _resolveProvider(config);
    if (provider == null) {
      throw const CloudSyncException(
        CloudSyncExceptionCode.providerUnavailable,
      );
    }

    try {
      final downloaded = await provider.downloadPackage(config.remotePath);
      if (downloaded != null) {
        await _markDownloadSuccess();
        await _setLastError(null);
      }
      return downloaded;
    } on CloudSyncException catch (error) {
      await _setLastError(error.code.name);
      rethrow;
    } catch (_) {
      await _setLastError(CloudSyncExceptionCode.unknown.name);
      rethrow;
    }
  }
}
