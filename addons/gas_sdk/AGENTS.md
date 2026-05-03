# GAS SDK — 云服务集成

## 概览

GAS（Game Achievement Service）云服务 SDK。42 个 GD 脚本，提供 OAuth 登录、云端存档、用户配置等功能。

## 架构

```
gas_sdk/
├── GAS/
│   ├── Service/        # 业务服务层（7 个服务）
│   ├── Models/         # 请求/响应模型（7 个模块）
│   ├── Network/        # HTTP 客户端 + 加密
│   ├── Common/         # 通用工具
│   ├── Config/         # 配置管理
│   ├── Enum/           # 枚举定义
│   └── Handler/        # 浏览器处理器
├── Demo/               # 演示场景
├── Resources/          # GASConfig.tres
└── plugin.gd           # 编辑器插件入口
```

## 服务层（Service/）

| 服务 | 职责 |
|------|------|
| `OAuthService` | OAuth 认证流程（auth_token → exchange → logout） |
| `ArchiveService` | 云端存档（读/写/删） |
| `AutoLoginService` | 自动登录 |
| `ProfileService` | 用户资料 |
| `ConfigService` | 应用配置 |
| `RedeemService` | 兑换码 |
| `VersionService` | 版本检查 |

## 模型层（Models/）

每个模块包含 `*Req.gd`（请求）和 `*Resp.gd`（响应）：

- `OAuth/` — OAuthAuthTokenReq/Resp, OAuthExchangeReq, OAuthAccessResp, OAuthLogoutReq/Resp
- `Archive/` — ArchiveReadReq/Resp, ArchiveSaveReq/Resp, ArchiveDeleteReq/Resp
- `AutoLogin/` — AutoLoginReq/Resp
- `Config/` — ConfigReq/Resp
- `Profile/` — ProfileReq/Resp
- `Redeem/` — RedeemAnonymousReq, RedeemWithAccountReq, RedeemResp
- `Version/` — VersionReq/Resp

## 网络层（Network/）

- `GASHttpClient` — HTTP 请求封装
- `GASEncryption` — 加密工具
- `GASApiRoute` — API 路由常量

## 使用模式

```gdscript
# 服务调用模式
var service := OAuthService.new()
var result := await service.get_auth_token()
if result is GASError:
    push_error(result.message)
else:
    var resp: OAuthAuthTokenResp = result
    # 处理成功响应
```

## 关键流程

1. **OAuth 登录**：`OAuthService.get_auth_token()` → 浏览器授权 → `exchange_auth_token()`
2. **存档同步**：`ArchiveService` 读写存档，`CloudArchiveService`（autoload）管理同步
3. **配置保存**：凭证存储到 `user://gas_config.cfg`

## 注意事项

- 所有服务方法返回 `Variant`，需检查 `is GASError`
- 响应模型继承自公共基类，通过 `GASResponseChecker.ensure_success()` 验证
- 加密使用 `GASEncryption.encrypt()` 处理敏感数据