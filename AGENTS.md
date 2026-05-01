# AGENTS.md

## 项目概览

Godot 4.6 游戏关卡集合/启动器。通过 PCK 文件动态加载用户关卡，使用 GAS SDK 云端存档。

## 代码规范：必须使用静态类型

所有变量必须显式声明类型：

```gdscript
var speed: float = 12.0
var levels: Array[MenuLevelData] = []
var _email: String = ""
var config := GASLoginConfig.new()
```

- 用 `:=` 做类型推断（等号右边类型明确时）
- `class_name` 声明可复用类
- `@tool` 标注编辑器运行的脚本
- `@onready var node: Type = $Path` 显式类型声明节点引用
- 缩进使用 Tab，非空格

## 目录结构

- `Scripts/` — 主应用脚本（菜单 UI、云存档、登录）
- `#Template/[Scripts]/` — 游戏模板核心逻辑（Player、LevelManager、Trigger 等）
- `addons/PCKManager/` — PCK 导出与管理编辑器插件（不再注册 autoload）
- `addons/gas_sdk/` — GAS 云服务 SDK（OAuth、存档、配置）
- `addons/ugc_import/` — 编辑器 UGC 关卡导入工具，导入时自动生成 `level_list.tres`
- `Scenes/` — `LevelManager.tscn` 菜单主场景，`gas_login.tscn` 登录
- `pck_levels/` — 关卡 PCK 文件 + `level_list.tres`（`MenuLevelList` 资源）

## 关键架构点

- **PCK 加载流程**：菜单启动时不预加载 PCK。用户点击关卡时按需 `ProjectSettings.load_resource_pack()`，PCK 内场景路径用 `change_scene_to_file` 直接跳转，不检查 `ResourceLoader.exists`（PCK 内路径无法预检）
- **封面和音乐**：存在 `level_list.tres` 的 `MenuLevelData` 资源里（`@export`），不依赖 PCK 加载
- **UGC 导入**：`ugc_import` 插件验证 PCK 时提取 `scene_path`，导入后自动 `_upsert_level_list` 写入/更新 `level_list.tres`
- `LevelManager`（Template `#Template/`）是 static 单例（`RefCounted`），管理全局游戏状态，不是 Node
- `Player` 使用 `static var instance: Player` 全局引用
- GAS 登录流程：OAuth → 浏览器授权 → 轮询 exchange → 保存凭证到 `user://gas_config.cfg`

## Autoload 单例

- `CloudArchiveService` (`Scripts/gas/cloud_archive_service.gd`) — 云端存档同步
- ~~`PCKLoader`~~ — 已移除 autoload，PCK 由菜单按需加载

## UI 布局陷阱

- **不要在 `TextureRect` 外包 `CenterContainer`**：`CenterContainer` 不会让子节点拉伸，`expand_mode`/`size_flags` 全部失效，图片只显示最小尺寸。`TextureRect` 应直接放在 `PanelContainer` 下

## 开发命令

- 无 CLI 构建/测试/lint 脚本，所有操作通过 Godot 编辑器完成

## OpenSpec 工作流

- `/opsx-propose` — 提案新变更
- `/opsx-apply` — 实施变更任务
- `/opsx-archive` — 归档完成的变更
- `/opsx-explore` — 探索模式（需求澄清）
