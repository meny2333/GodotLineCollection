# Level Detail Popup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在LevelManager中增强"详细信息"按钮功能，从PCK导入时提取author字段，并在点击时弹出Popup显示关卡详细信息

**Architecture:** 修改MenuLevelData新增字段，修改ugc_import插件提取author，修改LevelManager实现popup弹出

**Tech Stack:** Godot 4.6, GDScript

---

## File Structure

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `Scripts/MenuLevelData.gd` | 修改 | 新增author、description字段 |
| `addons/ugc_import/plugin.gd` | 修改 | 提取author、编辑对话框新增字段 |
| `Scripts/LevelManager.gd` | 修改 | 实现popup弹出逻辑 |

---

### Task 1: MenuLevelData 新增字段

**Files:**
- Modify: `Scripts/MenuLevelData.gd`

- [ ] **Step 1: 添加author字段**

```gdscript
@tool
class_name MenuLevelData
extends Resource

@export var cover: Texture2D
@export var music: AudioStream
@export var pck_path: String = ""

@export var title: String = ""
@export var author: String = ""
@export var description: String = ""
@export var scene_path: String = ""
@export var save_id: String = ""

## 音乐开始播放时间（秒）
@export var music_start: float = 0.0
## 音乐播放持续时长（秒），0表示播放到结尾
@export var music_duration: float = 0.0
## 音乐淡入时长（秒）
@export var music_fade_in: float = 1.0
## 音乐淡出时长（秒）
@export var music_fade_out: float = 1.0
```

- [ ] **Step 2: 验证修改**

在Godot编辑器中打开项目，确认MenuLevelData资源现在显示author和description字段。

---

### Task 2: ugc_import 插件提取 author

**Files:**
- Modify: `addons/ugc_import/plugin.gd:477-530` (_find_level_data_in_pck方法)
- Modify: `addons/ugc_import/plugin.gd:546-559` (_extract_save_id方法)
- Modify: `addons/ugc_import/plugin.gd:688-724` (_upsert_level_list方法)

- [ ] **Step 1: 添加_extract_author方法**

在`_extract_save_id`方法后面添加：

```gdscript
## 从tres文件中提取author
func _extract_author(pck_dir: RefCounted, tres_path: String) -> String:
	var raw: PackedByteArray = pck_dir.get_buffer(tres_path)
	if raw.is_empty():
		return ""
	var text: String = raw.get_string_from_utf8()
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("author"):
			var eq_idx := trimmed.find("=")
			if eq_idx >= 0:
				var val := trimmed.substr(eq_idx + 1).strip_edges()
				return val.strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""
```

- [ ] **Step 2: 修改_find_level_data_in_pck提取author**

在`_find_level_data_in_pck`方法中，找到提取saveID的代码后，添加author提取：

```gdscript
var author_str := ""
if not tres_path.is_empty():
	save_id_str = _extract_save_id(pck_dir, tres_path)
	author_str = _extract_author(pck_dir, tres_path)

var info: Dictionary = {"name": best_dir, "scene_path": best_scene_path}
if not save_id_str.is_empty():
	info["save_id"] = save_id_str
if not author_str.is_empty():
	info["author"] = author_str
return info
```

- [ ] **Step 3: 修改_upsert_level_list保存author**

在`_upsert_level_list`方法中，从level_info读取author并保存：

```gdscript
var author: String = level_info.get("author", "")

for data in list.levels:
	if data.pck_path == pck_res_path:
		data.title = title
		data.scene_path = scene_path
		if not save_id.is_empty():
			data.save_id = save_id
		if not author.is_empty():
			data.author = author
		if music != null:
			data.music = music
		ResourceSaver.save(list, LEVEL_LIST_PATH)
		return

var data := MenuLevelData.new()
data.title = title
data.pck_path = pck_res_path
data.scene_path = scene_path
data.save_id = save_id
data.author = author
if music != null:
	data.music = music
list.levels.append(data)
ResourceSaver.save(list, LEVEL_LIST_PATH)
```

