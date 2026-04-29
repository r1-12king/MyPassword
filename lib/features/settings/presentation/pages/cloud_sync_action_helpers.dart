import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../domain/cloud_sync/cloud_sync_models.dart';
import '../../../../domain/cloud_sync/cloud_sync_provider.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';

class CloudSyncActionHelpers {
  const CloudSyncActionHelpers._();

  static Future<String?> promptForPassword(
    BuildContext context, {
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(label),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(AppLocalizations.of(context).confirmAction),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  static void showProgressDialog(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<bool> uploadToWebDav(
    BuildContext context,
    WidgetRef ref, {
    required SyncStatusSnapshot status,
    required ValueChanged<bool> setBusy,
    VoidCallback? onCompleted,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (!status.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.webDavNotConfigured)));
      return false;
    }

    final masterPassword = await promptForPassword(
      context,
      label: l10n.enterMasterPassword,
    );
    if (!context.mounted || masterPassword == null || masterPassword.isEmpty) {
      return false;
    }

    showProgressDialog(context, l10n.webDavUploadNow);
    try {
      setBusy(true);
      await ref.read(cloudSyncCoordinatorProvider).uploadCurrentVault(
            currentMasterPassword: masterPassword,
          );
      final remoteMeta = await ref.read(cloudSyncCoordinatorProvider).fetchRemoteMeta();
      if (remoteMeta != null) {
        await ref.read(cloudSyncRepositoryProvider).markHandledRemote(remoteMeta);
      }
      if (!context.mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      onCompleted?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.webDavUploadSuccess)));
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapCloudSyncError(error, l10n))));
      return false;
    } finally {
      if (context.mounted) {
        setBusy(false);
      }
    }
  }

  static Future<bool> restoreFromWebDav(
    BuildContext context,
    WidgetRef ref, {
    required SyncStatusSnapshot status,
    required ValueChanged<bool> setBusy,
    VoidCallback? onCompleted,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (!status.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.webDavNotConfigured)));
      return false;
    }

    final backupMasterPassword = await promptForPassword(
      context,
      label: l10n.backupMasterPassword,
    );
    if (!context.mounted ||
        backupMasterPassword == null ||
        backupMasterPassword.isEmpty) {
      return false;
    }

    showProgressDialog(context, l10n.webDavRestoreNow);
    try {
      setBusy(true);
      final package =
          await ref.read(cloudSyncCoordinatorProvider).downloadLatestPackage();
      if (package == null) {
        throw const CloudSyncException(CloudSyncExceptionCode.remoteFileNotFound);
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/webdav_restore.mpsync');
      await tempFile.writeAsBytes(package.bytes, flush: true);

      final passwordValid =
          await ref.read(credentialRepositoryProvider).verifyBackupPassword(
                tempFile.path,
                backupMasterPassword: backupMasterPassword,
              );
      if (!passwordValid) {
        throw const CloudSyncException(
          CloudSyncExceptionCode.invalidBackupPassword,
        );
      }

      final importedCount = await ref.read(credentialRepositoryProvider).importBackup(
            tempFile.path,
            backupMasterPassword: backupMasterPassword,
          );
      if (package.meta != null) {
        await ref.read(cloudSyncRepositoryProvider).markHandledRemote(package.meta!);
      }
      await ref.read(cloudSyncAutomationServiceProvider).notifyLocalVaultChanged();
      ref.invalidate(credentialsProvider(''));

      if (!context.mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      onCompleted?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importedCount(importedCount))));
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapCloudSyncError(error, l10n))));
      return false;
    } finally {
      if (context.mounted) {
        setBusy(false);
      }
    }
  }

  static String mapLastError(String? error, AppLocalizations l10n) {
    if (error == null || error.isEmpty) {
      return l10n.syncNoErrors;
    }
    switch (error) {
      case 'notConfigured':
        return l10n.webDavNotConfigured;
      case 'authenticationFailed':
        return l10n.webDavAuthFailed;
      case 'remoteFileNotFound':
        return l10n.webDavRemoteFileMissing;
      case 'networkError':
        return l10n.webDavNetworkError;
      case 'invalidConfiguration':
      case 'providerUnavailable':
        return l10n.webDavInvalidConfig;
      case 'invalidMasterPassword':
        return l10n.invalidCurrentMasterPassword;
      case 'invalidBackupPassword':
        return l10n.invalidBackupMasterPassword;
      default:
        return l10n.webDavActionFailed;
    }
  }

  static String mapCloudSyncError(Object error, AppLocalizations l10n) {
    if (error is CloudSyncException) {
      switch (error.code) {
        case CloudSyncExceptionCode.notConfigured:
          return l10n.webDavNotConfigured;
        case CloudSyncExceptionCode.authenticationFailed:
          return l10n.webDavAuthFailed;
        case CloudSyncExceptionCode.remoteFileNotFound:
          return l10n.webDavRemoteFileMissing;
        case CloudSyncExceptionCode.networkError:
          return l10n.webDavNetworkError;
        case CloudSyncExceptionCode.invalidConfiguration:
        case CloudSyncExceptionCode.providerUnavailable:
          return l10n.webDavInvalidConfig;
        case CloudSyncExceptionCode.invalidMasterPassword:
          return l10n.invalidCurrentMasterPassword;
        case CloudSyncExceptionCode.invalidBackupPassword:
          return l10n.invalidBackupMasterPassword;
        case CloudSyncExceptionCode.unknown:
          break;
      }
    }
    return l10n.webDavActionFailed;
  }

  static String formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '-';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
