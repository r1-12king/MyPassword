import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../domain/repositories/credential_repository.dart';
import '../../security/crypto/crypto_service.dart';
import '../datasources/local/daos/credential_dao.dart';
import '../datasources/local/daos/import_history_dao.dart';
import '../datasources/local/daos/vault_meta_dao.dart';

class CredentialRepositoryImpl implements CredentialRepository {
  CredentialRepositoryImpl({
    required CredentialDao credentialDao,
    required CryptoService cryptoService,
    required ImportHistoryDao importHistoryDao,
    required VaultMetaDao vaultMetaDao,
  })  : _credentialDao = credentialDao,
        _cryptoService = cryptoService,
        _importHistoryDao = importHistoryDao,
        _vaultMetaDao = vaultMetaDao;

  final CredentialDao _credentialDao;
  final CryptoService _cryptoService;
  final ImportHistoryDao _importHistoryDao;
  final VaultMetaDao _vaultMetaDao;
  final Uuid _uuid = const Uuid();
  final Random _random = Random.secure();

  @override
  Future<String> saveCredential(SaveCredentialInput input) async {
    if (!_cryptoService.isUnlocked) {
      throw StateError('Vault is locked');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = input.id ?? _uuid.v4();
    final existing = input.id == null ? null : await _credentialDao.getById(id);

    final row = <String, Object?>{
      'id': id,
      'title': input.title.trim(),
      'username_ciphertext': await _encryptNullable(input.username),
      'password_ciphertext': await _cryptoService.encryptToBytes(input.password),
      'notes_ciphertext': await _encryptNullable(input.notes),
      'website_url': input.websiteUrl?.trim(),
      'website_domain': _normalizeDomain(input.websiteUrl),
      'favorite': input.favorite ? 1 : 0,
      'category': input.category?.trim(),
      'updated_at': now,
      'deleted_at': null,
      'version': 1,
    };

    if (existing == null) {
      row['created_at'] = now;
      await _credentialDao.insert(row);
    } else {
      row['created_at'] = existing['created_at'];
      await _credentialDao.update(id, row);
    }

    return id;
  }

  @override
  Future<List<CredentialListItem>> getCredentials({
    String? query,
    bool favoritesOnly = false,
  }) async {
    final rows = await _credentialDao.queryActive(
      query: query,
      favoritesOnly: favoritesOnly,
    );
    return Future.wait(rows.map(_mapListItem));
  }

  @override
  Future<CredentialDetail?> getCredentialDetail(String id) async {
    final row = await _credentialDao.getById(id);
    if (row == null) return null;

    return CredentialDetail(
      id: row['id'] as String,
      title: row['title'] as String,
      username: await _decryptNullable(row['username_ciphertext']),
      password: await _cryptoService.decryptFromBytes(
        (row['password_ciphertext'] as List<Object?>).cast<int>(),
      ),
      websiteUrl: row['website_url'] as String?,
      websiteDomain: row['website_domain'] as String?,
      notes: await _decryptNullable(row['notes_ciphertext']),
      category: row['category'] as String?,
      favorite: (row['favorite'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  @override
  Future<void> deleteCredential(String id) {
    return _credentialDao.softDelete(
      id,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> markCredentialUsed(String id) {
    return _credentialDao.updateLastUsedAt(
      id,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String generatePassword({
    int length = 20,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    final pools = <String>[];
    if (uppercase) pools.add('ABCDEFGHJKLMNPQRSTUVWXYZ');
    if (lowercase) pools.add('abcdefghijkmnopqrstuvwxyz');
    if (numbers) pools.add('23456789');
    if (symbols) pools.add('!@#\$%^&*()-_=+[]{}?');

    if (pools.isEmpty) {
      throw ArgumentError('At least one character set must be enabled');
    }

    if (length < pools.length) {
      throw ArgumentError('Length must be at least ${pools.length}');
    }

    final allChars = pools.join();
    final chars = <String>[];

    for (final pool in pools) {
      chars.add(pool[_random.nextInt(pool.length)]);
    }

    while (chars.length < length) {
      chars.add(allChars[_random.nextInt(allChars.length)]);
    }

    chars.shuffle(_random);
    return chars.take(length).join();
  }

  @override
  Future<BackupExportData> exportBackup({
    required String currentMasterPassword,
  }) async {
    if (!_cryptoService.isUnlocked) {
      throw StateError('Vault is locked');
    }

    final vaultMetaRow = await _vaultMetaDao.getVaultMetaRow();
    if (vaultMetaRow == null) {
      throw StateError('Vault not found');
    }
    final vaultMeta = VaultMetaRecord.fromRow(vaultMetaRow);
    final passwordValid = await _cryptoService.verifyMasterPassword(
      masterPassword: currentMasterPassword,
      vaultMeta: vaultMeta,
    );
    if (!passwordValid) {
      throw StateError('Invalid master password');
    }

    final rows = await _credentialDao.queryActive(orderBy: 'updated_at DESC');
    final details = <Map<String, Object?>>[];

    for (final row in rows) {
      final detail = await getCredentialDetail(row['id'] as String);
      if (detail == null) continue;
      details.add({
        'id': detail.id,
        'title': detail.title,
        'username': detail.username,
        'password': detail.password,
        'websiteUrl': detail.websiteUrl,
        'websiteDomain': detail.websiteDomain,
        'notes': detail.notes,
        'category': detail.category,
        'favorite': detail.favorite,
        'createdAt': detail.createdAt.millisecondsSinceEpoch,
        'updatedAt': detail.updatedAt.millisecondsSinceEpoch,
      });
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final passwordVerifier = await _cryptoService.createPasswordVerifier(
      currentMasterPassword,
    );
    final payload = jsonEncode({
      'version': 2,
      'exportedAt': timestamp,
      'masterPasswordVerifier': passwordVerifier,
      'credentials': details,
    });
    final encryptedPayload = await _cryptoService.encryptWithPassword(
      plaintext: payload,
      password: currentMasterPassword,
    );
    return BackupExportData(
      fileName: 'my_password_backup_$timestamp.mpbak',
      bytes: encryptedPayload,
    );
  }

  @override
  Future<int> importBackup(
    String filePath, {
    required String backupMasterPassword,
  }) async {
    if (!_cryptoService.isUnlocked) {
      throw StateError('Vault is locked');
    }

    final importId = _uuid.v4();
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    await _importHistoryDao.insert({
      'id': importId,
      'source_type': 'backup_file',
      'source_name': filePath.split(Platform.pathSeparator).last,
      'imported_count': 0,
      'skipped_count': 0,
      'failed_count': 0,
      'started_at': startedAt,
      'status': 'running',
    });

    try {
      final payload = await _readBackupPayload(
        filePath,
        backupMasterPassword: backupMasterPassword,
      );
      final existingItems = await getCredentials();
      final existingKeys = existingItems
          .map((item) => _buildDuplicateKey(
                title: item.title,
                username: item.username,
                websiteDomain: item.websiteDomain,
              ))
          .toSet();
      final credentials = (payload['credentials'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      var importedCount = 0;
      var skippedCount = 0;
      for (final item in credentials) {
        final duplicateKey = _buildDuplicateKey(
          title: (item['title'] as String?) ?? 'Imported item',
          username: item['username'] as String?,
          websiteDomain:
              item['websiteDomain'] as String? ?? _normalizeDomain(item['websiteUrl'] as String?),
        );
        if (existingKeys.contains(duplicateKey)) {
          skippedCount += 1;
          continue;
        }

        await saveCredential(
          SaveCredentialInput(
            title: (item['title'] as String?) ?? 'Imported item',
            username: item['username'] as String?,
            password: (item['password'] as String?) ?? '',
            websiteUrl: item['websiteUrl'] as String?,
            notes: item['notes'] as String?,
            category: item['category'] as String?,
            favorite: item['favorite'] as bool? ?? false,
          ),
        );
        existingKeys.add(duplicateKey);
        importedCount += 1;
      }

      await _importHistoryDao.updateStatus(
        importId,
        status: 'completed',
        importedCount: importedCount,
        skippedCount: skippedCount,
        completedAt: DateTime.now().millisecondsSinceEpoch,
      );
      return importedCount;
    } catch (_) {
      await _importHistoryDao.updateStatus(
        importId,
        status: 'failed',
        failedCount: 1,
        completedAt: DateTime.now().millisecondsSinceEpoch,
      );
      rethrow;
    }
  }

  @override
  Future<bool> verifyBackupPassword(
    String filePath, {
    required String backupMasterPassword,
  }) async {
    try {
      await _readBackupPayload(
        filePath,
        backupMasterPassword: backupMasterPassword,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CredentialListItem> _mapListItem(Map<String, Object?> row) async {
    return CredentialListItem(
      id: row['id'] as String,
      title: row['title'] as String,
      username: await _decryptNullable(row['username_ciphertext']),
      websiteDomain: row['website_domain'] as String?,
      favorite: (row['favorite'] as int) == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Future<List<int>?> _encryptNullable(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return _cryptoService.encryptToBytes(normalized);
  }

  Future<String?> _decryptNullable(Object? value) async {
    if (value == null) return null;
    return _cryptoService.decryptFromBytes((value as List<Object?>).cast<int>());
  }

  String? _normalizeDomain(String? url) {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return Uri.tryParse(normalized)?.host.toLowerCase();
  }

  String _buildDuplicateKey({
    required String title,
    String? username,
    String? websiteDomain,
  }) {
    return [
      title.trim().toLowerCase(),
      username?.trim().toLowerCase() ?? '',
      websiteDomain?.trim().toLowerCase() ?? '',
    ].join('|');
  }

  Future<Map<String, dynamic>> _readBackupPayload(
    String filePath, {
    required String backupMasterPassword,
  }) async {
    final encryptedBytes = await File(filePath).readAsBytes();
    final content = await _cryptoService.decryptWithPassword(
      ciphertext: encryptedBytes,
      password: backupMasterPassword,
    );
    final payload = jsonDecode(content) as Map<String, dynamic>;
    final verifier = payload['masterPasswordVerifier'] as Map<String, dynamic>?;
    if (verifier == null) {
      throw StateError('Backup verifier missing');
    }
    final passwordValid = await _cryptoService.verifyPasswordWithVerifier(
      password: backupMasterPassword,
      verifier: verifier,
    );
    if (!passwordValid) {
      throw StateError('Invalid backup password');
    }
    return payload;
  }
}
