# DAO 接口与建表 SQL 最终版

## 1. 文档目标

本文档是当前密码管理器 MVP 的本地数据库最终落地稿，统一以下内容：

- MVP 最终表范围
- 建表 SQL
- 索引 SQL
- DAO 接口定义
- `sqflite` 落地建议
- 与 Repository 的协作边界

这份文档的定位是：

- 可以直接据此开始实现 `sqflite`
- 不再停留在概念层
- 优先服务于当前 MVP

## 2. MVP 最终表范围

当前 MVP 只保留 3 张核心表：

1. `vault_meta`
2. `credentials`
3. `import_history`

说明：

- `tags`、`credential_tags` 暂不进入第一版
- `app_settings` 建议先放 `shared_preferences` 或后续 DataStore 等配置层，不放进 SQLite
- `credential_usage` 暂时用 `credentials.last_used_at` 代替
- `autofill_match` 留到自动填充阶段再加

这样可以避免一开始把表设计铺得太大。

## 3. 数据库命名约定

推荐常量：

```dart
abstract final class DbConstants {
  static const dbName = 'my_password.db';
  static const dbVersion = 1;

  static const vaultMetaTable = 'vault_meta';
  static const credentialsTable = 'credentials';
  static const importHistoryTable = 'import_history';
}
```

命名原则：

- 表名使用小写下划线
- 列名使用小写下划线
- 时间统一使用 `INTEGER` 存毫秒时间戳
- 布尔值统一使用 `INTEGER` 的 `0 / 1`

## 4. MVP 最终建表 SQL

### 4.1 `vault_meta`

用途：

- 保存保险库元信息
- 保存 KDF 参数
- 保存 wrapped vault key

最终 SQL：

```sql
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
);
```

字段说明：

- `id`: 建议固定为 `default_vault`
- `vault_name`: 预留展示名，可为空
- `master_password_kdf`: 当前建议 `argon2id`
- `salt_base64`: 主密码派生盐值
- `wrapped_vault_key_base64`: 被主密码派生密钥包裹后的 vault key
- `vault_version`: 用于 vault 格式演进

说明：

- 这张表在 MVP 逻辑上只会有 1 条记录

### 4.2 `credentials`

用途：

- 保存密码条目主数据

最终 SQL：

```sql
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
);
```

字段说明：

- `title`: 明文，用于搜索和列表展示
- `username_ciphertext`: 密文
- `password_ciphertext`: 密文，必填
- `notes_ciphertext`: 密文
- `website_url`: 原始链接
- `website_domain`: 规范化域名，明文，用于搜索和后续 autofill 匹配
- `favorite`: 收藏标记
- `category`: 轻量分类
- `last_used_at`: 最近使用时间
- `deleted_at`: 软删除时间
- `version`: 为后续同步预留

### 4.3 `import_history`

用途：

- 记录导入行为

最终 SQL：

```sql
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
);
```

字段说明：

- `source_type`: 如 `chrome_csv`、`bitwarden_csv`
- `status`: `running`、`completed`、`failed`

## 5. 索引 SQL 最终版

### `credentials` 索引

```sql
CREATE INDEX idx_credentials_title
ON credentials(title);

CREATE INDEX idx_credentials_website_domain
ON credentials(website_domain);

CREATE INDEX idx_credentials_favorite
ON credentials(favorite);

CREATE INDEX idx_credentials_updated_at
ON credentials(updated_at);

CREATE INDEX idx_credentials_last_used_at
ON credentials(last_used_at);

CREATE INDEX idx_credentials_deleted_at
ON credentials(deleted_at);
```

索引说明：

- `title`: 支撑搜索
- `website_domain`: 支撑搜索与后续 autofill
- `favorite`: 支撑收藏筛选
- `updated_at`: 支撑最近修改排序
- `last_used_at`: 支撑最近使用排序
- `deleted_at`: 支撑软删除过滤

说明：

- SQLite 不支持像 PostgreSQL 那样的 partial index 写法作为 MVP 必需前提
- 所以直接给 `deleted_at` 建普通索引即可

## 6. 初始化 SQL 汇总

推荐 `onCreate()` 顺序：

```sql
CREATE TABLE vault_meta (...);
CREATE TABLE credentials (...);
CREATE TABLE import_history (...);

CREATE INDEX idx_credentials_title ON credentials(title);
CREATE INDEX idx_credentials_website_domain ON credentials(website_domain);
CREATE INDEX idx_credentials_favorite ON credentials(favorite);
CREATE INDEX idx_credentials_updated_at ON credentials(updated_at);
CREATE INDEX idx_credentials_last_used_at ON credentials(last_used_at);
CREATE INDEX idx_credentials_deleted_at ON credentials(deleted_at);
```

## 7. `sqflite` Migration 建议

推荐结构：

```dart
abstract final class DbMigrations {
  static Future<void> onCreate(Database db) async {}

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {}
}
```

建议规则：

- `dbVersion = 1` 对应当前 3 张表
- 新增字段或新表时只做增量迁移
- 不要在升级逻辑里重建整个数据库

未来典型迁移：

- `v2`: 增加 `autofill_match`
- `v3`: 增加 `totp` 支持字段或独立表
- `v4`: 增加同步元数据

## 8. DAO 设计原则

DAO 层只负责：

- 执行 SQL
- 返回原始记录
- 不做加密
- 不做 UI 友好模型映射

DAO 层不负责：

- 主密码校验
- 字段加解密
- 业务错误翻译
- 页面逻辑

