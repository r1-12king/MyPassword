import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

abstract class ImportHistoryDao {
  Future<void> insert(Map<String, Object?> row);
  Future<void> updateStatus(
    String id, {
    required String status,
    int? importedCount,
    int? skippedCount,
    int? failedCount,
    int? completedAt,
  });
  Future<List<Map<String, Object?>>> getRecent({int limit = 20});
}

class ImportHistoryDaoImpl implements ImportHistoryDao {
  ImportHistoryDaoImpl(this._database);

  final AppDatabase _database;

  Database get _db => _database.instance;

  @override
  Future<void> insert(Map<String, Object?> row) {
    return _db.insert(
      'import_history',
      row,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateStatus(
    String id, {
    required String status,
    int? importedCount,
    int? skippedCount,
    int? failedCount,
    int? completedAt,
  }) {
    final values = <String, Object?>{
      'status': status,
      if (importedCount != null) 'imported_count': importedCount,
      if (skippedCount != null) 'skipped_count': skippedCount,
      if (failedCount != null) 'failed_count': failedCount,
      if (completedAt != null) 'completed_at': completedAt,
    };

    return _db.update(
      'import_history',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Map<String, Object?>>> getRecent({int limit = 20}) {
    return _db.query(
      'import_history',
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }
}
