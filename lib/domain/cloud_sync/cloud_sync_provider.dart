enum CloudSyncProviderType {
  webdav,
  baiduPan,
}

enum CloudSyncExceptionCode {
  notConfigured,
  providerUnavailable,
  authenticationFailed,
  remoteFileNotFound,
  networkError,
  invalidConfiguration,
  invalidMasterPassword,
  invalidBackupPassword,
  unknown,
}

class CloudSyncException implements Exception {
  const CloudSyncException(
    this.code, {
    this.message,
  });

  final CloudSyncExceptionCode code;
  final String? message;

  @override
  String toString() => message ?? code.name;
}

class RemoteSyncPackageMeta {
  const RemoteSyncPackageMeta({
    required this.path,
    required this.updatedAt,
    this.etag,
    this.sizeBytes,
  });

  final String path;
  final DateTime updatedAt;
  final String? etag;
  final int? sizeBytes;
}

class SyncPackageUpload {
  const SyncPackageUpload({
    required this.path,
    required this.bytes,
    this.contentType = 'application/octet-stream',
  });

  final String path;
  final List<int> bytes;
  final String contentType;
}

class DownloadedSyncPackage {
  const DownloadedSyncPackage({
    required this.path,
    required this.bytes,
    this.meta,
  });

  final String path;
  final List<int> bytes;
  final RemoteSyncPackageMeta? meta;
}

abstract class CloudSyncProvider {
  CloudSyncProviderType get providerType;
  String get displayName;

  Future<bool> isConfigured();
  Future<void> validateConnection();
  Future<RemoteSyncPackageMeta?> getRemoteMeta();
  Future<void> uploadPackage(SyncPackageUpload upload);
  Future<DownloadedSyncPackage?> downloadPackage(String path);
  Future<void> deletePackage(String path);
}
