import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/export/export_directory_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../shared/providers/app_providers.dart';

class ExportBackupPage extends ConsumerStatefulWidget {
  const ExportBackupPage({super.key});

  @override
  ConsumerState<ExportBackupPage> createState() => _ExportBackupPageState();
}

class _ExportBackupPageState extends ConsumerState<ExportBackupPage> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _path;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportBackup)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.exportBackupDesc),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.currentMasterPassword,
              ),
            ),
            if (settings.exportDirectoryLabel != null) ...[
              const SizedBox(height: 8),
              Text(l10n.exportDirectory),
              SelectableText(settings.exportDirectoryLabel!),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _export,
              child: Text(_loading ? l10n.exporting : l10n.exportBackupAction),
            ),
            if (_path != null) ...[
              const SizedBox(height: 16),
              Text(l10n.backupCreatedAt),
              SelectableText(_path!),
              const SizedBox(height: 8),
              Text(l10n.backupEncryptedNotice),
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

  Future<void> _export() async {
    final currentMasterPassword = _passwordController.text.trim();
    if (currentMasterPassword.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context).masterPasswordRequired;
      });
      return;
    }
    final exportDirectoryUri =
        ref.read(appSettingsControllerProvider).exportDirectoryUri;
    if (exportDirectoryUri == null || exportDirectoryUri.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context).exportDirectoryRequired;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _path = null;
    });

    try {
      final exportData =
          await ref.read(credentialRepositoryProvider).exportBackup(
            currentMasterPassword: currentMasterPassword,
          );
      final path = await ref.read(exportDirectoryServiceProvider).writeBackupFile(
            directoryUri: exportDirectoryUri,
            fileName: exportData.fileName,
            bytes: Uint8List.fromList(exportData.bytes),
          );
      if (!mounted) return;
      setState(() => _path = path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).unableToExportBackup);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
