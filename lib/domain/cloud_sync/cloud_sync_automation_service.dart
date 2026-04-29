import '../../core/settings/app_settings_controller.dart';
import 'cloud_sync_coordinator.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_provider.dart';

enum RemoteSyncAlertType {
  none,
  remoteUpdateAvailable,
  syncConflict,
}

class RemoteSyncAlert {
  const RemoteSyncAlert({
    required this.type,
    this.remoteMeta,
  });

  final RemoteSyncAlertType type;
  final RemoteSyncPackageMeta? remoteMeta;

  bool get shouldShow => type != RemoteSyncAlertType.none;
}

abstract class CloudSyncAutomationService {
  Future<void> notifyLocalVaultChanged();
  Future<RemoteSyncAlert> checkRemoteAlert();
}

class CloudSyncAutomationServiceImpl implements CloudSyncAutomationService {
  CloudSyncAutomationServiceImpl({
    required CloudSyncCoordinator cloudSyncCoordinator,
    required Future<SyncStatusSnapshot> Function() loadStatus,
    required Future<void> Function({DateTime? at}) markLocalChange,
    required AppSettingsState Function() readSettings,
    required String? Function() readSessionMasterPassword,
  })  : _cloudSyncCoordinator = cloudSyncCoordinator,
        _loadStatus = loadStatus,
        _markLocalChange = markLocalChange,
        _readSettings = readSettings,
        _readSessionMasterPassword = readSessionMasterPassword;

  final CloudSyncCoordinator _cloudSyncCoordinator;
  final Future<SyncStatusSnapshot> Function() _loadStatus;
  final Future<void> Function({DateTime? at}) _markLocalChange;
  final AppSettingsState Function() _readSettings;
  final String? Function() _readSessionMasterPassword;

  @override
  Future<void> notifyLocalVaultChanged() async {
    final now = DateTime.now();
    await _markLocalChange(at: now);

    final settings = _readSettings();
    if (!settings.autoSyncOnChange) {
      return;
    }

    final sessionMasterPassword = _readSessionMasterPassword();
    if (sessionMasterPassword == null || sessionMasterPassword.trim().isEmpty) {
      return;
    }

    try {
      await _cloudSyncCoordinator.uploadCurrentVault(
        currentMasterPassword: sessionMasterPassword,
      );
    } catch (_) {
      // Local changes should still succeed even if background sync fails.
    }
  }

  @override
  Future<RemoteSyncAlert> checkRemoteAlert() async {
    final status = await _loadStatus();
    if (!status.isConfigured) {
      return const RemoteSyncAlert(type: RemoteSyncAlertType.none);
    }

    final remoteMeta = await _cloudSyncCoordinator.fetchRemoteMeta();
    if (remoteMeta == null) {
      return const RemoteSyncAlert(type: RemoteSyncAlertType.none);
    }
    if (_isRemoteAlreadyHandled(status, remoteMeta)) {
      return const RemoteSyncAlert(type: RemoteSyncAlertType.none);
    }

    final lastSyncAt = _latest(status.lastUploadedAt, status.lastDownloadedAt);
    final hasRemoteUpdate = lastSyncAt == null || remoteMeta.updatedAt.isAfter(lastSyncAt);
    if (!hasRemoteUpdate) {
      return const RemoteSyncAlert(type: RemoteSyncAlertType.none);
    }

    final hasUnsyncedLocalChanges = status.lastLocalChangeAt != null &&
        (status.lastUploadedAt == null ||
            status.lastLocalChangeAt!.isAfter(status.lastUploadedAt!));

    if (hasUnsyncedLocalChanges) {
      return RemoteSyncAlert(
        type: RemoteSyncAlertType.syncConflict,
        remoteMeta: remoteMeta,
      );
    }

    return RemoteSyncAlert(
      type: RemoteSyncAlertType.remoteUpdateAvailable,
      remoteMeta: remoteMeta,
    );
  }

  DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  bool _isRemoteAlreadyHandled(
    SyncStatusSnapshot status,
    RemoteSyncPackageMeta remoteMeta,
  ) {
    final handledEtag = status.lastHandledRemoteEtag?.trim();
    final remoteEtag = remoteMeta.etag?.trim();
    if (handledEtag != null &&
        handledEtag.isNotEmpty &&
        remoteEtag != null &&
        remoteEtag.isNotEmpty &&
        handledEtag == remoteEtag) {
      return true;
    }

    final handledUpdatedAt = status.lastHandledRemoteUpdatedAt;
    if (handledUpdatedAt == null) {
      return false;
    }
    return !remoteMeta.updatedAt.isAfter(handledUpdatedAt);
  }
}
