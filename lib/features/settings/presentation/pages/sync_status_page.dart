import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../domain/cloud_sync/cloud_sync_automation_service.dart';
import '../../../../domain/cloud_sync/cloud_sync_models.dart';
import '../../../../domain/cloud_sync/cloud_sync_provider.dart';
import '../../../../shared/providers/app_providers.dart';
import 'cloud_sync_action_helpers.dart';

class SyncStatusPage extends ConsumerStatefulWidget {
  const SyncStatusPage({super.key});

  @override
  ConsumerState<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends ConsumerState<SyncStatusPage> {
  bool _actionInProgress = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appSettings = ref.watch(appSettingsControllerProvider);
    final snapshotAsync = ref.watch(_syncStatusSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncStatus),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(_syncStatusSnapshotProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          final status = snapshot.status;
          final remoteMeta = snapshot.remoteMeta;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: l10n.syncOverview,
                children: [
                  _StatusRow(label: l10n.syncType, value: 'WebDAV'),
                  _StatusRow(
                    label: l10n.syncConfigurationStatus,
                    value: status.isConfigured
                        ? l10n.syncConfigured
                        : l10n.syncNotConfigured,
                  ),
                  _StatusRow(
                    label: l10n.webDavRemotePath,
                    value: snapshot.config?.remotePath ?? '-',
                  ),
                  _StatusRow(
                    label: l10n.autoSyncOnChange,
                    value: appSettings.autoSyncOnChange
                        ? l10n.syncEnabled
                        : l10n.syncDisabled,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.alertType != RemoteSyncAlertType.none)
                _AlertCard(alertType: snapshot.alertType),
              if (snapshot.alertType != RemoteSyncAlertType.none)
                const SizedBox(height: 16),
              _SectionCard(
                title: l10n.syncRecentActivity,
                children: [
                  _StatusRow(
                    label: l10n.syncLastLocalChange,
                    value: CloudSyncActionHelpers.formatDateTime(
                      status.lastLocalChangeAt,
                    ),
                  ),
                  _StatusRow(
                    label: l10n.syncLastUpload,
                    value: CloudSyncActionHelpers.formatDateTime(
                      status.lastUploadedAt,
                    ),
                  ),
                  _StatusRow(
                    label: l10n.syncLastRestore,
                    value: CloudSyncActionHelpers.formatDateTime(
                      status.lastDownloadedAt,
                    ),
                  ),
                  _StatusRow(
                    label: l10n.syncLastError,
                    value: CloudSyncActionHelpers.mapLastError(
                      status.lastError,
                      l10n,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: l10n.syncRemoteStatus,
                children: [
                  _StatusRow(
                    label: l10n.syncRemotePackage,
                    value: remoteMeta == null
                        ? l10n.webDavRemoteFileMissing
                        : l10n.syncRemotePackageExists,
                  ),
                  _StatusRow(
                    label: l10n.syncRemoteUpdatedAt,
                    value: CloudSyncActionHelpers.formatDateTime(
                      remoteMeta?.updatedAt,
                    ),
                  ),
                  _StatusRow(
                    label: l10n.syncRemoteFileSize,
                    value: CloudSyncActionHelpers.formatSize(
                      remoteMeta?.sizeBytes,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: l10n.syncActions,
                children: [
                  FilledButton(
                    onPressed: _actionInProgress
                        ? null
                        : () => _uploadToWebDav(snapshot.status),
                    child: Text(l10n.webDavUploadNow),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _actionInProgress
                        ? null
                        : () => _restoreFromWebDav(snapshot.status),
                    child: Text(l10n.webDavRestoreNow),
                  ),
                ],
              ),
            ],
          );
        },
        error: (_, __) => Center(child: Text(l10n.webDavActionFailed)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _uploadToWebDav(SyncStatusSnapshot status) async {
    await CloudSyncActionHelpers.uploadToWebDav(
      context,
      ref,
      status: status,
      setBusy: (busy) => setState(() => _actionInProgress = busy),
      onCompleted: () => ref.invalidate(_syncStatusSnapshotProvider),
    );
  }

  Future<void> _restoreFromWebDav(SyncStatusSnapshot status) async {
    await CloudSyncActionHelpers.restoreFromWebDav(
      context,
      ref,
      status: status,
      setBusy: (busy) => setState(() => _actionInProgress = busy),
      onCompleted: () => ref.invalidate(_syncStatusSnapshotProvider),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

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
          ...children,
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
          Expanded(
            flex: 4,
            child: Text(label),
          ),
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alertType,
  });

  final RemoteSyncAlertType alertType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final text = alertType == RemoteSyncAlertType.syncConflict
        ? l10n.remoteSyncConflict
        : l10n.remoteSyncUpdateAvailable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(color: colorScheme.onTertiaryContainer),
          ),
          if (alertType == RemoteSyncAlertType.syncConflict) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.push(RouteNames.syncConflict),
              child: Text(l10n.syncConflictTitle),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncStatusPageSnapshot {
  const _SyncStatusPageSnapshot({
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

final _syncStatusSnapshotProvider =
    FutureProvider<_SyncStatusPageSnapshot>((ref) async {
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

      return _SyncStatusPageSnapshot(
        status: status,
        config: config,
        remoteMeta: remoteMeta,
        alertType: alertType,
      );
    });
