# WebDAV 云同步迁移实现文档

本文档基于 `MyPassword` 当前实现，整理一套可迁移到其他 Flutter 工程的 WebDAV 同步方案。

本文关注的能力包括：

- WebDAV 配置
- WebDAV 连接测试
- 上传加密同步包到 WebDAV
- 从 WebDAV 恢复同步包
- 本地变更后自动同步
- 同步状态记录
- 同步错误处理

本文默认前提：

- 你的应用已经具备“本地备份导出 / 导入”能力
- 你的备份文件本身已经是加密包，而不是明文数据库

如果还没有本地备份能力，可以先参考：

- [备份导入导出迁移指南.md](/Users/admin/Documents/mywork/cccli/MyPassword/docs/同步/备份导入导出迁移指南.md)

---

## 1. 目标方案定义

当前项目的 WebDAV 同步定义是：

- 用户自己填写自己的 WebDAV 网盘配置
- App 不托管用户数据
- App 只上传和下载“应用加密同步包”
- 同步包仍然沿用本地备份格式
- 恢复时下载同步包，再走现有导入逻辑

这套方案非常适合：

- 坚果云
- 支持 WebDAV 的 NAS
- 私有 WebDAV 服务
- 企业 WebDAV 文档服务

---

## 2. 整体架构

当前项目把 WebDAV 同步拆成 5 层。

### 1. UI 配置层

负责：

- 让用户填写 WebDAV 地址
- 用户名
- 应用密码
- 远端同步路径
- 测试连接
- 手动上传
- 手动恢复

对应代码：

- [webdav_sync_page.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/features/settings/presentation/pages/webdav_sync_page.dart)
- [settings_page.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/features/settings/presentation/pages/settings_page.dart)

### 2. 配置持久化层

负责：

- 保存 WebDAV 地址
- 保存用户名
- 保存远端路径
- 安全保存应用密码
- 保存同步状态

对应代码：

- [cloud_sync_repository_impl.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/data/cloud_sync/cloud_sync_repository_impl.dart)

### 3. 协调层

负责：

- 用当前主密码导出同步包
- 调用具体云提供方上传
- 下载远端同步包
- 记录同步成功时间和错误信息

对应代码：

- [cloud_sync_coordinator.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/domain/cloud_sync/cloud_sync_coordinator.dart)

### 4. 提供方层

负责：

- 具体实现 WebDAV 协议
- 发起 `PROPFIND` / `PUT` / `GET` / `DELETE` / `MKCOL`
- 解析元信息
- 创建远端目录

对应代码：

- [webdav_sync_provider.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/data/cloud_sync/providers/webdav/webdav_sync_provider.dart)

### 5. 自动同步策略层

负责：

- 本地数据变更后是否自动上传
- 首页是否提示远端有更新
- 本地和远端是否可能冲突

对应代码：

- [cloud_sync_automation_service.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/domain/cloud_sync/cloud_sync_automation_service.dart)

---

## 3. 核心设计原则

这套 WebDAV 同步方案的核心有 4 个原则。

### 1. 同步包沿用本地备份格式

不要专门为 WebDAV 设计另一套同步文件格式。

当前项目直接复用：

- `credentialRepository.exportBackup(...)`
- `credentialRepository.importBackup(...)`

也就是说：

- 上传到 WebDAV 的文件，本质就是应用现有的加密备份包
- 从 WebDAV 恢复时，下载后直接交给现有导入逻辑

优点：

- 实现简单
- 同步与备份格式统一
- 迁移到其他云盘时也能复用

### 2. WebDAV 配置与同步逻辑解耦

不要在页面里直接写 HTTP。

当前项目明确拆开：

- UI 页面只收集配置和触发动作
- 协调层只负责“同步流程”
- 提供方层只负责“WebDAV 协议实现”

这对迁移很重要，因为以后接入百度网盘时可以只换提供方层。

### 3. 应用密码存安全存储，不放 SharedPreferences

当前实现中：

- WebDAV 地址、用户名、远端路径放 `SharedPreferences`
- WebDAV 应用密码放 `SecureKeyStorage`

这样做更合理，因为：

- 用户名、地址不是高敏感信息
- 应用密码是高敏感信息，必须走安全存储

### 4. 自动同步不应阻塞本地操作

当前自动同步策略是：

- 本地保存成功优先
- 自动上传只是“尽力而为”
- 自动上传失败不让用户的本地保存一起失败

