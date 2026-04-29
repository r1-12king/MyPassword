import 'package:sqflite/sqflite.dart';

abstract final class DbMigrations {
  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE vault_meta (
        id TEXT PRIMARY KEY NOT NULL,
        vault_name TEXT,
        master_password_kdf TEXT NOT NULL,
        kdf_memory_kb INTEGER NOT NULL,
        kdf_iterations INTEGER NOT NULL,
        kdf_parallelism INTEGER NOT NULL,
        salt_base64 TEXT NOT NULL,
        wrapped_vault_key_base64 TEXT NOT NULL,
        vault_version INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE credentials (
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
      CREATE TABLE import_history (
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

    await db.execute(
      'CREATE INDEX idx_credentials_title ON credentials(title)',
    );
    await db.execute(
      'CREATE INDEX idx_credentials_website_domain ON credentials(website_domain)',
    );
    await db.execute(
      'CREATE INDEX idx_credentials_favorite ON credentials(favorite)',
    );
    await db.execute(
      'CREATE INDEX idx_credentials_updated_at ON credentials(updated_at)',
    );
    await db.execute(
      'CREATE INDEX idx_credentials_last_used_at ON credentials(last_used_at)',
    );
    await db.execute(
      'CREATE INDEX idx_credentials_deleted_at ON credentials(deleted_at)',
    );
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Future migration placeholder.
    }
  }
}
