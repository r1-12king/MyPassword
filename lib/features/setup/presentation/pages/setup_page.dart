import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/providers/app_providers.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _enableBiometricUnlock = false;
  bool _canUseBiometrics = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBiometricState);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createVault)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.masterPassword,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enableBiometricUnlock),
              value: _enableBiometricUnlock && _canUseBiometrics,
              onChanged: !_canUseBiometrics || _loading
                  ? null
                  : (value) {
                      setState(() => _enableBiometricUnlock = value);
                    },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(
                _loading ? l10n.creating : l10n.createVaultAction,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () => context.push(RouteNames.importBackup),
              child: Text(l10n.importBackup),
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
    final password = _controller.text.trim();
    if (password.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).masterPasswordRequired);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(vaultRepositoryProvider).createVault(
            masterPassword: password,
            enableBiometricUnlock: _enableBiometricUnlock && _canUseBiometrics,
          );
      ref.read(vaultSessionControllerProvider.notifier).setMasterPassword(password);
      if (!mounted) return;
      context.go(RouteNames.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).unableToCreateVault);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadBiometricState() async {
    final canUse =
        await ref.read(biometricServiceProvider).canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _canUseBiometrics = canUse;
      if (!canUse) {
        _enableBiometricUnlock = false;
      }
    });
  }
}