这非常重要。

否则用户在弱网环境下，新增一个条目都可能失败，体验会非常差。

---

## 4. 数据模型设计

当前同步配置数据模型位于：

- [cloud_sync_models.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/domain/cloud_sync/cloud_sync_models.dart)

### 4.1 WebDAV 配置

```dart
class WebDavConfig {
  final String baseUrl;
  final String username;
  final String appPassword;
  final String remotePath;
}
```

字段含义：

- `baseUrl`
  - WebDAV 根地址
  - 例如：`https://dav.jianguoyun.com/dav/`
- `username`
  - WebDAV 用户名
- `appPassword`
  - WebDAV 应用密码
- `remotePath`
  - 远端同步包路径
  - 例如：`/MyPassword/vault_sync.mpsync`

### 4.2 通用同步配置

```dart
class CloudSyncConfig {
  final CloudSyncProviderType providerType;
  final String remotePath;
  final WebDavConfig? webDavConfig;
}
```

这样做是为以后多云盘预留扩展位。

### 4.3 同步状态快照

```dart
class SyncStatusSnapshot {
  final bool isConfigured;
  final RemoteSyncPackageMeta? lastRemoteMeta;
  final DateTime? lastLocalChangeAt;
  final DateTime? lastUploadedAt;
  final DateTime? lastDownloadedAt;
  final String? lastError;
}
```

这个结构后续可以直接用于：

- 设置页显示同步状态
- 首页远端更新提示
- 自动同步冲突检测

---

## 5. WebDAV 配置持久化方案

配置保存逻辑位于：

- [cloud_sync_repository_impl.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/data/cloud_sync/cloud_sync_repository_impl.dart)

### 5.1 SharedPreferences 保存字段

当前使用这些 key：

- `cloud_sync.provider_type`
- `cloud_sync.webdav.base_url`
- `cloud_sync.webdav.username`
- `cloud_sync.webdav.remote_path`

### 5.2 Secure Storage 保存字段

WebDAV 应用密码保存在：

- `secure.webdav_app_password`

对应代码在：

- [secure_key_storage.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/security/storage/secure_key_storage.dart)

### 5.3 为什么这样拆

推荐迁移时也保持这个拆法：

- 普通配置：SharedPreferences
- 密码：安全存储

这样可以减少安全风险，也便于调试和管理。

---

## 6. WebDAV 连接测试实现方法

### 6.1 UI 层

当前配置页提供：

- 保存
- 测试连接

测试连接成功后会自动保存配置。

对应代码：

- [webdav_sync_page.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/features/settings/presentation/pages/webdav_sync_page.dart)

### 6.2 Provider 层测试实现

当前 WebDAV 连接测试使用：

- `PROPFIND` 请求根地址

具体方法：

```dart
validateConnectionWithConfig(WebDavConfig config)
```

执行流程：

1. 用用户填写的 `baseUrl` 建立请求
2. 发送 `PROPFIND`
3. 带上 Basic Auth
4. 请求成功则视为连接可用

### 6.3 为什么用 PROPFIND

因为 WebDAV 本身就是基于这些扩展方法工作的。

相比单纯 GET：

- `PROPFIND` 更能代表 WebDAV 服务是否真的可用

---

## 7. WebDAV 上传同步包实现方法

### 7.1 协调层入口

上传入口定义在：

- [cloud_sync_coordinator.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/domain/cloud_sync/cloud_sync_coordinator.dart)

核心方法：

```dart
uploadCurrentVault({
  required String currentMasterPassword,
})
```

### 7.2 上传流程

当前完整流程如下：

1. 读取当前同步配置
2. 检查配置是否合法
3. 调 `credentialRepository.exportBackup(currentMasterPassword: ...)`
4. 得到加密同步包字节
5. 调 `provider.uploadPackage(...)`
6. 上传成功后记录最近上传时间
7. 失败则记录错误码

这说明 WebDAV 上传不是直接上传数据库，而是上传“加密同步包”。

### 7.3 WebDAV 提供方的上传实现

位于：

- [webdav_sync_provider.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/data/cloud_sync/providers/webdav/webdav_sync_provider.dart)

当前上传实现有两个关键点。

#### 1. 自动创建远端目录

上传前会调用：

```dart
_ensureRemoteDirectoryExists(config, upload.path)
```

它会：

