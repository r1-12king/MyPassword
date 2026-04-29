# MyPassword

Local-first password manager MVP built with Flutter.

## Current Status

The project already includes the main MVP backbone:

- master password vault setup and unlock
- local encrypted credential storage with SQLite
- credential create, edit, view, search, and delete
- password generator
- encrypted backup export and import
- biometric unlock entry point
- English and Chinese localization

This is still an MVP-in-progress, not a production-hardened password manager.

## Tech Stack

- Flutter
- Riverpod
- go_router
- sqflite
- flutter_secure_storage
- local_auth
- cryptography

## Project Structure

```text
lib/
  app/          app shell and routing
  bootstrap/    app initialization and dependency wiring
  core/         shared constants and localization
  data/         database, DAO, repository implementations
  domain/       repository interfaces and domain models
  features/     UI pages grouped by feature
  security/     crypto, biometric, and secure storage services
  shared/       global providers
```

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter analyze
```

## Notes

- Vault data is stored locally on device.
- Sensitive credential fields are encrypted before writing to SQLite.
- The current biometric flow is implemented for MVP convenience and should be reviewed further before any production release.
- There are currently no automated tests under `test/`.

## Docs

Detailed design notes live under `docs/`, including:

- `docs/文档索引.md`
- `docs/架构/系统架构.md`
- `docs/架构/Android密码管理器MVP方案.md`
- `docs/数据安全/加密服务设计草稿.md`
- `docs/数据安全/保险库仓储设计草稿.md`
- `docs/项目/升级日志.md`
- `docs/项目/开发规范.md`
- `docs/项目/当前版本待办清单.md`
- `docs/同步/备份导入导出迁移指南.md`
- `docs/同步/WebDAV云同步迁移实现文档.md`
- `docs/同步/多云盘统一抽象设计文档.md`
