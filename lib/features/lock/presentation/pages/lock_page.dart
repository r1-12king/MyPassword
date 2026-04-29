import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/providers/app_providers.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _showBiometricUnlock = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
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
      appBar: AppBar(title: Text(l10n.unlockVault)),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _unlock,
              child: Text(_loading ? l10n.unlocking : l10n.unlock),
            ),
            if (_showBiometricUnlock) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _unlockWithBiometrics,
                child: Text(l10n.useBiometrics),
              ),
            ],
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

  Future<void> _bootstrap() async {
    final vaultRepository = ref.read(vaultRepositoryProvider);
    final hasVault = await vaultRepository.hasVault();
    if (!mounted) return;

    if (!hasVault) {
      context.go(RouteNames.setup);
      return;
    }

    final showBiometrics = await vaultRepository.canUnlockWithBiometrics();
    if (!mounted) return;
    setState(() => _showBiometricUnlock = showBiometrics);
  }

  Future<void> _unlock() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await ref.read(vaultRepositoryProvider).unlockVault(
            masterPassword: _controller.text,
          );
      if (!mounted) return;

      if (success) {
        ref
            .read(vaultSessionControllerProvider.notifier)
            .setMasterPassword(_controller.text);
        context.go(RouteNames.home);
      } else {
        setState(() => _error = l10n.unableToUnlockVault);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final biometricService = ref.read(biometricServiceProvider);
      final vaultRepository = ref.read(vaultRepositoryProvider);
      final enabled = await vaultRepository.canUnlockWithBiometrics();

      if (!enabled) {
        setState(() => _error = l10n.biometricUnlockNotEnabled);
        return;
      }

      final canUse = await biometricService.canUseBiometrics();

      if (!canUse) {
        setState(() => _error = l10n.biometricsUnavailable);
        return;
      }

      final authenticated = await biometricService.authenticate(
        localizedReason: l10n.unlockVault,
      );
      if (!authenticated) {
        setState(() => _error = l10n.biometricAuthenticationFailed);
        return;
      }

      final success = await vaultRepository.unlockWithBiometrics();
      if (!mounted) return;

      if (success) {
        ref.read(vaultSessionControllerProvider.notifier).clear();
        context.go(RouteNames.home);
      } else {
        setState(() => _error = l10n.biometricUnlockUnavailable);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