- 解析远端文件路径的目录部分
- 逐级发 `MKCOL`
- 目录已存在时继续

这个设计是必要的，因为很多 WebDAV 服务：

- 根地址可连接
- 但目标子目录如果不存在，直接 `PUT` 会失败

#### 2. 真正上传

目录准备好以后，再发送：

- `PUT`

请求内容就是加密同步包字节。

---

## 8. WebDAV 恢复同步包实现方法

### 8.1 手动恢复入口

设置页提供：

- 从 WebDAV 恢复

对应代码：

- [settings_page.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/features/settings/presentation/pages/settings_page.dart)

### 8.2 恢复流程

当前恢复流程是：

1. 用户输入备份文件主密码
2. 调 `cloudSyncCoordinator.downloadLatestPackage()`
3. 下载远端同步包字节
4. 写到临时文件
5. 调 `credentialRepository.verifyBackupPassword(...)`
6. 校验通过后执行 `importBackup(...)`

这说明恢复并不是“下载后直接覆盖数据库”，而是：

- 下载同步包
- 按本地备份导入规则恢复

这个设计非常适合迁移，因为：

- 云恢复和本地导入共用同一套数据入口

### 8.3 恢复为什么仍要用户输入备份主密码

因为同步包本身是加密的。

当前项目要求：

- 恢复时必须由用户手动提供同步包主密码
- 应用只用同步包里的 `masterPasswordVerifier` 做校验

也就是说：

- App 不会在云端托管解密密码
- App 也不会自动保存这份远端备份的解密密码

---

## 9. 自动同步策略实现方法

自动同步策略位于：

- [cloud_sync_automation_service.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/domain/cloud_sync/cloud_sync_automation_service.dart)

### 9.1 本地变更触发自动上传

核心入口：

```dart
notifyLocalVaultChanged()
```

执行逻辑：

1. 记录最近本地变更时间
2. 检查设置中是否开启“本地变更后自动同步”
3. 从当前会话读取主密码
4. 如果能拿到主密码，就自动上传
5. 上传失败时吞掉异常，不影响本地操作

### 9.2 为什么自动同步依赖当前会话主密码

因为同步包导出仍然依赖：

- `exportBackup(currentMasterPassword: ...)`

所以自动上传必须满足：

- 当前会话里有主密码

这也是为什么当前项目里：

- 普通主密码解锁后能自动同步
- 生物识别解锁后不能自动上传

因为生物识别解锁场景下没有重新输入主密码。

### 9.3 自动同步的触发点

当前已接入这些本地变更场景：

- 新增条目
- 编辑条目
- 删除条目
- 导入备份
- 修改主密码

这是一种比较务实的第一期策略。

---

## 10. 首页远端更新提示实现方法

当前项目在首页会检查：

- WebDAV 上是否存在较新的同步包
- 本地是否有尚未上传的变更

如果检测到：

- 远端更新比本地同步时间更新，则提示远端有更新
- 远端更新且本地也有未上传变化，则提示可能有冲突

相关实现位于：

- [cloud_sync_automation_service.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/domain/cloud_sync/cloud_sync_automation_service.dart)
- [home_page.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/features/home/presentation/pages/home_page.dart)

这个机制迁移时非常值得保留，因为它能避免用户无感知地把远端新数据覆盖掉。

---

## 11. WebDAV 错误处理方案

当前项目统一定义了同步错误码：

- `notConfigured`
- `providerUnavailable`
- `authenticationFailed`
- `remoteFileNotFound`
- `networkError`
- `invalidConfiguration`
- `invalidMasterPassword`
- `invalidBackupPassword`
- `unknown`

定义位于：

- [cloud_sync_provider.dart](/Users/admin/Documents/mywork/cccli/MyPassword/lib/domain/cloud_sync/cloud_sync_provider.dart)

### 11.1 为什么需要统一错误码

因为 UI 不能直接依赖：

- SocketException
- HttpException
- WebDAV 状态码

如果直接把底层异常透出到页面，后续你换百度网盘、S3、OneDrive 时，页面层会变得非常混乱。

统一错误码后：

- 页面只关心“认证失败 / 网络失败 / 文件不存在”
- 提供方层自己处理底层协议差异

### 11.2 当前 WebDAV 错误映射

当前已经覆盖的典型场景：

