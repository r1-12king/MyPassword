import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

abstract class VaultMetaDao {
  Future<bool> hasVault();
  Future<Map<String, Object?>?> getVaultMetaRow();
  Future<void> insertVaultMeta(Map<String, Object?> row);
  Future<void> deleteVaultMeta();
}

class VaultMetaDaoImpl implements VaultMetaDao {
  VaultMetaDaoImpl(this._database);

  final AppDatabase _database;

  Database get _db => _database.instance;

  @override
  Future<bool> hasVault() async {
    final rows = await _db.query(
      'vault_meta',
      columns: ['id'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<Map<String, Object?>?> getVaultMetaRow() async {
    final rows = await _db.query(
      'vault_meta',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<void> insertVaultMeta(Map<String, Object?> row) {
    return _db.insert(
      'vault_meta',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteVaultMeta() {
    return _db.delete('vault_meta');
  }
}
