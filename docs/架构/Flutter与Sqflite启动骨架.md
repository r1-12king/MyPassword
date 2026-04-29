# Flutter + sqflite Bootstrap Skeleton

## Goal

This document provides a practical initialization skeleton for a Flutter password manager MVP built with:

- `flutter_riverpod`
- `go_router`
- `sqflite`
- `local_auth`

The goal is not to provide a full app, but to define the minimum code structure needed to:

- start the app cleanly
- initialize the local database
- wire repositories through providers
- determine first-run or locked-state routing
- leave room for crypto and biometric integration

## Suggested File Layout

```text
lib/
  main.dart
  bootstrap/
    app_bootstrap.dart
  app/
    app.dart
    router/
      app_router.dart
      route_names.dart
  core/
    constants/
      db_constants.dart
  data/
    datasources/
      local/
        db/
          app_database.dart
          db_migrations.dart
        daos/
          credential_dao.dart
          vault_meta_dao.dart
    repositories/
      credential_repository_impl.dart
      vault_repository_impl.dart
  domain/
    repositories/
      credential_repository.dart
      vault_repository.dart
  security/
    biometric/
      biometric_service.dart
    crypto/
      crypto_service.dart
    storage/
      secure_key_storage.dart
  features/
    lock/
      presentation/
        pages/
          lock_page.dart
    setup/
      presentation/
        pages/
          setup_page.dart
    home/
      presentation/
        pages/
          home_page.dart
  shared/
    providers/
      app_providers.dart
```

## Package Suggestions

Example dependencies for `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  sqflite: ^2.3.3+1
  path: ^1.9.0
  path_provider: ^2.1.4
  local_auth: ^2.3.0
  flutter_secure_storage: ^9.2.2
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
```

If you later add model code generation, add:

- `freezed`
- `json_serializable`
- `build_runner`

## Bootstrap Flow

Recommended app startup flow:

1. Flutter framework starts
2. Create app bootstrap container
3. Open local database
4. Build repositories and services
5. Run `ProviderScope`
6. Build router from current vault state
7. Route to:
   - `setup` if no vault exists
   - `lock` if vault exists but is locked
   - `home` if session is already unlocked

For MVP, it is simpler to always start at `lock` and let `lock` redirect to `setup` when needed.

## `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await AppBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: bootstrap.providerOverrides,
      child: const PasswordManagerApp(),
    ),
  );
}
```

## `bootstrap/app_bootstrap.dart`

This is the app composition root.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../data/datasources/local/db/app_database.dart';
import '../data/datasources/local/daos/credential_dao.dart';
import '../data/datasources/local/daos/vault_meta_dao.dart';
import '../data/repositories/credential_repository_impl.dart';
import '../data/repositories/vault_repository_impl.dart';
import '../domain/repositories/credential_repository.dart';
import '../domain/repositories/vault_repository.dart';
import '../security/biometric/biometric_service.dart';
import '../security/crypto/crypto_service.dart';
import '../security/storage/secure_key_storage.dart';
import '../shared/providers/app_providers.dart';

class AppBootstrap {
  AppBootstrap._({
    required this.providerOverrides,
  });

  final List<Override> providerOverrides;

  static Future<AppBootstrap> initialize() async {
    final database = AppDatabase();
    await database.open();

    final vaultMetaDao = VaultMetaDao(database);
    final credentialDao = CredentialDao(database);

    final secureKeyStorage = SecureKeyStorage();
    final cryptoService = CryptoService(secureKeyStorage: secureKeyStorage);
    final biometricService = BiometricService();

    final vaultRepository = VaultRepositoryImpl(
      vaultMetaDao: vaultMetaDao,
      secureKeyStorage: secureKeyStorage,
      cryptoService: cryptoService,
    );

    final credentialRepository = CredentialRepositoryImpl(
      credentialDao: credentialDao,
      cryptoService: cryptoService,
    );

    return AppBootstrap._(
      providerOverrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureKeyStorageProvider.overrideWithValue(secureKeyStorage),
        cryptoServiceProvider.overrideWithValue(cryptoService),
        biometricServiceProvider.overrideWithValue(biometricService),
        vaultRepositoryProvider.overrideWithValue(vaultRepository),
        credentialRepositoryProvider.overrideWithValue(credentialRepository),
      ],
    );
  }
}
```

## `app/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

