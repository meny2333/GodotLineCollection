# Scripts/ — 主应用脚本

## 概览

菜单 UI、云存档、用户管理的核心逻辑。7 个 GD 脚本 + 3 个 autoload 单例。

## 结构

```
Scripts/
├── LevelManager.gd      # 菜单主控（598行），管理关卡展示、PCK 加载、音乐播放
├── MenuLevelData.gd      # @tool 资源类，关卡元数据（封面/音乐/路径）
├── MenuLevelList.gd      # @tool 资源类，关卡列表容器
├── progress_store.gd     # static 单例（RefCounted），本地进度存储
├── UserManager.gd        # autoload，用户信息 + 头像加载
├── GameUIHook.gd         # autoload，游戏 UI 钩子
├── CustomGameUI.gd       # 自定义游戏 UI
├── gas/                  # GAS 云存档集成
│   └── cloud_archive_service.gd  # autoload，云端存档同步
└── ui/                   # UI 组件
```

## 关键类

| 类名 | 类型 | 职责 |
|------|------|------|
| `MenuLevelData` | Resource (@tool) | 关卡元数据：封面、音乐、PCK 路径、场景路径 |
| `MenuLevelList` | Resource (@tool) | 关卡列表容器，存储为 `level_list.tres` |
| `ProgressStore` | RefCounted (static) | 本地进度：星星、百分比、钻石 |
| `UserManager` | Node (autoload) | 用户昵称、头像、邮箱 |

## 模式

- **资源类必须加 `@tool`**：`MenuLevelData`、`MenuLevelList` 在编辑器中使用
- **static 单例模式**：`ProgressStore` 用 `static var` 而非 autoload
- **信号驱动**：`UserManager.user_info_updated` 通知 UI 更新

## 注意事项

- `LevelManager` 是 Control 节点，不是 Template 中的 static 单例
- PCK 加载不预检路径，直接 `change_scene_to_file`
- 音乐播放支持淡入淡出 + 循环计时器