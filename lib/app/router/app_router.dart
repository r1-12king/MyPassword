import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/credential/presentation/pages/credential_detail_page.dart';
import '../../features/credential/presentation/pages/credential_edit_page.dart';
import '../../features/export_import/presentation/pages/export_backup_page.dart';
import '../../features/export_import/presentation/pages/import_backup_page.dart';
import '../../features/generator/presentation/pages/password_generator_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/lock/presentation/pages/lock_page.dart';
import '../../features/settings/presentation/pages/change_master_password_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/sync_conflict_page.dart';
import '../../features/settings/presentation/pages/sync_status_page.dart';
import '../../features/settings/presentation/pages/webdav_guide_page.dart';
import '../../features/settings/presentation/pages/webdav_sync_page.dart';
import '../../features/setup/presentation/pages/setup_page.dart';
import '../../shared/providers/app_providers.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.lock,
    routes: [
      GoRoute(
        path: RouteNames.lock,
        builder: (context, state) => const LockPage(),
      ),
      GoRoute(
        path: RouteNames.setup,
        builder: (context, state) => const SetupPage(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: RouteNames.credentialCreate,
        builder: (context, state) => const CredentialEditPage(),
      ),
      GoRoute(
        path: '/credentials/:credentialId',
        builder: (context, state) {
          final credentialId = state.pathParameters['credentialId']!;
          return CredentialDetailPage(credentialId: credentialId);
        },
      ),
      GoRoute(
        path: '/credentials/:credentialId/edit',
        builder: (context, state) {
          final credentialId = state.pathParameters['credentialId']!;
          return CredentialEditPage(credentialId: credentialId);
        },
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: RouteNames.generator,
        builder: (context, state) => const PasswordGeneratorPage(),
      ),
      GoRoute(
        path: RouteNames.importBackup,
        builder: (context, state) => const ImportBackupPage(),
      ),
      GoRoute(
        path: RouteNames.exportBackup,
        builder: (context, state) => const ExportBackupPage(),
      ),
      GoRoute(
        path: RouteNames.changeMasterPassword,
        builder: (context, state) => const ChangeMasterPasswordPage(),
      ),
      GoRoute(
        path: RouteNames.webDavSync,
        builder: (context, state) => const WebDavSyncPage(),
      ),
      GoRoute(
        path: RouteNames.webDavGuide,
        builder: (context, state) => const WebDavGuidePage(),
      ),
      GoRoute(
        path: RouteNames.syncStatus,
        builder: (context, state) => const SyncStatusPage(),
      ),
      GoRoute(
        path: RouteNames.syncConflict,
        builder: (context, state) => const SyncConflictPage(),
      ),
    ],
    redirect: (context, state) {
      final vaultRepository = ref.read(vaultRepositoryProvider);
      final hasVault = vaultRepository.hasVaultCached;
      final isUnlocked = vaultRepository.isUnlocked;
      final location = state.matchedLocation;
      final isSetupFlow =
          location == RouteNames.setup || location == RouteNames.importBackup;
      final isLockScreen = location == RouteNames.lock;

      if (!hasVault && !isSetupFlow) {
        return RouteNames.setup;
      }

      if (hasVault && !isUnlocked && !isLockScreen) {
        return RouteNames.lock;
      }

      if (hasVault && isUnlocked && (isLockScreen || location == RouteNames.setup)) {
        return RouteNames.home;
      }

      return null;
    },
  );
});
