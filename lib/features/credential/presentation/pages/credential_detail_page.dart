import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../domain/repositories/credential_repository.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';

final credentialDetailProvider =
    FutureProvider.family<CredentialDetail?, String>((ref, credentialId) {
  return ref.read(credentialRepositoryProvider).getCredentialDetail(credentialId);
});

class CredentialDetailPage extends ConsumerWidget {
  const CredentialDetailPage({
    super.key,
    required this.credentialId,
  });

  final String credentialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(credentialDetailProvider(credentialId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.credential),
        actions: [
          IconButton(
            onPressed: () => context.push('/credentials/$credentialId/edit'),
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return Center(child: Text(l10n.credentialNotFound));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OverviewCard(detail: detail),
              const SizedBox(height: 16),
              Text(
                l10n.credential,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _FieldTile(
                label: l10n.username,
                value: detail.username ?? '',
                icon: Icons.person_outline,
                actionLabel: l10n.copyUsername,
                onAction: detail.username == null || detail.username!.isEmpty
                    ? null
                    : () => _copyField(
                          context,
                          value: detail.username!,
                          message: l10n.copiedUsername,
                        ),
              ),
              _FieldTile(
                label: l10n.password,
                value: detail.password,
                icon: Icons.lock_outline,
                actionLabel: l10n.copyPassword,
                onAction: () => _copyField(
                  context,
                  value: detail.password,
                  message: l10n.copiedPassword,
                ),
              ),
              _FieldTile(
                label: l10n.website,
                value: detail.websiteUrl ?? '',
                icon: Icons.language,
              ),
              _FieldTile(
                label: l10n.notes,
                value: detail.notes ?? '',
                icon: Icons.notes_outlined,
                multiline: true,
              ),
              _FieldTile(
                label: l10n.category,
                value: detail.category ?? '',
                icon: Icons.folder_open_outlined,
              ),
              _FieldTile(
                label: l10n.updated,
                value: detail.updatedAt.toIso8601String(),
                icon: Icons.schedule,
              ),
            ],
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(credentialRepositoryProvider).deleteCredential(credentialId);
    await ref.read(cloudSyncAutomationServiceProvider).notifyLocalVaultChanged();
    ref.invalidate(searchQueryProvider);
    ref.invalidate(credentialsProvider(''));
    ref.invalidate(credentialDetailProvider(credentialId));
    if (!context.mounted) return;
    context.go(RouteNames.home);
  }

  Future<void> _copyField(
    BuildContext context, {
    required String value,
    required String message,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.detail,
  });

  final CredentialDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((detail.websiteDomain ?? '').isNotEmpty)
                _MetaChip(
                  icon: Icons.public,
                  label: detail.websiteDomain!,
                ),
              if ((detail.category ?? '').isNotEmpty)
                _MetaChip(
                  icon: Icons.folder_open_outlined,
                  label: detail.category!,
                ),
              _MetaChip(
                icon: detail.favorite ? Icons.star : Icons.schedule,
                label: detail.favorite ? l10n.favorite : l10n.updated,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurface),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.value,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.multiline = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                value.isEmpty ? '-' : value,
                minLines: multiline ? 3 : 1,
                maxLines: multiline ? null : 3,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
