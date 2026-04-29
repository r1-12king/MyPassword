import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/providers/app_providers.dart';

class ChangeMasterPasswordPage extends ConsumerStatefulWidget {
  const ChangeMasterPasswordPage({super.key});

  @override
  ConsumerState<ChangeMasterPasswordPage> createState() =>
      _ChangeMasterPasswordPageState();
}

class _ChangeMasterPasswordPageState
    extends ConsumerState<ChangeMasterPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changeMasterPassword)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.currentMasterPassword),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.masterPasswordRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.newMasterPassword),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.masterPasswordRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.confirmNewMasterPassword,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.masterPasswordRequired;
                }
                if (value != _newPasswordController.text) {
                  return l10n.masterPasswordMismatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? l10n.saving : l10n.save),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(vaultRepositoryProvider).changeMasterPassword(
            currentMasterPassword: _currentPasswordController.text.trim(),
            newMasterPassword: _newPasswordController.text.trim(),
          );
      ref
          .read(vaultSessionControllerProvider.notifier)
          .setMasterPassword(_newPasswordController.text);
      await ref.read(cloudSyncAutomationServiceProvider).notifyLocalVaultChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.masterPasswordUpdated)),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.unableToChangeMasterPassword);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