- [ ] **Step 4: 验证修改**

导入一个包含author字段的PCK文件，检查level_list.tres中author是否正确保存。

---

### Task 3: ugc_import 编辑对话框新增字段

**Files:**
- Modify: `addons/ugc_import/plugin.gd` (编辑对话框相关代码)

- [ ] **Step 1: 添加UI变量声明**

在变量声明区域添加：

```gdscript
## 编辑对话框中的作者输入框
var edit_author_input: LineEdit
## 编辑对话框中的描述输入框
var edit_description_input: LineEdit
```

- [ ] **Step 2: 在编辑对话框中添加author输入框**

在`_enter_tree`方法中，找到save_id_input创建的位置，在其后添加：

```gdscript
# 作者
var author_label := Label.new()
author_label.text = "作者："
edit_vbox.add_child(author_label)

edit_author_input = LineEdit.new()
edit_vbox.add_child(edit_author_input)

# 描述
var description_label := Label.new()
description_label.text = "描述："
edit_vbox.add_child(description_label)

edit_description_input = LineEdit.new()
edit_vbox.add_child(edit_description_input)
```

- [ ] **Step 3: 修改_show_edit_dialog加载author和description**

在`_show_edit_dialog`方法中添加：

```gdscript
edit_author_input.text = level.author
edit_description_input.text = level.description
```

- [ ] **Step 4: 修改_on_edit_confirmed保存author和description**

在`_on_edit_confirmed`方法中添加：

```gdscript
current_editing_level.author = edit_author_input.text
current_editing_level.description = edit_description_input.text
```

- [ ] **Step 5: 验证修改**

在Godot编辑器中打开UGC管理，编辑一个关卡，确认可以看到author和description输入框并能保存。

---

### Task 4: LevelManager 实现 Popup

**Files:**
- Modify: `Scripts/LevelManager.gd:456-463` (_on_info_button方法)

- [ ] **Step 1: 添加popup变量声明**

在变量声明区域添加：

```gdscript
## 详情弹窗
var _detail_popup: AcceptDialog
```

- [ ] **Step 2: 修改_on_info_button方法**

替换原有的`_on_info_button`方法：

```gdscript
func _on_info_button() -> void:
	if levels.is_empty():
		return
	var data: MenuLevelData = levels[current_index]
	_show_detail_popup(data)


func _show_detail_popup(data: MenuLevelData) -> void:
	if _detail_popup:
		_detail_popup.queue_free()

	_detail_popup = AcceptDialog.new()
	_detail_popup.title = "关卡详情"
	_detail_popup.size = Vector2i(500, 300)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# 左侧封面
	var cover_rect := TextureRect.new()
	cover_rect.custom_minimum_size = Vector2(200, 200)
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_rect.texture = data.cover
	hbox.add_child(cover_rect)

	# 右侧信息
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = data.title if data.title != "" else "未命名关卡"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	vbox.add_child(title_label)

	var author_label := Label.new()
	author_label.text = "作者: %s" % data.author if not data.author.is_empty() else "作者: 未知"
	author_label.add_theme_font_size_override("font_size", 14)
	author_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7, 1))
	vbox.add_child(author_label)

	var desc_label := Label.new()
	desc_label.text = data.description if not data.description.is_empty() else "暂无描述"
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	hbox.add_child(vbox)
	_detail_popup.add_child(hbox)
	add_child(_detail_popup)
	_detail_popup.popup_centered()
```

- [ ] **Step 3: 验证修改**

运行游戏，点击"详细信息"按钮，确认弹出popup显示封面、标题、作者和描述。

---

## 测试清单

1. MenuLevelData资源在编辑器中显示author和description字段
2. 导入PCK时author字段自动提取并保存到level_list.tres
3. 编辑对话框可以编辑author和description
4. 点击"详细信息"按钮弹出popup
5. popup正确显示封面、标题、作者、描述
6. 无author时显示"未知"，无description时显示"暂无描述"