- `401 / 403` -> `authenticationFailed`
- 网络 Socket / TLS -> `networkError`
- `404` -> `remoteFileNotFound`
- URL 或路径问题 -> `invalidConfiguration`

这套映射模式迁移到其他项目时建议保留。

---

## 12. 配置页和设置页的交互方案

### 12.1 WebDAV 配置页

当前提供：

- 地址输入
- 用户名输入
- 应用密码输入
- 远端同步路径输入
- 保存
- 测试连接

并且：

- 测试连接成功后会自动保存当前配置

### 12.2 设置页手动同步入口

当前设置页提供：

- 上传到 WebDAV
- 从 WebDAV 恢复

并且已经补充：

- 上传 / 恢复时显示进行中的阻塞对话框
- 完成后再提示成功或失败

这套交互是比较适合第一期上线的。

---

## 13. 迁移到其他项目时建议保留的接口边界

如果你准备把 WebDAV 同步迁移到其他工程，建议保留以下抽象。

### 1. `CloudSyncProvider`

建议保留一个统一接口：

```dart
abstract class CloudSyncProvider {
  Future<bool> isConfigured();
  Future<void> validateConnection();
  Future<RemoteSyncPackageMeta?> getRemoteMeta();
  Future<void> uploadPackage(SyncPackageUpload upload);
  Future<DownloadedSyncPackage?> downloadPackage(String path);
  Future<void> deletePackage(String path);
}
```

这样未来新增其他云盘时，只要增加新 provider 实现即可。

### 2. `CloudSyncCoordinator`

建议保留一个协调层，专门处理：

- 本地备份导出
- 提供方上传
- 提供方下载
- 同步状态落库

不要让页面自己拼这些逻辑。

### 3. `CloudSyncRepository`

建议用单独的配置仓储管理：

- 配置持久化
- 同步状态
- 最近错误

### 4. `CloudSyncAutomationService`

建议把自动同步策略也独立出来，不要散落到各页面里。

---

## 14. 迁移实施步骤建议

如果在新项目中从零实现 WebDAV 同步，建议按下面顺序推进。

### 第一步：先完成本地备份能力

必须先有：

- 导出加密同步包
- 导入加密同步包
- 备份密码校验

### 第二步：定义同步抽象层

先写：

- `CloudSyncProvider`
- `CloudSyncCoordinator`
- `CloudSyncRepository`

### 第三步：实现 WebDAV Provider

优先支持：

- `validateConnection`
- `uploadPackage`
- `downloadPackage`
- `getRemoteMeta`

### 第四步：做配置页

配置项包括：

- 地址
- 用户名
- 应用密码
- 远端同步路径

### 第五步：做手动上传 / 手动恢复

先把同步主链路跑通，再做自动同步。

### 第六步：做自动同步

建议第一期只做：

- 本地变更后自动上传
- 首页远端更新提示

### 第七步：做冲突处理

这部分复杂度最高，建议放到第二期。

---

## 15. 当前方案的局限

这套方案当前可用，但仍然有明确边界。

### 1. 只支持单文件同步包

当前策略是：

- 始终同步一个固定远端文件

这足够简单，但不支持：

- 多版本历史
- 回滚
- 并行设备变更分支

### 2. 生物识别解锁下不能自动上传

因为当前自动上传仍依赖主密码。

如果后续要解决，需要重新设计：

- 会话授权模型
- 同步包导出授权策略

### 3. 冲突处理还比较初级

目前只做到：

- 检测可能有冲突
- 提示用户手动处理

还没有：

- 合并策略
- 覆盖策略
- 可视化冲突页

### 4. 当前只实现 WebDAV

未来接入百度网盘等非 WebDAV 服务时：

- Provider 层需要重新实现
- 但上层协调层和自动同步策略仍可复用

---

## 16. 结论

当前 `MyPassword` 的 WebDAV 同步方案，本质上是：

- 用本地备份格式作为统一同步包
- 用 WebDAV 作为远端文件存储通道
- 用协调层把本地备份与远端同步动作串起来
- 用自动同步策略补上基础体验

这套方案适合迁移到其他项目的原因是：

- 结构清晰
- 业务层和协议层边界明确
- 后续扩展多云盘时可复用大部分代码
- 不依赖自建后端

如果你后续要继续，我建议下一份文档可以补：

1. WebDAV 同步时序图
2. 同步状态页设计文档
3. 第二期多云盘接入抽象设计文档
