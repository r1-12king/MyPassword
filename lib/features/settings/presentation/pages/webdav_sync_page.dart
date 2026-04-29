import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../data/cloud_sync/providers/webdav/webdav_sync_provider.dart';
import '../../../../domain/cloud_sync/cloud_sync_models.dart';
import '../../../../domain/cloud_sync/cloud_sync_provider.dart';
import '../../../../shared/providers/app_providers.dart';

class WebDavSyncPage extends ConsumerStatefulWidget {
  const WebDavSyncPage({super.key});

  @override
  ConsumerState<WebDavSyncPage> createState() => _WebDavSyncPageState();
}

class _WebDavSyncPageState extends ConsumerState<WebDavSyncPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _remotePathController = TextEditingController(
    text: '/MyPassword/vault_sync.mpsync',
  );
  bool _loading = false;
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remotePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configAsync = ref.watch(_webDavConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.webDavSync)),
      body: configAsync.when(
        data: (config) {
          _initialize(config);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.webDavSyncDesc,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _baseUrlController,
                  decoration: InputDecoration(labelText: l10n.webDavBaseUrl),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.webDavBaseUrlRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: l10n.webDavUsername),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.webDavUsernameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.webDavPassword),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.webDavPasswordRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remotePathController,
                  decoration: InputDecoration(labelText: l10n.webDavRemotePath),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.webDavRemotePathRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? l10n.saving : l10n.save),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loading ? null : _testConnection,
                  child: Text(l10n.webDavTestConnection),
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
          );
        },
        error: (_, __) => Center(child: Text(l10n.unableToLoadCredential)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _initialize(WebDavConfig? config) {
    if (_initialized || config == null) return;
    _initialized = true;
    _baseUrlController.text = config.baseUrl;
    _usernameController.text = config.username;
    _passwordController.text = config.appPassword;
    _remotePathController.text = config.remotePath;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _persistCurrentConfig();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.webDavSaved)),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.webDavSaveFailed);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = ref.read(cloudSyncProviderRegistryProvider)[
          CloudSyncProviderType.webdav];
      if (provider is! WebDavSyncProvider) {
        throw const CloudSyncException(
          CloudSyncExceptionCode.providerUnavailable,
        );
      }

      await provider.validateConnectionWithConfig(_buildConfig());
      await _persistCurrentConfig();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.webDavConnectionSuccess}，${l10n.webDavSaved}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _mapCloudSyncError(error, l10n));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  WebDavConfig _buildConfig() {
    return WebDavConfig(
      baseUrl: _baseUrlController.text.trim(),
      username: _usernameController.text.trim(),
      appPassword: _passwordController.text.trim(),
      remotePath: _remotePathController.text.trim(),
    );
  }

  Future<void> _persistCurrentConfig() async {
    await ref.read(cloudSyncRepositoryProvider).saveWebDavConfig(_buildConfig());
    ref.invalidate(_webDavConfigProvider);
  }

  String _mapCloudSyncError(Object error, AppLocalizations l10n) {
    if (error is CloudSyncException) {
      switch (error.code) {
        case CloudSyncExceptionCode.authenticationFailed:
          return l10n.webDavAuthFailed;
        case CloudSyncExceptionCode.remoteFileNotFound:
          return l10n.webDavRemoteFileMissing;
        case CloudSyncExceptionCode.networkError:
          return l10n.webDavNetworkError;
        case CloudSyncExceptionCode.invalidConfiguration:
        case CloudSyncExceptionCode.notConfigured:
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

final _webDavConfigProvider = FutureProvider<WebDavConfig?>((ref) async {
  final config = await ref.read(cloudSyncRepositoryProvider).getCurrentConfig();
  return config?.webDavConfig;
});
