# 设计文档：主菜单导入PCK直接游玩

## 概述

在主菜单（LevelManager.tscn）添加"导入PCK"功能，用户选择本地 .pck 文件后自动验证、加载并直接开始游玩。导入的关卡不会保存到 level_list.tres，仅临时游玩。

## 用户流程

1. 用户点击主菜单 Header 区域的"导入PCK"按钮
2. 弹出文件选择对话框，filter 为 `*.pck`
3. 选择文件后，系统读取 PCK 二进制验证：
   - 验证 magic number（GDPC = 0x43504447）
   - 扫描文件列表，查找 `[Scenes]/` 目录下的 `.tscn` + `.tres` 组合
   - 提取 scene_path
4. 验证通过 → 弹出确认对话框显示关卡名称
5. 用户确认 → 加载 PCK → 切换到关卡场景开始游玩
6. 验证失败 → info_label 显示错误信息

## 技术方案

### 文件变更

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Scripts/LevelManager.gd` | 修改 | 添加导入按钮、FileDialog、PCK验证和加载逻辑 |
| `addons/PCKManager/PCKDirAccess.gd` | 不变 | 运行时复用，纯GDScript无编辑器依赖 |

### 新增组件（在 LevelManager.gd 中）

#### 1. 导入按钮

在 Header 区域（与 RefreshBtn、切换视图按钮同排）添加"导入PCK"按钮。

```gdscript
@onready var import_btn: Button = $Margin/VBox/Header/ImportBtn
```

需要在 LevelManager.tscn 的 Header 中添加 Button 节点，命名为 `ImportBtn`。

#### 2. FileDialog

运行时创建，非模态：

```gdscript
var _import_dialog: FileDialog

func _create_import_dialog() -> void:
    _import_dialog = FileDialog.new()
    _import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    _import_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _import_dialog.filters = PackedStringArray(["*.pck ; PCK Files"])
    _import_dialog.title = "选择PCK文件"
    _import_dialog.size = Vector2i(600, 400)
    _import_dialog.file_selected.connect(_on_pck_file_selected)
    add_child(_import_dialog)
```

#### 3. PCK验证逻辑

复用 PCKDirAccess 的 `get_paths()` 方法扫描 PCK 内文件列表，然后用类似 `_find_level_data_in_pck` 的逻辑查找场景：

```gdscript
func _validate_pck(pck_path: String) -> Dictionary:
    # 返回 {"scene_path": "...", "name": "..."} 或空字典
    var pck_dir = PCKDirAccess.new()
    pck_dir.open(pck_path)
    if pck_dir.file == null:
        return {}
    var paths := pck_dir.get_paths()
    pck_dir.close()
    if paths.is_empty():
        return {}
    return _find_level_scene(paths)
```

场景查找逻辑（从 ugc_import/plugin.gd 移植简化版）：

```gdscript
func _find_level_scene(paths: Array[String]) -> Dictionary:
    var scene_dirs: Dictionary = {}
    for p in paths:
        var clean: String = p.trim_suffix(".remap")
        if not clean.contains("[Scenes]/"):
            continue
        var scenes_idx := clean.find("[Scenes]/")
        var after := clean.substr(scenes_idx + "[Scenes]/".length())
        var parts := after.split("/")
        if parts.size() >= 2:
            var dir_name: String = parts[0]
            if not scene_dirs.has(dir_name):
                scene_dirs[dir_name] = {"has_tscn": false, "has_tres": false}
            if parts[1].ends_with(".tscn"):
                scene_dirs[dir_name]["has_tscn"] = true
            elif parts[1].ends_with(".tres"):
                scene_dirs[dir_name]["has_tres"] = true

    # 优先找有 .tscn + .tres 的目录
    var best_dir: String = ""
    for dir_name in scene_dirs:
        if scene_dirs[dir_name]["has_tscn"] and scene_dirs[dir_name]["has_tres"]:
            best_dir = dir_name
            break

    # 退而求其次：找任意 .tscn
    if best_dir.is_empty():
        for p in paths:
            if p.trim_suffix(".remap").ends_with(".tscn"):
                return {"scene_path": p.trim_suffix(".remap"), "name": "unknown"}

    if best_dir.is_empty():
        return {}

    # 在 best_dir 中找 .tscn
    for p in paths:
        var clean: String = p.trim_suffix(".remap")
        if clean.contains("[Scenes]/%s/" % best_dir) and clean.ends_with(".tscn"):
            return {"scene_path": clean, "name": best_dir}
    return {}
```

#### 4. 加载并游玩

```gdscript
func _on_pck_file_selected(path: String) -> void:
    var result := _validate_pck(path)
    if result.is_empty():
        info_label.text = "无效PCK：未找到关卡场景"
        return

    var scene_path: String = result["scene_path"]
    var level_name: String = result["name"]

    # 加载PCK
    var success := ProjectSettings.load_resource_pack(path)
    if not success:
        info_label.text = "PCK加载失败"
        return

    # 直接切换场景
    info_label.text = "正在加载: %s" % level_name
    get_tree().change_scene_to_file(scene_path)
```

### UI布局变更

Header 区域按钮排列（从左到右）：
```
[用户头像]  ← 空间 →  [导入PCK] [切换视图] [刷新]
```

## 错误处理

| 情况 | 处理 |
|------|------|
| PCK文件不存在/无法读取 | info_label 提示"无法读取PCK文件" |
| Magic number不匹配 | info_label 提示"无效PCK文件" |
| PCK内无[Scenes]/目录 | info_label 提示"PCK内未找到关卡场景" |
| load_resource_pack失败 | info_label 提示"PCK加载失败" |

## 不做的事

- 不保存到 level_list.tres
- 不提取音乐/封面用于预览
- 不处理PCK内多个关卡的情况（取第一个找到的）
- 不做确认弹窗（直接加载，减少交互步骤）
