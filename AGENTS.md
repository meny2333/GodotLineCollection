# AGENTS.md

GodotLineCollection 是一个 Godot 4.6 关卡合集 / 启动器：通过 PCK 动态加载用户关卡，使用 GAS SDK 做云端存档。本身不包含游戏主玩法——关卡内容来自外部 PCK 与上游 `godot-line` 模板仓库（本地镜像在 `#Template/`）。

## 代理强约束（必须遵守）

详见 `.opencode/agents/build.md`，要点：

- **禁止 Python**：不得用 `python/python3/pip/poetry/uv` 处理任何任务（解析 .osu、扫描资源、批处理、测试都不可）。改用 GDScript / godotmcp / bash。
- **优先 godotmcp**：对 Godot 项目（场景/节点/脚本/资源/项目设置/调试/运行测试）一律走 `addons/godot_mcp/` MCP 工具。godotmcp 不支持时才退回文件编辑或 bash，并在回复中说明。
- **任务闭环**：每个新需求或修 bug 必须按 `识别意图 → 写 todo → 启子代理 → review → 干活 → 子代理测试 → 收尾` 执行；纯问答/只读查阅不受此闭环约束，但仍禁 Python、仍优先 godotmcp。
- **不自行 commit/push**，除非用户明确要求。

## 开发命令

- 项目通过 Godot 编辑器运行，无 npm/cargo 风格脚本。`project.godot` 的 `run/main_scene="uid://4b0fo58iyn6m"` 即 `Scenes/LevelManager.tscn`。
- 验证改动：在 Godot 编辑器内运行主场景，或用 godotmcp 的调试/运行时工具。无单元测试框架。
- 无 lint/typecheck 命令；GDScript 风格遵循 [CONTRIBUTING.md](CONTRIBUTING.md)：变量/函数 `lowerCamelCase`、类名 `PascalCase`、常量 `UPPER_SNAKE_CASE`、信号 `lowerCamelCase`。
- 贡献流程：GitHub Flow，从 `master` 拉分支，分支名用 Issue 号（如 `GD-111`），PR 关联单一 Issue（见 [CONTRIBUTING.md](CONTRIBUTING.md)）。

## 关键架构边界

- `#Template/` 是上游 `godot-line` 模板的本地只读镜像（路径含方括号：`[Scenes]/`、`[Scripts]/`、`[Resources]/`、`[Music]/`、`[Materials]/`）。**禁止就地修改**；定制一律在 `Scripts/`、`Scenes/`、 autoload 中覆盖。
- `Scripts/GameUIHook.gd`（autoload）在运行时把模板原 `gameui` 节点替换为 `Scenes/CustomGameUI.tscn`，是为“不改 #Template 而定制 UI”的钩子模式示例。
- PCK 内场景/脚本路径用方括号记法，如 `#Template/[Scenes]/DefaultScene/Default.tscn`（见 `pck_levels/level_list.tres`）。

## Autoload 与静态类（容易踩错）

`project.godot` 的 `[autoload]`（运行期单例）：
- `GameUIHook` → `Scripts/GameUIHook.gd`
- `CloudArchiveService` → `Scripts/gas/cloud_archive_service.gd`
- `UserManager` → `Scripts/UserManager.gd`
- `LongSceneManager` → addon `long_scene_manager`
- `ImGuiRoot` / `ImGuiDebug` → imgui-godot 调试 UI
- `PopupToast` → `Scripts/PopupToast.gd`
- `HotUpdate` → `Scripts/hot_update.gd`（启动时加载 `res://patches`、可执行目录 `patches/`、`user://patches`，再按 manifest 拉远程 PCK）
- `MCPRuntimeProbe` → `addons/godot_mcp/runtime/mcp_runtime_probe.gd`

**不是 autoload、而是纯静态类**（`class_name X extends RefCounted`，按类名静态调用，不要 `get_node`）：
- `ProgressStore`（`Scripts/progress_store.gd`）关卡进度内存缓存
- `AchievementManager`（`Scripts/achievement_manager.gd`）成就解锁；`AchievementTrigger` 经 `GlobalClassLookup` 调用 `AddAchievement`
- `MenuLevelData` / `MenuLevelList`（`Scripts/MenuLevelData.gd` 等，`@tool extends Resource`，可序列化关卡列表）
- `MusicPreview` / `AdSystem` / `EnergySystem` / `PCKLoader`（`Scripts/level_manager/`）

注意 `Scripts/LevelManager.gd`（UI 控制器，`extends Control`，挂在 `Scenes/LevelManager.tscn`）与目录 `Scripts/level_manager/`（小写，存放子系统）**不是**同一概念，别混淆。

## PCK 关卡加载流程

1. `MenuLevelList` 资源（`pck_levels/level_list.tres`）罗列关卡条目，每条是 `MenuLevelData`，含 `pck_path`、`scene_path`、`save_id`、音乐/封面/主题色等。
2. `PCKLoader`（`Scripts/level_manager/pck_loader.gd`）按状态机 `IDLE → VERIFY_PCK → LOAD_PCK`：先校验 MD5（工作线程），再 `ProjectSettings.globalize_path` 后调用 `PCKLoader.load_pck()`，成功发 `pck_loaded` 信号。
3. 远端下载走 `PCKDownloader`（autoload-style `instance` 单例），从 `pck_levels/remote.json` 读多源（Github Raw / Gitee Raw / ghproxy）。
4. 启动器只加载 PCK，关卡内玩法由 PCK 里的场景自行实现（基于 `#Template/` 提供的 Trigger/Player 等组件）。

## GAS 云端存档

集成见 [`addons/gas_sdk/AGENTS.md`](addons/gas_sdk/AGENTS.md)。要点：
- 服务方法返回 `Variant`，使用前检查 `is GASError`。
- 凭证存 `user://gas_config.cfg`；`CloudArchiveService`（autoload）管同步。
- 不要把 GAS 服务当同步返回值用，须 `await`。

## 物理与渲染（项目设置级）

- 物理：引擎 `Jolt Physics`，3D 单独线程；Layer 命名固定为 1=Player、2=BaseFloor、3=BaseWall。
- 渲染：renderer `mobile`（桌面 Windows 下 RD 驱动 d3d12），贴图压缩 import ETC2/ASTC。改渲染相关代码勿走 Forward+ 假设。
- 输入映射：`turn`（鼠标左键/空格）、`retry`(R)、`save`(S)、`reload`(Q)、`savetaper`(W)——关卡内快捷键。

## 定制约定

- 覆盖 #Template 行为时，新建 autoload 或 hook，**不要去 `#Template/` 改原文件**。
- 资源数据用 `@tool extends Resource` 子类（参照 `MenuLevelData`），用 `.tres` 序列化保存，避免硬编码字典。
- `TODO.md` 是与 Unity 冰焰模板 V4.7.6 的功能对照表（P0–P3），新增 Trigger/Animator/GUI 前先查它确认是否已有对应实现或命名差异。

## 高信号文件入口

- 主菜单 UI 控制器：`Scripts/LevelManager.gd`（671 行，装配 MusicPreview/AdSystem/EnergySystem/PCKLoader）
- PCK 加载：`Scripts/level_manager/pck_loader.gd`
- 关卡数据：`Scripts/MenuLevelData.gd`、`Scripts/MenuLevelList.gd`、`pck_levels/level_list.tres`
- GAS 集成：`Scripts/gas/` 及 `addons/gas_sdk/`
- MCP 插件文档：`addons/godot_mcp/README.zh.md`
