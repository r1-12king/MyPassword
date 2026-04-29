import 'cloud_sync_provider.dart';

class WebDavConfig {
  const WebDavConfig({
    required this.baseUrl,
    required this.username,
    required this.appPassword,
    this.remotePath = '/MyPassword/vault_sync.mpsync',
  });

  final String baseUrl;
  final String username;
  final String appPassword;
  final String remotePath;
}

class CloudSyncConfig {
  const CloudSyncConfig({
    required this.providerType,
    required this.remotePath,
    this.webDavConfig,
  });

  final CloudSyncProviderType providerType;
  final String remotePath;
  final WebDavConfig? webDavConfig;

  bool get isValid {
    switch (providerType) {
      case CloudSyncProviderType.webdav:
        final config = webDavConfig;
        return config != null &&
            config.baseUrl.trim().isNotEmpty &&
            config.username.trim().isNotEmpty &&
            config.appPassword.trim().isNotEmpty;
      case CloudSyncProviderType.baiduPan:
        return false;
    }
  }
}

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.isConfigured,
    this.lastRemoteMeta,
    this.lastLocalChangeAt,
    this.lastUploadedAt,
    this.lastDownloadedAt,
    this.lastHandledRemoteUpdatedAt,
    this.lastHandledRemoteEtag,
    this.lastError,
  });

  final bool isConfigured;
  final RemoteSyncPackageMeta? lastRemoteMeta;
  final DateTime? lastLocalChangeAt;
  final DateTime? lastUploadedAt;
  final DateTime? lastDownloadedAt;
  final DateTime? lastHandledRemoteUpdatedAt;
  final String? lastHandledRemoteEtag;
  final String? lastError;
}
