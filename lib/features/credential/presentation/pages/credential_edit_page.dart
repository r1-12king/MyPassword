import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../domain/repositories/credential_repository.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'credential_detail_page.dart';

class CredentialEditPage extends ConsumerStatefulWidget {
  const CredentialEditPage({
    super.key,
    this.credentialId,
  });

  final String? credentialId;

  @override
  ConsumerState<CredentialEditPage> createState() => _CredentialEditPageState();
}

class _CredentialEditPageState extends ConsumerState<CredentialEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();
  bool _favorite = false;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final credentialId = widget.credentialId;
    final detailAsync = credentialId == null
        ? const AsyncData<CredentialDetail?>(null)
        : ref.watch(credentialDetailProvider(credentialId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          credentialId == null ? l10n.newCredential : l10n.editCredential,
        ),
      ),
      body: detailAsync.when(
        data: (detail) {
          _initialize(detail);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: l10n.title),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.titleRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: l10n.username),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: l10n.password),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _openGenerator,
                  child: Text(l10n.generatePassword),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _websiteController,
                  decoration: InputDecoration(labelText: l10n.website),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: l10n.notes),
                ),
                SwitchListTile(
                  title: Text(l10n.favorite),
                  value: _favorite,
                  onChanged: (value) => setState(() => _favorite = value),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: Text(_loading ? l10n.saving : l10n.save),
                ),
              ],
            ),
          );
        },
        error: (_, __) => Center(
          child: Text(l10n.unableToLoadCredential),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  void _initialize(CredentialDetail? detail) {
    if (_initialized) return;
    _initialized = true;
    if (detail == null) return;

    _titleController.text = detail.title;
    _usernameController.text = detail.username ?? '';
    _passwordController.text = detail.password;
    _websiteController.text = detail.websiteUrl ?? '';
    _notesController.text = detail.notes ?? '';
    _favorite = detail.favorite;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final repository = ref.read(credentialRepositoryProvider);
      final id = await repository.saveCredential(
        SaveCredentialInput(
          id: widget.credentialId,
          title: _titleController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          websiteUrl: _websiteController.text,
          notes: _notesController.text,
          favorite: _favorite,
        ),
      );
      await ref.read(cloudSyncAutomationServiceProvider).notifyLocalVaultChanged();

      ref.invalidate(credentialsProvider(''));
      ref.invalidate(credentialDetailProvider(id));

      if (!mounted) return;
      final detailRoute = '/credentials/$id';
      if (widget.credentialId == null) {
        if (context.canPop()) {
          context.pushReplacement(detailRoute);
        } else {
          context.go(detailRoute);
        }
        return;
      }

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(detailRoute);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openGenerator() async {
    final generated = await context.push<String>(RouteNames.generator);
    if (generated == null || !mounted) return;
    setState(() => _passwordController.text = generated);
  }
}