class PasswordManagerApp extends ConsumerWidget {
  const PasswordManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MyPassword',
      routerConfig: router,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
    );
  }
}
```

## `app/router/route_names.dart`

```dart
abstract final class RouteNames {
  static const lock = '/lock';
  static const setup = '/setup';
  static const home = '/home';
  static const credentialDetail = '/credential/:credentialId';
  static const credentialCreate = '/credential/new';
  static const credentialEdit = '/credential/:credentialId/edit';
  static const settings = '/settings';
  static const importData = '/import';
}
```

## `app/router/app_router.dart`

This MVP router is intentionally simple.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/lock/presentation/pages/lock_page.dart';
import '../../features/setup/presentation/pages/setup_page.dart';
import '../../shared/providers/app_providers.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final vaultRepository = ref.watch(vaultRepositoryProvider);

  return GoRouter(
    initialLocation: RouteNames.lock,
    redirect: (context, state) {
      final hasVault = vaultRepository.hasVaultSync();

      if (!hasVault && state.matchedLocation != RouteNames.setup) {
        return RouteNames.setup;
      }

      return null;
    },
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
    ],
  );
});
```

Implementation note:

- `hasVaultSync()` is fine for startup only if repository state is already initialized
- if you later need async redirect logic, move that to a splash/bootstrap screen instead

## `shared/providers/app_providers.dart`

Use one file to expose app-level dependencies.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/db/app_database.dart';
import '../../domain/repositories/credential_repository.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../security/biometric/biometric_service.dart';
import '../../security/crypto/crypto_service.dart';
import '../../security/storage/secure_key_storage.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError();
});

final secureKeyStorageProvider = Provider<SecureKeyStorage>((ref) {
  throw UnimplementedError();
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  throw UnimplementedError();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  throw UnimplementedError();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  throw UnimplementedError();
});

final credentialRepositoryProvider = Provider<CredentialRepository>((ref) {
  throw UnimplementedError();
});
```

## Database Layer

## `core/constants/db_constants.dart`

```dart
abstract final class DbConstants {
  static const dbName = 'my_password.db';
  static const dbVersion = 1;

  static const vaultMetaTable = 'vault_meta';
  static const credentialsTable = 'credentials';
  static const importHistoryTable = 'import_history';
}
```

## `data/datasources/local/db/app_database.dart`

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/db_constants.dart';
import 'db_migrations.dart';

class AppDatabase {
  Database? _db;

  Database get instance {
    final db = _db;
    if (db == null) {
      throw StateError('Database has not been opened');
    }
    return db;
  }

  Future<void> open() async {
    if (_db != null) return;

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, DbConstants.dbName);

    _db = await openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: (db, version) async {
        await DbMigrations.onCreate(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await DbMigrations.onUpgrade(db, oldVersion, newVersion);
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
```

## `data/datasources/local/db/db_migrations.dart`

```dart
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/db_constants.dart';

abstract final class DbMigrations {
  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.vaultMetaTable} (
        id TEXT PRIMARY KEY NOT NULL,
        master_password_kdf TEXT NOT NULL,
        kdf_memory_kb INTEGER NOT NULL,
        kdf_iterations INTEGER NOT NULL,
        kdf_parallelism INTEGER NOT NULL,
        salt_base64 TEXT NOT NULL,
        wrapped_vault_key_base64 TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.credentialsTable} (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        username_ciphertext BLOB,
        password_ciphertext BLOB NOT NULL,
        notes_ciphertext BLOB,
        website_url TEXT,
        website_domain TEXT,
        favorite INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_used_at INTEGER,
        deleted_at INTEGER,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_credentials_title
      ON ${DbConstants.credentialsTable}(title)
    ''');

    await db.execute('''
      CREATE INDEX idx_credentials_domain
      ON ${DbConstants.credentialsTable}(website_domain)
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.importHistoryTable} (
        id TEXT PRIMARY KEY NOT NULL,
        source_type TEXT NOT NULL,
        source_name TEXT,
        imported_count INTEGER NOT NULL,
        skipped_count INTEGER NOT NULL DEFAULT 0,
        failed_count INTEGER NOT NULL DEFAULT 0,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        status TEXT NOT NULL
      )
    ''');
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Future migration example.
    }
  }
}
```

## DAO Layer

## `data/datasources/local/daos/vault_meta_dao.dart`

