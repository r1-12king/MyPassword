import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/cloud_sync/cloud_sync_models.dart';
import '../../domain/cloud_sync/cloud_sync_provider.dart';
import '../../security/storage/secure_key_storage.dart';
import 'cloud_sync_repository.dart';

class CloudSyncRepositoryImpl implements CloudSyncRepository {
  CloudSyncRepositoryImpl({
    required SharedPreferences preferences,
    required SecureKeyStorage secureKeyStorage,
  })  : _preferences = preferences,
        _secureKeyStorage = secureKeyStorage;

  final SharedPreferences _preferences;
  final SecureKeyStorage _secureKeyStorage;

  static const _providerTypeKey = 'cloud_sync.provider_type';
  static const _webDavBaseUrlKey = 'cloud_sync.webdav.base_url';
  static const _webDavUsernameKey = 'cloud_sync.webdav.username';
  static const _webDavRemotePathKey = 'cloud_sync.webdav.remote_path';
  static const _lastLocalChangeAtKey = 'cloud_sync.last_local_change_at';
  static const _lastUploadedAtKey = 'cloud_sync.last_uploaded_at';
  static const _lastDownloadedAtKey = 'cloud_sync.last_downloaded_at';
  static const _lastHandledRemoteUpdatedAtKey =
      'cloud_sync.last_handled_remote_updated_at';
  static const _lastHandledRemoteEtagKey = 'cloud_sync.last_handled_remote_etag';
  static const _lastErrorKey = 'cloud_sync.last_error';

  @override
  Future<CloudSyncConfig?> getCurrentConfig() async {
    final providerTypeValue = _preferences.getString(_providerTypeKey);
    if (providerTypeValue == null || providerTypeValue.isEmpty) {
      return null;
    }

    if (providerTypeValue == CloudSyncProviderType.webdav.name) {
      final baseUrl = _preferences.getString(_webDavBaseUrlKey) ?? '';
      final username = _preferences.getString(_webDavUsernameKey) ?? '';
      final appPassword = await _secureKeyStorage.readWebDavAppPassword() ?? '';
      final remotePath =
          _preferences.getString(_webDavRemotePathKey) ??
              '/MyPassword/vault_sync.mpsync';

      return CloudSyncConfig(
        providerType: CloudSyncProviderType.webdav,
        remotePath: remotePath,
        webDavConfig: WebDavConfig(
          baseUrl: baseUrl,
          username: username,
          appPassword: appPassword,
          remotePath: remotePath,
        ),
      );
    }

    return const CloudSyncConfig(
      providerType: CloudSyncProviderType.baiduPan,
      remotePath: '/MyPassword/vault_sync.mpsync',
    );
  }

  @override
  Future<void> saveWebDavConfig(WebDavConfig config) async {
    await _preferences.setString(_providerTypeKey, CloudSyncProviderType.webdav.name);
    await _preferences.setString(_webDavBaseUrlKey, config.baseUrl);
    await _preferences.setString(_webDavUsernameKey, config.username);
    await _secureKeyStorage.writeWebDavAppPassword(config.appPassword);
    await _preferences.setString(_webDavRemotePathKey, config.remotePath);
  }

  @override
  Future<SyncStatusSnapshot> getStatus() async {
    final config = await getCurrentConfig();
    return SyncStatusSnapshot(
      isConfigured: config?.isValid ?? false,
      lastLocalChangeAt: _readDateTime(_lastLocalChangeAtKey),
      lastUploadedAt: _readDateTime(_lastUploadedAtKey),
      lastDownloadedAt: _readDateTime(_lastDownloadedAtKey),
      lastHandledRemoteUpdatedAt: _readDateTime(_lastHandledRemoteUpdatedAtKey),
      lastHandledRemoteEtag: _preferences.getString(_lastHandledRemoteEtagKey),
      lastError: _preferences.getString(_lastErrorKey),
    );
  }

  @override
  Future<RemoteSyncPackageMeta?> fetchRemoteMeta() {
    throw UnimplementedError('Cloud sync metadata fetch is not implemented yet');
  }

  @override
  Future<void> markLocalChange({DateTime? at}) async {
    await _preferences.setInt(
      _lastLocalChangeAtKey,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> markUploadSuccess({DateTime? at}) async {
    await _preferences.setInt(
      _lastUploadedAtKey,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
    await _preferences.remove(_lastErrorKey);
  }

  @override
  Future<void> markDownloadSuccess({DateTime? at}) async {
    await _preferences.setInt(
      _lastDownloadedAtKey,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
    await _preferences.remove(_lastErrorKey);
  }

  @override
  Future<void> markHandledRemote(RemoteSyncPackageMeta meta) async {
    await _preferences.setInt(
      _lastHandledRemoteUpdatedAtKey,
      meta.updatedAt.millisecondsSinceEpoch,
    );
    if (meta.etag == null || meta.etag!.trim().isEmpty) {
      await _preferences.remove(_lastHandledRemoteEtagKey);
    } else {
      await _preferences.setString(_lastHandledRemoteEtagKey, meta.etag!.trim());
    }
  }

  @override
  Future<void> setLastError(String? error) async {
    if (error == null || error.trim().isEmpty) {
      await _preferences.remove(_lastErrorKey);
      return;
    }
    await _preferences.setString(_lastErrorKey, error.trim());
  }

  @override
  Future<void> clearConfig() async {
    await _preferences.remove(_providerTypeKey);
    await _preferences.remove(_webDavBaseUrlKey);
    await _preferences.remove(_webDavUsernameKey);
    await _preferences.remove(_webDavRemotePathKey);
    await _preferences.remove(_lastLocalChangeAtKey);
    await _preferences.remove(_lastUploadedAtKey);
    await _preferences.remove(_lastDownloadedAtKey);
    await _preferences.remove(_lastHandledRemoteUpdatedAtKey);
    await _preferences.remove(_lastHandledRemoteEtagKey);
    await _preferences.remove(_lastErrorKey);
    await _secureKeyStorage.deleteWebDavAppPassword();
  }

  DateTime? _readDateTime(String key) {
    final value = _preferences.getInt(key);
    if (value == null || value <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}
