# Import PCK and Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在主菜单添加"导入PCK"功能，用户选择本地 .pck 文件后自动验证、加载并直接开始游玩。

**Architecture:** 在 Scripts/LevelManager.gd 中添加导入按钮、FileDialog、PCK 验证逻辑。复用现有 PCKDirAccess 读取 PCK 二进制文件列表，自动扫描 [Scenes]/ 目录找到关卡场景，加载后直接切换。不修改 level_list.tres。

**Tech Stack:** Godot 4.6, GDScript, PCKDirAccess (纯 GDScript PCK 读取器)

---

### Task 1: 在场景中添加"导入PCK"按钮节点

**Files:**
- Modify: `Scenes/LevelManager.tscn:117-126` (在 RefreshBtn 后添加 ImportBtn 节点)

- [ ] **Step 1: 在 LevelManager.tscn 的 Header 中添加 ImportBtn 节点**

在 `[node name="RefreshBtn" ...]` 块之后、`[node name="SpacerL" ...]` 之前插入：

```
[node name="ImportBtn" type="Button" parent="Margin/VBox/Header"]
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.85)
theme_override_font_sizes/font_size = 14
theme_override_styles/normal = SubResource("StyleBoxFlat_SecBtn")
theme_override_styles/pressed = SubResource("StyleBoxFlat_SecBtn")
theme_override_styles/hover = SubResource("StyleBoxFlat_SecBtnHover")
theme_override_styles/disabled = SubResource("StyleBoxFlat_DisabledBtn")
text = "导入PCK"
```

- [ ] **Step 2: 添加按钮信号连接**

在文件末尾的 `[connection]` 区域添加：

```
[connection signal="pressed" from="Margin/VBox/Header/ImportBtn" to="." method="_on_import_pck_pressed"]
```

- [ ] **Step 3: 验证场景文件格式正确**

在 Godot 编辑器中打开 LevelManager.tscn，确认 ImportBtn 出现在 Header 中 RefreshBtn 右侧。

---

### Task 2: 在 LevelManager.gd 中添加导入按钮引用和 FileDialog

**Files:**
- Modify: `Scripts/LevelManager.gd:1-30` (添加 @onready 引用和变量)
- Modify: `Scripts/LevelManager.gd:45-59` (在 _ready 中初始化)

- [ ] **Step 1: 添加 @onready 引用和成员变量**

在 `Scripts/LevelManager.gd` 顶部添加 ImportBtn 引用（在现有 @onready 行之后）：

```gdscript
@onready var import_btn: Button = $Margin/VBox/Header/ImportBtn
```

在成员变量区域（`var _detail_popup: AcceptDialog` 之后）添加：

```gdscript
var _import_dialog: FileDialog
```

- [ ] **Step 2: 在 _ready() 中创建 FileDialog**

在 `_ready()` 函数末尾（`_apply_circle_avatar(avatar_rect)` 之后）添加初始化调用：

```gdscript
_create_import_dialog()
```

- [ ] **Step 3: 实现 _create_import_dialog() 方法**

在 LevelManager.gd 中添加新方法（放在 `_create_view_toggle()` 之后）：

```gdscript
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

- [ ] **Step 4: 实现按钮回调**

添加按钮点击处理方法：

```gdscript
func _on_import_pck_pressed() -> void:
	_import_dialog.popup_centered()
```

- [ ] **Step 5: 运行项目验证 UI**

运行项目 (`godot4.6 --path .`)，确认主菜单 Header 出现"导入PCK"按钮，点击后弹出文件选择对话框。

---

### Task 3: 实现 PCK 验证和场景查找逻辑

**Files:**
- Modify: `Scripts/LevelManager.gd` (添加验证方法)

- [ ] **Step 1: 实现 _validate_pck() 方法**

添加 PCK 验证入口方法：

```gdscript
func _validate_pck(pck_global_path: String) -> Dictionary:
	var pck := PCKDirAccess.new()
	pck.open(pck_global_path)
	if pck.file == null:
		return {}
	var paths := pck.get_paths()
	pck.close()
	if paths.is_empty():
		return {}
	return _find_level_scene(paths)
```

- [ ] **Step 2: 实现 _find_level_scene() 方法**

从 ugc_import/plugin.gd 移植简化版场景查找逻辑：

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

	var best_dir: String = ""
	for dir_name in scene_dirs:
		if scene_dirs[dir_name]["has_tscn"] and scene_dirs[dir_name]["has_tres"]:
			best_dir = dir_name
			break

	if best_dir.is_empty():
		for p in paths:
			var clean: String = p.trim_suffix(".remap")
			if clean.ends_with(".tscn"):
				return {"scene_path": clean, "name": "unknown"}

	if best_dir.is_empty():
		return {}

	for p in paths:
		var clean: String = p.trim_suffix(".remap")
		if clean.contains("[Scenes]/%s/" % best_dir) and clean.ends_with(".tscn"):
			return {"scene_path": clean, "name": best_dir}
	return {}
```

- [ ] **Step 3: 验证逻辑可用**

可以临时在 `_on_import_pck_pressed` 中调用 `_validate_pck` 并打印结果来测试。使用已知有效的 PCK 文件（如 `pck_levels/sample.pck`）验证。

---

### Task 4: 实现文件选择回调和加载流程

**Files:**
- Modify: `Scripts/LevelManager.gd` (添加文件选择回调)

- [ ] **Step 1: 实现 _on_pck_file_selected() 方法**

```gdscript
func _on_pck_file_selected(path: String) -> void:
	var result := _validate_pck(path)
	if result.is_empty():
		info_label.text = "无效PCK：未找到关卡场景"
		return

	var scene_path: String = result["scene_path"]
	var level_name: String = result["name"]

	var success := ProjectSettings.load_resource_pack(path)
	if not success:
		info_label.text = "PCK加载失败"
		return

	loaded_pcks.append(path)
	info_label.text = "正在加载: %s" % level_name
	get_tree().change_scene_to_file(scene_path)
```

- [ ] **Step 2: 端到端测试**

1. 准备一个有效的 PCK 文件（如 `pck_levels/sample.pck` 的副本放在桌面）
2. 运行项目，点击"导入PCK"
3. 选择该 PCK 文件
4. 验证：关卡直接加载并开始游玩

- [ ] **Step 3: 错误场景测试**

1. 选择一个非 PCK 文件（如 .txt）→ 应提示"无效PCK"
2. 选择一个不含 [Scenes]/ 的 PCK → 应提示"无效PCK：未找到关卡场景"

---

### Task 5: 清理和最终验证

**Files:**
- Modify: `Scripts/LevelManager.gd` (清理临时测试代码)

- [ ] **Step 1: 确保无临时代码残留**

检查 `_on_import_pck_pressed` 方法，确保没有调试 print 语句。

- [ ] **Step 2: 完整流程验证**

运行完整流程：
1. 启动项目 → 主菜单
2. 点击"导入PCK" → 文件选择对话框弹出
3. 选择有效 PCK → 关卡加载并开始游玩
4. 返回主菜单 → 确认导入的关卡未出现在关卡列表中（不保存到 level_list.tres）

- [ ] **Step 3: 提交代码**

```bash
git add Scripts/LevelManager.gd Scenes/LevelManager.tscn
git commit -m "feat: add import PCK and play directly from main menu"
```
