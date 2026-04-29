import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/export/export_directory_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';

class ImportBackupPage extends ConsumerStatefulWidget {
  const ImportBackupPage({super.key});

  @override
  ConsumerState<ImportBackupPage> createState() => _ImportBackupPageState();
}

class _ImportBackupPageState extends ConsumerState<ImportBackupPage> {
  final _backupMasterPasswordController = TextEditingController();
  final _masterPasswordController = TextEditingController();
  bool _loading = false;
  String? _selectedFilePath;
  String? _selectedFileLabel;
  String? _message;
  String? _error;
  bool? _hasVault;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadVaultState);
  }

  @override
  void dispose() {
    _backupMasterPasswordController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasVault = _hasVault ?? true;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importBackup)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.importBackupDesc),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loading ? null : _chooseBackupFile,
              child: Text(l10n.chooseBackupFile),
            ),
            if (_selectedFilePath != null) ...[
              const SizedBox(height: 8),
              Text(l10n.selectedBackupFile),
              SelectableText(_selectedFileLabel ?? _selectedFilePath!),
              const SizedBox(height: 16),
              TextField(
                controller: _backupMasterPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.backupMasterPassword,
                ),
              ),
            ],
            if (!hasVault) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _masterPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.masterPassword,
                  helperText: l10n.createVault,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _import,
              child: Text(_loading ? l10n.importing : l10n.startImport),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final backupMasterPassword = _backupMasterPasswordController.text.trim();
    final hasVault = _hasVault ?? true;
    if (_selectedFilePath == null || _selectedFilePath!.isEmpty) {
      setState(() => _error = l10n.chooseBackupFileFirst);
      return;
    }
    if (backupMasterPassword.isEmpty) {
      setState(() => _error = l10n.masterPasswordRequired);
      return;
    }
    if (!hasVault && _masterPasswordController.text.trim().isEmpty) {
      setState(() => _error = l10n.masterPasswordRequired);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final backupPasswordValid = await ref
          .read(credentialRepositoryProvider)
          .verifyBackupPassword(
            _selectedFilePath!,
            backupMasterPassword: backupMasterPassword,
          );
      if (!backupPasswordValid) {
        if (!mounted) return;
        setState(() => _error = l10n.invalidBackupMasterPassword);
        return;
      }

      if (!hasVault) {
        await ref.read(vaultRepositoryProvider).createVault(
              masterPassword: _masterPasswordController.text.trim(),
            );
        ref
            .read(vaultSessionControllerProvider.notifier)
            .setMasterPassword(_masterPasswordController.text);
        _hasVault = true;
      }

      final importedCount = await ref
          .read(credentialRepositoryProvider)
          .importBackup(
            _selectedFilePath!,
            backupMasterPassword: backupMasterPassword,
          );
      await ref.read(cloudSyncAutomationServiceProvider).notifyLocalVaultChanged();
      ref.invalidate(credentialsProvider(''));
      if (!mounted) return;
      setState(() => _message = l10n.importedCount(importedCount));
      context.go(RouteNames.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.unableToImportBackup);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _chooseBackupFile() async {
    final result = await ref.read(exportDirectoryServiceProvider).pickBackupFile();

    if (!mounted) return;

    final path = result?.path;
    if (path == null || path.isEmpty) {
      setState(() => _message = AppLocalizations.of(context).importCancelled);
      return;
    }

    setState(() {
      _selectedFilePath = path;
      _selectedFileLabel = result?.label;
      _error = null;
      _message = null;
    });
  }

  Future<void> _loadVaultState() async {
    final hasVault = await ref.read(vaultRepositoryProvider).hasVault();
    if (!mounted) return;
    setState(() => _hasVault = hasVault);
  }
}
