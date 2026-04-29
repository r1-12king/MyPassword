import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../domain/cloud_sync/cloud_sync_automation_service.dart';
import '../../../../domain/repositories/credential_repository.dart';
import '../../../../shared/providers/app_providers.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final credentialsProvider =
    FutureProvider.family<List<CredentialListItem>, String>((ref, query) {
  return ref.read(credentialRepositoryProvider).getCredentials(query: query);
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  RemoteSyncAlertType _remoteAlertType = RemoteSyncAlertType.none;
  bool _checkedRemoteAlert = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedRemoteAlert) {
      return;
    }
    _checkedRemoteAlert = true;
    Future.microtask(_loadRemoteAlert);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searchQuery = ref.watch(searchQueryProvider);
    final credentialsAsync = ref.watch(credentialsProvider(searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwords),
        actions: [
          IconButton(
            onPressed: () => context.push(RouteNames.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_remoteAlertType != RemoteSyncAlertType.none)
            MaterialBanner(
              content: Text(
                _remoteAlertType == RemoteSyncAlertType.syncConflict
                    ? l10n.remoteSyncConflict
                    : l10n.remoteSyncUpdateAvailable,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _remoteAlertType = RemoteSyncAlertType.none);
                  },
                  child: Text(l10n.dismiss),
                ),
                TextButton(
                  onPressed: () => context.push(
                    _remoteAlertType == RemoteSyncAlertType.syncConflict
                        ? RouteNames.syncConflict
                        : RouteNames.syncStatus,
                  ),
                  child: Text(
                    _remoteAlertType == RemoteSyncAlertType.syncConflict
                        ? l10n.syncConflictTitle
                        : l10n.syncStatus,
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),
          Expanded(
            child: credentialsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(l10n.noCredentialsYet),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Slidable(
                      key: ValueKey(item.id),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.28,
                        children: [
                          SlidableAction(
                            onPressed: (_) => _confirmDelete(
                              context,
                              ref,
                              item.id,
                              searchQuery,
                              l10n,
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: l10n.delete,
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () => context.push('/credentials/${item.id}').then(
                              (_) => ref.invalidate(
                                credentialsProvider(searchQuery),
                              ),
                            ),
                        title: Text(item.title),
                        subtitle: Text(_buildSubtitle(item, l10n)),
                        trailing:
                            item.favorite ? const Icon(Icons.star, size: 18) : null,
                      ),
                    );
                  },
                );
              },
              error: (_, __) => Center(
                child: Text(l10n.unableToLoadCredential),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.credentialCreate).then((_) {
          ref.invalidate(credentialsProvider(searchQuery));
        }),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _buildSubtitle(CredentialListItem item, AppLocalizations l10n) {
    final parts = <String>[];
    final username = item.username?.trim();
    final websiteDomain = item.websiteDomain?.trim();

    if (username != null && username.isNotEmpty) {
      parts.add(username);
    }
    if (websiteDomain != null && websiteDomain.isNotEmpty) {
      parts.add(websiteDomain);
    }

    if (parts.isEmpty) {
      return '${l10n.noUsername} · ${l10n.noDomain}';
    }

    return parts.join(' · ');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String credentialId,
    String searchQuery,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.deleteCredentialTitle),
              content: Text(l10n.deleteCredentialMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.delete),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    await ref.read(credentialRepositoryProvider).deleteCredential(credentialId);
    await ref.read(cloudSyncAutomationServiceProvider).notifyLocalVaultChanged();
    ref.invalidate(credentialsProvider(searchQuery));
  }

  Future<void> _loadRemoteAlert() async {
    try {
      final alert =
          await ref.read(cloudSyncAutomationServiceProvider).checkRemoteAlert();
      if (!mounted || !alert.shouldShow) {
        return;
      }
      setState(() => _remoteAlertType = alert.type);
    } catch (_) {
      // Ignore remote check failures on the home page.
    }
  }
}
