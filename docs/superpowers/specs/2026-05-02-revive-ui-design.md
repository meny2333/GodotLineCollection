# Revive UI Design

## Overview

在 `CustomGameUI.tscn` 中添加复活专用 UI 层，当玩家死亡且有检查点时显示，提供复活和返回两个选项。

## Requirements

- **触发条件**：玩家死亡且存在检查点（`LevelManager.current_checkpoint != null`）
- **UI 替换**：复活 UI 替换当前游戏 UI（非叠加）
- **复活行为**：隐藏所有 UI，复活玩家到检查点，继续游戏
- **返回行为**：隐藏复活 UI，显示游戏 UI（含重试/返回菜单选项），不直接返回主菜单
- **进度条**：显示关卡完成百分比（`LevelManager.percent`）
- **视觉风格**：保持现有胶囊卡片风格，复用自动取色逻辑

## Architecture

### 场景结构

```
CustomGameUI (Control)
├── UILayer (CanvasLayer, layer=100) - 游戏UI
│   ├── TopBar - 顶部信息栏
│   └── BottomBar - 底部数据卡片和按钮
└── ReviveLayer (CanvasLayer, layer=101) - 复活UI
    └── RevivePanel (PanelContainer)
        ├── TopBar (Control)
        │   ├── BackBtn (Button) - 左上角"← 返回"
        │   └── ReviveBtn (Button) - 右上角"复活"
        └── ProgressBar (VBoxContainer)
            ├── PercentLabel (Label) - "75%"
            └── ProgressBar (ProgressBar) - 进度条
```

### 状态流程

```
玩家死亡 + 有检查点
    ↓
显示 ReviveLayer，隐藏 UILayer
    ↓
┌─────────────────┬─────────────────┐
│  点击"复活"      │  点击"返回"      │
│  ↓              │  ↓              │
│  隐藏 ReviveLayer│  隐藏 ReviveLayer│
│  复活玩家        │  显示 UILayer    │
│  不显示任何 UI   │  （含重试/返回） │
│  继续游戏        │  等待用户操作    │
└─────────────────┴─────────────────┘
```

### 脚本变更

修改 `Scripts/CustomGameUI.gd`：

1. **新增状态变量**：
   - `_revive_shown: bool` - 复活 UI 是否显示

2. **新增节点引用**：
   - `revive_layer: CanvasLayer`
   - `revive_btn: Button`
   - `revive_back_btn: Button`
   - `revive_progress_bar: ProgressBar`
   - `revive_percent_label: Label`

3. **新增方法**：
   - `_show_revive_ui()` - 显示复活 UI，隐藏游戏 UI
   - `_hide_revive_ui_silent()` - 隐藏复活 UI，不显示游戏 UI（复活后调用）
   - `_hide_revive_ui_show_game()` - 隐藏复活 UI，显示游戏 UI（返回时调用）
   - `_update_revive_progress()` - 更新进度条显示

4. **修改 `_process()`**：
   - 检测死亡 + 有检查点状态
   - 控制复活 UI 显示/隐藏
   - 复活成功后自动隐藏
   - 复活 UI 显示时不调用 `_update_colors()`

5. **修改按钮回调**：
   - `_on_revive_pressed()` - 调用 `_hide_revive_ui_silent()` 后复活
   - `_on_revive_back_pressed()` - 调用 `_hide_revive_ui_show_game()`

### 视觉设计

- **统一样式**：所有元素使用半透明黑色背景，不使用自动取色
  - PanelContainer: `bg_color = Color(0, 0, 0, 0.5)`
  - Button: `bg_color = Color(0, 0, 0, 0.6)`
  - Label: 白色文字
- **进度条**：Godot 内置 `ProgressBar`，深灰背景 + 白色填充
- **按钮布局**：BackBtn 左上角，ReviveBtn 右上角
- **不调用 `_update_colors()`**：复活 UI 使用固定样式，不跟随关卡颜色

## Data Flow

```
LevelManager.GameState = Died
    ↓
CustomGameUI._process() 检测
    ↓
检查 LevelManager.current_checkpoint != null
    ↓
显示 ReviveLayer，隐藏 UILayer
    ↓
用户点击"复活"
    ↓
_hide_revive_ui_silent()
    ↓
LevelManager.current_checkpoint.revive()
    ↓
LevelManager.GameState = Waiting
    ↓
_process() 检测非死亡状态
    ↓
隐藏 ReviveLayer（如仍显示）
```

## Testing

- 玩家死亡无检查点 → 不显示复活 UI
- 玩家死亡有检查点 → 显示复活 UI
- 点击复活 → 复活成功，无 UI 显示
- 点击返回 → 显示游戏 UI
- 进度条实时更新
- 自动取色正常工作
