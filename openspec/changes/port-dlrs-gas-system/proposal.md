## Why

GodotLineCollection 没有用户账号和在线服务。以 GASNetwork（Unity C# SDK）为蓝本，移植为 Godot 4 GDScript SDK addon，开发者通过 Inspector 配置 appid/apptoken，实例化无状态服务即可使用。同时提供游戏集成（登录场景 + 存档同步），像 GASNetwork Demo 一样对接 SDK。

## What Changes

**SDK addon（以 GASNetwork 为主）：**
- `GASConfig` Resource（等价 GASNetwork 的 ScriptableObject）—— Inspector 配置 appid/appToken
- `GASConfigManager` 静态访问器（lazy-load + lang 设置）
- `GASEncryption` —— AES-256-CBC，SHA-256 key derivation，零 IV（与 GASNetwork 完全一致）
- `GASHttpClient` —— POST/GET，JSON 序列化，响应检查，日志（等价 GASNetwork 的 UnityWebRequest + UniTask 模式）
- `GASApiRoute` —— 端点常量（与 GASNetwork 一致）
- `GASResponseChecker` / `GASResponseLogger` / `GASError` —— 等价 GASNetwork 的 Common 层
- `GASBrowserHandler` —— 打开授权浏览器/注册/服务条款
- `GASLang` —— zh/en 枚举
- Typed Models（Request/Response 类，等价 GASNetwork 的 Models 层）
- Services：`OAuthService` / `AutoLoginService` / `ProfileService` / `ArchiveService` / `VersionService` / `RedeemService` / `ConfigService`（方法签名对齐 GASNetwork）
- Demo 场景（等价 GASNetwork Demo）

**游戏集成：**
- 登录场景（像 GASDemo 一样用 SDK 服务，加上 UI 和 token 持久化）
- CloudArchiveService autoload（sync-on-login、debounced save、conflict resolution）
- LevelManager 对接

## Capabilities

### New Capabilities
- `gas-sdk`: 完整 GAS SDK addon，以 GASNetwork 为蓝本移植到 GDScript——Config、Encryption、Http、ApiRoute、Common、Lang、Handler、Models、Services、Demo
- `gas-game-integration`: 游戏集成——登录场景、CloudArchiveService autoload、LevelManager 对接

### Modified Capabilities
(无)

## Impact

- **New addon**: `addons/gas_sdk/` —— 可复用 SDK，无游戏依赖
- **New game scripts**: `Scripts/gas/` —— 登录、CloudArchiveService
- **New autoload**: `CloudArchiveService`
- **Modified scene**: `Scenes/LevelManager.tscn` —— 加登录按钮
- **API dependencies**: `api.chinadlrs.com` / `gas.chinadlrs.com`
