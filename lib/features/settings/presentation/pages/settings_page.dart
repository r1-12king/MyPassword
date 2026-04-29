import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/export/export_directory_service.dart';
import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../domain/cloud_sync/cloud_sync_provider.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loadingBiometrics = true;
  bool _canUseBiometrics = false;
  bool _biometricUnlockEnabled = false;
  bool _syncActionInProgress = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBiometricState);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appLocaleControllerProvider);
    final localeController = ref.read(appLocaleControllerProvider.notifier);
    final appSettings = ref.watch(appSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ExpansionTile(
            title: Text(l10n.localBackup),
            children: [
              ListTile(
                title: Text(l10n.exportDirectory),
                subtitle: Text(
                  appSettings.exportDirectoryLabel ?? l10n.exportDirectoryNotSet,
                ),
                onTap: _selectExportDirectory,
              ),
              ListTile(
                title: Text(l10n.exportBackup),
                onTap: () => context.push(RouteNames.exportBackup),
              ),
              ListTile(
                title: Text(l10n.importBackup),
                onTap: () => context.push(RouteNames.importBackup),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(l10n.webDavSync),
            children: [
              ListTile(
                title: Text(l10n.webDavGuide),
                subtitle: Text(l10n.webDavGuideDesc),
                onTap: () => context.push(RouteNames.webDavGuide),
              ),
              ListTile(
                title: Text(l10n.webDavSyncConfig),
                subtitle: Text(l10n.webDavSyncDescShort),
                onTap: () => context.push(RouteNames.webDavSync),
              ),
              ListTile(
                title: Text(l10n.syncStatus),
                subtitle: Text(l10n.syncStatusDesc),
                onTap: () => context.push(RouteNames.syncStatus),
              ),
              ListTile(
                title: Text(l10n.webDavUploadNow),
                enabled: !_syncActionInProgress,
                onTap: _syncActionInProgress ? null : _uploadToWebDav,
              ),
              ListTile(
                title: Text(l10n.webDavRestoreNow),
                enabled: !_syncActionInProgress,
                onTap: _syncActionInProgress ? null : _restoreFromWebDav,
              ),
            ],
          ),
          ListTile(
            title: Text(l10n.changeMasterPassword),
            onTap: () => context.push(RouteNames.changeMasterPassword),
          ),
          ListTile(
            title: Text(l10n.language),
            subtitle: Text(
              locale == null
                  ? l10n.languageSystem
                  : locale.languageCode == 'zh'
                      ? l10n.languageChinese
                      : l10n.languageEnglish,
            ),
            onTap: () => _showLanguageSheet(context, localeController, l10n),
          ),
          SwitchListTile(
            title: Text(l10n.autoSyncOnChange),
            subtitle: Text(l10n.autoSyncOnChangeDesc),
            value: appSettings.autoSyncOnChange,
            onChanged: (value) async {
              await ref
                  .read(appSettingsControllerProvider.notifier)
                  .setAutoSyncOnChange(value);
            },
          ),
          ListTile(
            title: Text(l10n.vaultLockTiming),
            subtitle: Text(
              appSettings.vaultLockMode == VaultLockMode.onBackground
                  ? l10n.lockWhenAppBackgrounded
                  : l10n.lockWhenAppExit,
            ),
            onTap: () => _showVaultLockModeSheet(context, l10n),
          ),
          if (appSettings.vaultLockMode == VaultLockMode.onAppExit)
            ListTile(
              title: Text(l10n.lockVaultNow),
              onTap: () async {
                await ref.read(vaultRepositoryProvider).lockVault();
                ref.read(vaultSessionControllerProvider.notifier).clear();
                if (!context.mounted) return;
                context.go(RouteNames.lock);
              },
            ),
          SwitchListTile(
            title: Text(l10n.enableBiometricUnlock),
            subtitle: Text(
              !_canUseBiometrics
                  ? l10n.biometricsUnavailable
                  : _biometricUnlockEnabled
                      ? l10n.biometricUnlockEnabled
                      : l10n.biometricUnlockNotEnabled,
            ),
            value: _biometricUnlockEnabled,
            onChanged: _loadingBiometrics || !_canUseBiometrics
                ? null
                : _toggleBiometricUnlock,
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageSheet(
    BuildContext context,
    AppLocaleController controller,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.languageSystem),
                onTap: () async {
                  await controller.useSystem();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text(l10n.languageEnglish),
                onTap: () async {
                  await controller.setEnglish();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text(l10n.languageChinese),
                onTap: () async {
                  await controller.setChinese();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadBiometricState() async {
    final biometricService = ref.read(biometricServiceProvider);
    final vaultRepository = ref.read(vaultRepositoryProvider);
    final canUse = await biometricService.canUseBiometrics();
    final enabled = canUse
        ? await vaultRepository.canUnlockWithBiometrics()
        : false;
    if (!mounted) return;
    setState(() {
      _canUseBiometrics = canUse;
      _biometricUnlockEnabled = enabled;
      _loadingBiometrics = false;
    });
  }

  Future<void> _toggleBiometricUnlock(bool value) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loadingBiometrics = true);

    try {
      final vaultRepository = ref.read(vaultRepositoryProvider);
      if (value) {
        await vaultRepository.enableBiometricUnlock();
      } else {
        await vaultRepository.disableBiometricUnlock();
      }

      if (!mounted) return;
      setState(() => _biometricUnlockEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? l10n.biometricUnlockEnabled
                : l10n.biometricUnlockDisabled,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.biometricUnlockEnableFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingBiometrics = false);
      }
    }
  }

  Future<void> _selectExportDirectory() async {
    final selection = await ref.read(exportDirectoryServiceProvider).pickDirectory();
    if (!mounted) return;

    if (selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).exportCancelled)),
      );
      return;
    }

    await ref.read(appSettingsControllerProvider.notifier).setExportDirectory(
          uri: selection.uri,
          label: selection.label,
        );
  }

  Future<void> _showVaultLockModeSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final current = ref.read(appSettingsControllerProvider).vaultLockMode;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.lockWhenAppBackgrounded),
                trailing: current == VaultLockMode.onBackground
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  await controller.setVaultLockMode(VaultLockMode.onBackground);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text(l10n.lockWhenAppExit),
                trailing: current == VaultLockMode.onAppExit
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  await controller.setVaultLockMode(VaultLockMode.onAppExit);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadToWebDav() async {
    final l10n = AppLocalizations.of(context);
    final status = await ref.read(cloudSyncCoordinatorProvider).getStatus();
    if (!status.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.webDavNotConfigured)),
      );
      return;
    }

    final masterPassword = await _promptForPassword(l10n.enterMasterPassword);
    if (!mounted || masterPassword == null || masterPassword.isEmpty) return;

    _showSyncProgress(l10n.webDavUploadNow);

    try {
      setState(() => _syncActionInProgress = true);
      await ref.read(cloudSyncCoordinatorProvider).uploadCurrentVault(
            currentMasterPassword: masterPassword,
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.webDavUploadSuccess)),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapCloudSyncError(error, l10n))),
      );
    } finally {
      if (mounted) {
        setState(() => _syncActionInProgress = false);
      }
    }
  }

  Future<void> _restoreFromWebDav() async {
    final l10n = AppLocalizations.of(context);
    final status = await ref.read(cloudSyncCoordinatorProvider).getStatus();
    if (!status.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.webDavNotConfigured)),
      );
      return;
    }

    final backupMasterPassword =
        await _promptForPassword(l10n.backupMasterPassword);
    if (!mounted ||
        backupMasterPassword == null ||
        backupMasterPassword.isEmpty) {
      return;
    }

    _showSyncProgress(l10n.webDavRestoreNow);

    try {
      setState(() => _syncActionInProgress = true);
      final package =
          await ref.read(cloudSyncCoordinatorProvider).downloadLatestPackage();
      if (package == null) {
        throw const CloudSyncException(
          CloudSyncExceptionCode.remoteFileNotFound,
        );
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
      ref.invalidate(credentialsProvider(''));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importedCount(importedCount))),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapCloudSyncError(error, l10n))),
      );
    } finally {
      if (mounted) {
        setState(() => _syncActionInProgress = false);
      }
    }
  }

  void _showSyncProgress(String label) {
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

  Future<String?> _promptForPassword(String label) async {
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

  String _mapCloudSyncError(Object error, AppLocalizations l10n) {
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
}