```dart
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

class VaultMetaDao {
  VaultMetaDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.instance;

  Future<bool> hasVault() async {
    final result = await _db.query(
      'vault_meta',
      columns: ['id'],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<void> insertVaultMeta(Map<String, Object?> values) async {
    await _db.insert(
      'vault_meta',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

## `data/datasources/local/daos/credential_dao.dart`

```dart
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

class CredentialDao {
  CredentialDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.instance;

  Future<List<Map<String, Object?>>> getAllActive() async {
    return _db.query(
      'credentials',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> insert(Map<String, Object?> values) async {
    await _db.insert(
      'credentials',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDelete(String id, int deletedAt) async {
    await _db.update(
      'credentials',
      {
        'deleted_at': deletedAt,
        'updated_at': deletedAt,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

## Domain Repository Contracts

## `domain/repositories/vault_repository.dart`

```dart
abstract class VaultRepository {
  Future<bool> hasVault();
  bool hasVaultSync();
  Future<void> createVault({
    required String masterPassword,
  });
  Future<bool> unlockVault({
    required String masterPassword,
  });
}
```

## `domain/repositories/credential_repository.dart`

```dart
abstract class CredentialRepository {
  Future<void> saveCredential({
    required String title,
    required String? username,
    required String password,
    required String? notes,
    required String? websiteUrl,
  });

  Future<List<Map<String, Object?>>> getCredentials();
}
```

## Repository Implementations

## `data/repositories/vault_repository_impl.dart`

This is where master password verification and vault key setup should live.

```dart
import '../../domain/repositories/vault_repository.dart';
import '../../security/crypto/crypto_service.dart';
import '../../security/storage/secure_key_storage.dart';
import '../datasources/local/daos/vault_meta_dao.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl({
    required VaultMetaDao vaultMetaDao,
    required SecureKeyStorage secureKeyStorage,
    required CryptoService cryptoService,
  })  : _vaultMetaDao = vaultMetaDao,
        _secureKeyStorage = secureKeyStorage,
        _cryptoService = cryptoService;

  final VaultMetaDao _vaultMetaDao;
  final SecureKeyStorage _secureKeyStorage;
  final CryptoService _cryptoService;

  bool _hasVaultCache = false;

  @override
  Future<bool> hasVault() async {
    _hasVaultCache = await _vaultMetaDao.hasVault();
    return _hasVaultCache;
  }

  @override
  bool hasVaultSync() => _hasVaultCache;

  @override
  Future<void> createVault({
    required String masterPassword,
  }) async {
    final vaultSetup = await _cryptoService.createVaultSetup(masterPassword);

    await _vaultMetaDao.insertVaultMeta(vaultSetup.metaRow);
    await _secureKeyStorage.persistWrappedSessionMaterial(
      vaultSetup.sessionMaterial,
    );

    _hasVaultCache = true;
  }

  @override
  Future<bool> unlockVault({
    required String masterPassword,
  }) async {
    return _cryptoService.unlock(masterPassword);
  }
}
```

Important note:

- In production, `hasVaultSync()` should only be used after bootstrap has already populated cache
- otherwise use a splash/bootstrap screen and async state

## `data/repositories/credential_repository_impl.dart`

```dart
import 'package:uuid/uuid.dart';

import '../../domain/repositories/credential_repository.dart';
import '../../security/crypto/crypto_service.dart';
import '../datasources/local/daos/credential_dao.dart';

class CredentialRepositoryImpl implements CredentialRepository {
  CredentialRepositoryImpl({
    required CredentialDao credentialDao,
    required CryptoService cryptoService,
  })  : _credentialDao = credentialDao,
        _cryptoService = cryptoService;

  final CredentialDao _credentialDao;
  final CryptoService _cryptoService;
  final Uuid _uuid = const Uuid();

  @override
  Future<void> saveCredential({
    required String title,
    required String? username,
    required String password,
    required String? notes,
    required String? websiteUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _credentialDao.insert({
      'id': _uuid.v4(),
      'title': title,
      'username_ciphertext': username == null
          ? null
          : await _cryptoService.encryptToBytes(username),
      'password_ciphertext': await _cryptoService.encryptToBytes(password),
      'notes_ciphertext': notes == null
          ? null
          : await _cryptoService.encryptToBytes(notes),
      'website_url': websiteUrl,
      'website_domain': _normalizeDomain(websiteUrl),
      'favorite': 0,
      'created_at': now,
      'updated_at': now,
      'version': 1,
    });
  }

  @override
  Future<List<Map<String, Object?>>> getCredentials() {
    return _credentialDao.getAllActive();
  }

  String? _normalizeDomain(String? url) {
    if (url == null || url.isEmpty) return null;
    return Uri.tryParse(url)?.host.toLowerCase();
  }
}
```

## Security Service Skeleton

## `security/storage/secure_key_storage.dart`

This file hides platform secure storage details.

```dart
class SecureKeyStorage {
  Future<void> persistWrappedSessionMaterial(String value) async {
    // TODO: store using flutter_secure_storage or a platform channel.
  }

  Future<String?> readWrappedSessionMaterial() async {
    // TODO: read secure value.
    return null;
  }
}
```

## `security/crypto/crypto_service.dart`

This file should centralize vault key creation, unlock, and field encryption.

```dart
class VaultSetupResult {
  VaultSetupResult({
    required this.metaRow,
    required this.sessionMaterial,
  });

  final Map<String, Object?> metaRow;
  final String sessionMaterial;
}

class CryptoService {
  CryptoService({
    required this.secureKeyStorage,
  });

  final SecureKeyStorage secureKeyStorage;

  Future<VaultSetupResult> createVaultSetup(String masterPassword) async {
    // TODO:
    // 1. generate salt
    // 2. derive key with Argon2id
    // 3. generate vault key
    // 4. wrap vault key
    // 5. return row payload for vault_meta
    throw UnimplementedError();
  }

  Future<bool> unlock(String masterPassword) async {
    // TODO:
    // 1. load vault meta
    // 2. derive key again
    // 3. unwrap vault key
    // 4. cache unlocked session in memory
    throw UnimplementedError();
  }

  Future<List<int>> encryptToBytes(String plaintext) async {
    // TODO: encrypt with unlocked vault key
    throw UnimplementedError();
  }

  Future<String> decryptFromBytes(List<int> ciphertext) async {
    // TODO: decrypt with unlocked vault key
    throw UnimplementedError();
  }
}
```

## Biometric Service Skeleton

## `security/biometric/biometric_service.dart`

```dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuthentication = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    return _localAuthentication.canCheckBiometrics ||
        await _localAuthentication.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    return _localAuthentication.authenticate(
      localizedReason: 'Unlock your vault',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
}
```

## Minimal Pages

These pages can stay very small in the first implementation.

## `features/setup/presentation/pages/setup_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/providers/app_providers.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Vault')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Master password',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Creating...' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    try {
      await ref.read(vaultRepositoryProvider).createVault(
            masterPassword: _controller.text,
          );

      if (!mounted) return;
      context.go(RouteNames.home);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
```

## `features/lock/presentation/pages/lock_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../shared/providers/app_providers.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkVaultState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Vault')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Master password',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _unlock,
              child: Text(_loading ? 'Unlocking...' : 'Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkVaultState() async {
    final hasVault = await ref.read(vaultRepositoryProvider).hasVault();
    if (!mounted) return;

    if (!hasVault) {
      context.go(RouteNames.setup);
    }
  }

  Future<void> _unlock() async {
    setState(() => _loading = true);

    try {
      final success = await ref.read(vaultRepositoryProvider).unlockVault(
            masterPassword: _controller.text,
          );

      if (!mounted) return;
      if (success) {
        context.go(RouteNames.home);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
```

## `features/home/presentation/pages/home_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passwords')),
      body: const Center(
        child: Text('Credential list goes here'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## Recommended Next Implementation Order

After wiring this bootstrap skeleton, build in this order:

1. complete `CryptoService.createVaultSetup()`
2. complete `CryptoService.unlock()`
3. implement secure storage persistence
4. implement credential list mapping and detail fetch
5. add create/edit credential form
6. add password generator flow
7. add biometric unlock
8. add import flow

## Important Caveats

- `sqflite` is storage only, not security
- field encryption must happen before database insert
- do not place master password in Riverpod state, logs, or route parameters
- do not keep plaintext secrets in widget state longer than needed
- avoid making router redirect depend on slow async work unless you insert a splash/bootstrap route

## Next Step

The most useful follow-up after this skeleton would be one of these:

- `CryptoService` envelope format draft
- `sqflite` DAO + model mapping skeleton
- Flutter credential create/edit page skeleton
