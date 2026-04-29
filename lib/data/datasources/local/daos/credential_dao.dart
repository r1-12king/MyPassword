import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

abstract class CredentialDao {
  Future<void> insert(Map<String, Object?> row);
  Future<void> update(String id, Map<String, Object?> row);
  Future<Map<String, Object?>?> getById(String id);
  Future<List<Map<String, Object?>>> queryActive({
    String? query,
    bool favoritesOnly = false,
    String orderBy = 'updated_at DESC',
  });
  Future<void> softDelete(String id, int deletedAt);
  Future<void> updateLastUsedAt(String id, int timestamp);
  Future<void> deleteAll();
}

class CredentialDaoImpl implements CredentialDao {
  CredentialDaoImpl(this._database);

  final AppDatabase _database;

  Database get _db => _database.instance;

  @override
  Future<void> insert(Map<String, Object?> row) {
    return _db.insert(
      'credentials',
      row,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> update(String id, Map<String, Object?> row) {
    return _db.update(
      'credentials',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Map<String, Object?>?> getById(String id) async {
    final rows = await _db.query(
      'credentials',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<Map<String, Object?>>> queryActive({
    String? query,
    bool favoritesOnly = false,
    String orderBy = 'favorite DESC, updated_at DESC',
  }) {
    final where = <String>['deleted_at IS NULL'];
    final whereArgs = <Object?>[];
    final normalizedQuery = query?.trim();

    if (favoritesOnly) {
      where.add('favorite = 1');
    }

    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      where.add('(title LIKE ? OR website_domain LIKE ?)');
      final likeValue = '%$normalizedQuery%';
      whereArgs.add(likeValue);
      whereArgs.add(likeValue);
    }

    return _db.query(
      'credentials',
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  @override
  Future<void> softDelete(String id, int deletedAt) {
    return _db.update(
      'credentials',
      {
        'deleted_at': deletedAt,
        'updated_at': deletedAt,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateLastUsedAt(String id, int timestamp) {
    return _db.update(
      'credentials',
      {
        'last_used_at': timestamp,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteAll() {
    return _db.delete('credentials');
  }
}
