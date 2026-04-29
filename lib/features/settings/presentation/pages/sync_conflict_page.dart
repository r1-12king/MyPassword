import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../domain/cloud_sync/cloud_sync_automation_service.dart';
import '../../../../domain/cloud_sync/cloud_sync_models.dart';
import '../../../../domain/cloud_sync/cloud_sync_provider.dart';
import '../../../../shared/providers/app_providers.dart';
import 'cloud_sync_action_helpers.dart';

class SyncConflictPage extends ConsumerStatefulWidget {
  const SyncConflictPage({super.key});

  @override
  ConsumerState<SyncConflictPage> createState() => _SyncConflictPageState();
}

class _SyncConflictPageState extends ConsumerState<SyncConflictPage> {
  bool _actionInProgress = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshotAsync = ref.watch(_syncConflictSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncConflictTitle)),
      body: snapshotAsync.when(
        data: (snapshot) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(
                title: l10n.syncConflictTitle,
                child: Text(
                  snapshot.alertType == RemoteSyncAlertType.syncConflict
                      ? l10n.syncConflictDescription
                      : l10n.syncConflictNoLongerExists,
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: l10n.syncConflictLocalSide,
                child: Column(
                  children: [
                    _StatusRow(
                      label: l10n.syncLastLocalChange,
                      value: CloudSyncActionHelpers.formatDateTime(
                        snapshot.status.lastLocalChangeAt,
                      ),
                    ),
                    _StatusRow(
                      label: l10n.syncLastUpload,
                      value: CloudSyncActionHelpers.formatDateTime(
                        snapshot.status.lastUploadedAt,
                      ),
                    ),
                    _StatusRow(
                      label: l10n.syncLastError,
                      value: CloudSyncActionHelpers.mapLastError(
                        snapshot.status.lastError,
                        l10n,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: l10n.syncConflictRemoteSide,
                child: Column(
                  children: [
                    _StatusRow(
                      label: l10n.syncRemoteUpdatedAt,
                      value: CloudSyncActionHelpers.formatDateTime(
                        snapshot.remoteMeta?.updatedAt,
                      ),
                    ),
                    _StatusRow(
                      label: l10n.syncRemoteFileSize,
                      value: CloudSyncActionHelpers.formatSize(
                        snapshot.remoteMeta?.sizeBytes,
                      ),
                    ),
                    _StatusRow(
                      label: l10n.webDavRemotePath,
                      value: snapshot.config?.remotePath ?? '-',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: l10n.syncConflictHowToHandle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.syncConflictKeepLocalHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _actionInProgress || !snapshot.status.isConfigured
                          ? null
                          : () => _keepLocal(snapshot.status),
                      child: Text(l10n.syncConflictKeepLocalAction),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.syncConflictKeepRemoteHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _actionInProgress || !snapshot.status.isConfigured
                          ? null
                          : () => _keepRemote(snapshot.status),
                      child: Text(l10n.syncConflictKeepRemoteAction),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _actionInProgress
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.syncConflictHandleLater),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        error: (_, __) => Center(child: Text(l10n.webDavActionFailed)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _keepLocal(SyncStatusSnapshot status) async {
    final success = await CloudSyncActionHelpers.uploadToWebDav(
      context,
      ref,
      status: status,
      setBusy: (busy) => setState(() => _actionInProgress = busy),
      onCompleted: () => ref.invalidate(_syncConflictSnapshotProvider),
    );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _keepRemote(SyncStatusSnapshot status) async {
    final success = await CloudSyncActionHelpers.restoreFromWebDav(
      context,
      ref,
      status: status,
      setBusy: (busy) => setState(() => _actionInProgress = busy),
      onCompleted: () => ref.invalidate(_syncConflictSnapshotProvider),
    );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label)),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncConflictSnapshot {
  const _SyncConflictSnapshot({
    required this.status,
    required this.config,
    required this.remoteMeta,
    required this.alertType,
  });

  final SyncStatusSnapshot status;
  final CloudSyncConfig? config;
  final RemoteSyncPackageMeta? remoteMeta;
  final RemoteSyncAlertType alertType;
}

final _syncConflictSnapshotProvider =
    FutureProvider<_SyncConflictSnapshot>((ref) async {
      final coordinator = ref.read(cloudSyncCoordinatorProvider);
      final repository = ref.read(cloudSyncRepositoryProvider);

      final status = await coordinator.getStatus();
      final config = await repository.getCurrentConfig();

      RemoteSyncPackageMeta? remoteMeta;
      RemoteSyncAlertType alertType = RemoteSyncAlertType.none;

      if (status.isConfigured) {
        try {
          remoteMeta = await coordinator.fetchRemoteMeta();
        } catch (_) {}
        try {
          final alert = await ref
              .read(cloudSyncAutomationServiceProvider)
              .checkRemoteAlert();
          alertType = alert.type;
        } catch (_) {}
      }

      return _SyncConflictSnapshot(
        status: status,
        config: config,
        remoteMeta: remoteMeta,
        alertType: alertType,
      );
    });