Repository 层负责：

- 调用 DAO
- 调用 `CryptoService`
- 拼装领域模型

## 9. `VaultMetaDao` 最终接口

推荐接口：

```dart
abstract class VaultMetaDao {
  Future<bool> hasVault();

  Future<Map<String, Object?>?> getVaultMetaRow();

  Future<void> insertVaultMeta(Map<String, Object?> row);

  Future<void> deleteVaultMeta();
}
```

推荐实现行为：

### `hasVault()`

- 查询 `vault_meta`
- 取 1 条
- 只判断是否存在

### `getVaultMetaRow()`

- 查询 1 条保险库记录
- 若不存在返回 `null`

### `insertVaultMeta(row)`

- 使用 `ConflictAlgorithm.replace`

### `deleteVaultMeta()`

- 删除全部 `vault_meta` 记录

因为 MVP 只有一个 vault，这样足够。

## 10. `CredentialDao` 最终接口

推荐接口：

```dart
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
```

### `insert(row)`

- 插入新凭据
- 使用 `ConflictAlgorithm.abort`

原因：

- 新增不应该静默覆盖已有记录

### `update(id, row)`

- 仅更新指定记录
- 必须使用 `where: 'id = ?'`

### `getById(id)`

- 查询单条记录
- 建议默认也过滤 `deleted_at IS NULL`

### `queryActive(...)`

推荐过滤规则：

- `deleted_at IS NULL`
- 如果 `query` 非空：
  - `title LIKE ? OR website_domain LIKE ?`
- 如果 `favoritesOnly = true`
  - `favorite = 1`

推荐排序：

- 默认 `updated_at DESC`
- 后续可支持 `last_used_at DESC`

### `softDelete(id, deletedAt)`

- 设置：
  - `deleted_at = deletedAt`
  - `updated_at = deletedAt`

### `updateLastUsedAt(id, timestamp)`

- 设置 `last_used_at`

### `deleteAll()`

- 删除所有凭据
- 用于 `resetVault()`

## 11. `ImportHistoryDao` 最终接口

推荐接口：

```dart
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

  Future<List<Map<String, Object?>>> getRecent({
    int limit = 20,
  });
}
```

说明：

- 这张表当前不参与核心密码流程
- 但保留它对导入调试和后续可观测性有价值

## 12. DAO SQL 行为建议

### 12.1 `CredentialDao.queryActive()` 推荐 SQL 形态

无搜索条件：

```sql
SELECT *
FROM credentials
WHERE deleted_at IS NULL
ORDER BY updated_at DESC;
```

带搜索条件：

```sql
SELECT *
FROM credentials
WHERE deleted_at IS NULL
  AND (
    title LIKE ?
    OR website_domain LIKE ?
  )
ORDER BY updated_at DESC;
```

带收藏筛选：

```sql
SELECT *
FROM credentials
WHERE deleted_at IS NULL
  AND favorite = 1
ORDER BY updated_at DESC;
```

组合搜索 + 收藏：

```sql
SELECT *
FROM credentials
WHERE deleted_at IS NULL
  AND favorite = 1
  AND (
    title LIKE ?
    OR website_domain LIKE ?
  )
ORDER BY updated_at DESC;
```

## 13. `sqflite` 实现建议

### `VaultMetaDaoImpl`

建议骨架：

```dart
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
```

### `CredentialDaoImpl`

建议骨架：

```dart
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
    String orderBy = 'updated_at DESC',
  }) async {
    final where = <String>['deleted_at IS NULL'];
    final whereArgs = <Object?>[];

    if (favoritesOnly) {
      where.add('favorite = 1');
    }

    final normalizedQuery = query?.trim();
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
```

## 14. Repository 与 DAO 边界最终约定

最终约定如下：

### DAO 层

- 接收 `Map<String, Object?>`
- 返回 `Map<String, Object?>`
- 不知道密文含义
- 不知道业务模型

### Repository 层

- 决定何时调用 DAO
- 决定何时调用 `CryptoService`
- 决定如何把 DAO 结果映射成领域模型
- 决定错误如何转换

### UI 层

- 不直接接触 DAO
- 不直接接触数据库记录

## 15. 建议的 `onCreate()` 最终代码

```dart
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

    await db.execute('''
      CREATE INDEX idx_credentials_title
      ON credentials(title)
    ''');

    await db.execute('''
      CREATE INDEX idx_credentials_website_domain
      ON credentials(website_domain)
    ''');

    await db.execute('''
      CREATE INDEX idx_credentials_favorite
      ON credentials(favorite)
    ''');

    await db.execute('''
      CREATE INDEX idx_credentials_updated_at
      ON credentials(updated_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_credentials_last_used_at
      ON credentials(last_used_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_credentials_deleted_at
      ON credentials(deleted_at)
    ''');
  }
}
```

## 16. 最终建议

当前阶段建议你严格按这个最小组合落地：

- `vault_meta`
- `credentials`
- `import_history`
- `VaultMetaDao`
- `CredentialDao`
- `ImportHistoryDao`

不要一开始就加：

- tags
- autofill_match
- totp_secrets
- sync_change_log

因为这些都会分散实现重心。

## 17. 结论

这份最终版的核心原则只有三条：

1. `表先收敛`
2. `DAO 只做 SQL`
3. `加密和业务编排留在 Repository / Service`

按这份文档实现后，你就已经具备了真正开始写 Flutter MVP 数据层代码的稳定基线。
