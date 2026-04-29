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
      onCreate: (db, version) => DbMigrations.onCreate(db),
      onUpgrade: (db, oldVersion, newVersion) =>
          DbMigrations.onUpgrade(db, oldVersion, newVersion),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
