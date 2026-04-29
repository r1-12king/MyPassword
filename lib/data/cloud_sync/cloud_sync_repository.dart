import '../../domain/cloud_sync/cloud_sync_models.dart';
import '../../domain/cloud_sync/cloud_sync_provider.dart';

abstract class CloudSyncRepository {
  Future<CloudSyncConfig?> getCurrentConfig();
  Future<void> saveWebDavConfig(WebDavConfig config);
  Future<SyncStatusSnapshot> getStatus();
  Future<RemoteSyncPackageMeta?> fetchRemoteMeta();
  Future<void> markLocalChange({DateTime? at});
  Future<void> markUploadSuccess({DateTime? at});
  Future<void> markDownloadSuccess({DateTime? at});
  Future<void> markHandledRemote(RemoteSyncPackageMeta meta);
  Future<void> setLastError(String? error);
  Future<void> clearConfig();
}
