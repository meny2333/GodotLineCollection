## Context

以 GASNetwork（`D:\Code\dl\GASNetwork`）为主移植。GASNetwork 是一个 Unity C# SDK，结构清晰：

```
GAS/
├── Common/       # GASException, GASCommonResp<T>, GASResponseChecker, GASResponseLogger
├── Config/       # GASConfig (ScriptableObject), GASConfigManager (static)
├── Enum/         # GASLang
├── Handler/      # GASBrowserHandler
├── Models/       # OAuth/, AutoLogin/, Profile/, Archive/, Version/, Redeem/, Config/
├── Network/      # GASHttpClient, GASEncryption, GASApiRoute
└── Service/      # OAuthService, AutoLoginService, ProfileService, ArchiveService, VersionService, RedeemService, ConfigService
Demo/             # GASDemo.cs — 示例用法
Resources/        # GASConfig.asset — 模板配置
```

**Godot 4 映射：**

| Unity (GASNetwork) | Godot 4 |
|---|---|
| `ScriptableObject` | `Resource` (.tres) |
| `Resources.Load<T>()` | `ResourceLoader.load()` |
| `UniTask<T>` | `await` on signal |
| `[JsonProperty("x")]` | `@export` + 手动 JSON 映射 |
| `GASCommonResp<T>` 泛型 | 每个 Resp 类内联 code/msg/data 字段（GDScript 无泛型） |
| `GASException` throw | `GASError` 返回值（GDScript 无异常机制） |
| `UnityWebRequest` | `HTTPRequest` node |

**目标项目现状：**
- 无账号/auth 代码
- Autoloads: `PCKLoader`
- 现有 addons: `PCKManager/`, `ugc_import/`

## Goals / Non-Goals

**Goals:**
- 以 GASNetwork 为蓝本，1:1 移植为 Godot 4 GDScript SDK addon
- SDK 方法签名、字段名、加密逻辑与 GASNetwork 保持一致
- 游戏集成层尽量薄，像 GASDemo 一样直接用 SDK
- Demo 场景演示 SDK 用法

**Non-Goals:**
- LeanCloud 旧版登录
- 调试管理 UI
- Editor 插件面板
- 旧版 `[Obsolete]` 方法（不移植 AutoLoginAsyncOld 等）

## Decisions

### D1: 目录结构 — 1:1 映射 GASNetwork

**Choice**: `addons/gas_sdk/GAS/` 下按 GASNetwork 同样结构组织（Common/、Config/、Enum/、Handler/、Models/、Network/、Service/），Demo/ 和 Resources/ 同级。
**Rationale**: 与 GASNetwork 一致，方便对照和维护。

### D2: 泛型响应 — 每个Resp类内联code/msg/data

**Choice**: 每个 Response 类包含 `code: int`、`msg: String`、`data: Dictionary` 字段，不尝试模拟 C# 泛型。
**Rationale**: GDScript 无泛型。内联字段最简单直接，data 作为 Dictionary 由调用方按需取字段。与 GASNetwork 的 `GASCommonResp<T>` 等价但适配 GDScript。

### D3: 异常 → GASError 返回值

**Choice**: 用 `GASError`（code + message + raw_text）替代 C# 异常。Service 方法在失败时返回 `GASError`，成功时返回对应 Resp 类。用 `is GASError` 检查。
**Rationale**: GDScript 无 try/catch 异常机制。返回错误对象是 GDScript 惯用模式。等价于 GASNetwork 的 `GASResponseChecker.EnsureSuccess()` 抛异常，只是改用返回值。

### D4: 异步 — await on internal HTTPRequest signal

**Choice**: `GASHttpClient.post()` 和 `GASHttpClient.get()` 返回值通过 `await` 获取。内部创建临时 HTTPRequest node，request_completed 信号 await 后返回解析结果，然后 queue_free。
**Rationale**: 等价 GASNetwork 的 `await _http.PostAsync<T>()`。Godot 4 的 `await` + signal 是标准异步模式。

### D5: GASConfig — Resource + GASConfigManager 静态访问

**Choice**: `GASConfig extends Resource`，`@export var app_id: int`、`@export var app_token: String`。`GASConfigManager` 从 `res://addons/gas_sdk/Resources/GASConfig.tres` lazy-load。
**Rationale**: 直接等价 GASNetwork 的 ScriptableObject + Resources.Load 模式。

### D6: GASEncryption — 与 GASNetwork 完全一致

**Choice**: 只实现 GASNetwork 有的：`Encrypt(plainText, rawKey)` + `Decrypt(cipherText, rawKey)` + `DeriveKeyBytes(rawKey)`。AES-256-CBC，SHA-256 key，零 IV。
**Rationale**: 加密必须与服务端兼容。GASNetwork 的实现是规范。不添加源 GDScript 版的 OpenSSL Salted 等额外功能。

### D7: Services 方法签名 — 对齐 GASNetwork

**Choice**: 方法名和参数与 GASNetwork 一致：
- `OAuthService.get_auth_token()` / `exchange_auth_token(auth_token)` / `logout(email, access_token)`
- `AutoLoginService.auto_login(email, access_token)`
- `ProfileService.get_profile(email, access_token)`
- `ArchiveService.read(email, access_token)` / `save(email, access_token, version, plain_content)` / `delete(email, access_token)` / `decrypt_archive_content(encrypted_content)`
- `VersionService.get_version(sequence)` / `decrypt_version(encrypted_content)`
- `RedeemService.redeem_anonymous(redeem_code)` / `redeem_with_account(email, access_token, redeem_code)` / `decrypt_redeem_content(encrypted_content)`
- `ConfigService.get_config()` / `decrypt_config(encrypted_config)`

**Rationale**: 1:1 对齐 GASNetwork，开发者迁移零学习成本。

### D8: 游戏集成 — 薄层，像 GASDemo 一样用 SDK

**Choice**: 登录场景直接实例化 SDK Service（如 GASDemo），加上 UI 和 token 持久化。CloudArchiveService autoload 封装 sync/debounce/conflict 逻辑。
**Rationale**: GASNetwork Demo 展示了正确用法。游戏层不应重新实现 SDK 已有的功能。

### D9: GASResponseLogger — 保留日志功能

**Choice**: 移植 GASNetwork 的请求/响应日志，用 Godot 的 `print`/`push_warning`/`push_error`。
**Rationale**: 调试必备。GASNetwork 始终开启日志。

## Risks / Trade-offs

- **[Risk] GDScript 无泛型** → 每个 Resp 类内联 code/msg/data。字段访问用 Dictionary key，无编译期类型检查。需文档说明 data 结构。
- **[Risk] HTTPRequest 生命周期** → 每次请求创建临时 node，await 后 queue_free。需确保无泄漏。
- **[Risk] 无异常机制** → 返回 GASError。开发者需习惯 `if resp is GASError` 检查。
