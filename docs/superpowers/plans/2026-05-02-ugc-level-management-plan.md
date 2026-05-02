# UGC关卡管理增删功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有ugc_import插件中添加关卡管理功能，支持删除、编辑、排序和批量操作

**Architecture:** 扩展现有ugc_import插件对话框，添加TabContainer组织导入和管理功能。管理标签页显示已导入关卡列表，支持删除、编辑、排序操作。

**Tech Stack:** Godot 4.6, GDScript, EditorPlugin, Resource系统

---

## 文件结构

### 修改文件
- `addons/ugc_import/plugin.gd` - 主要修改文件，添加管理功能

### 新增文件（无）

### 依赖文件（只读）
- `Scripts/MenuLevelData.gd` - 关卡数据资源类
- `Scripts/MenuLevelList.gd` - 关卡列表资源类
- `addons/PCKManager/PCKDirAccess.gd` - PCK文件访问

---

## 任务分解

### Task 1: 重构对话框结构，添加TabContainer

**Files:**
- Modify: `addons/ugc_import/plugin.gd:23-88`

- [ ] **Step 1: 修改_import_dialog创建逻辑**

```gdscript
func _enter_tree() -> void:
	import_button = Button.new()
	import_button.text = "UGC管理"
	import_button.pressed.connect(_on_import_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, import_button)

	import_dialog = ConfirmationDialog.new()
	import_dialog.title = "UGC关卡管理"
	import_dialog.size = Vector2i(700, 550)
	import_dialog.ok_button_text = "导入"
	import_dialog.confirmed.connect(_on_import_confirmed)

	var tab_container := TabContainer.new()
	tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 创建导入标签页
	var import_tab := _create_import_tab()
	tab_container.add_child(import_tab)
	import_tab.name = "导入PCK"

	# 创建管理标签页
	var manage_tab := _create_manage_tab()
	tab_container.add_child(manage_tab)
	manage_tab.name = "关卡管理"

	import_dialog.add_child(tab_container)
	add_child(import_dialog)

	# 其他对话框保持不变
	file_dialog = FileDialog.new()
	file_dialog.title = "选择PCK文件"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.pck ; PCK文件"])
	file_dialog.files_selected.connect(_on_files_selected)
	file_dialog.close_requested.connect(func(): file_dialog.hide())
	add_child(file_dialog)

	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.title = "覆盖确认"
	overwrite_dialog.ok_button_text = "覆盖"
	overwrite_dialog.cancel_button_text = "跳过"
	add_child(overwrite_dialog)
```

- [ ] **Step 2: 创建_create_import_tab函数**

```gdscript
func _create_import_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "ImportTab"

	var header := Label.new()
	header.text = "选择 .pck 文件进行验证和导入："
	vbox.add_child(header)

	pck_list = ItemList.new()
	pck_list.custom_minimum_size = Vector2(0, 300)
	pck_list.select_mode = ItemList.SELECT_MULTI
	vbox.add_child(pck_list)

	var btn_hbox := HBoxContainer.new()

	select_button = Button.new()
	select_button.text = "选择PCK"
	select_button.pressed.connect(_on_select_pressed)
	btn_hbox.add_child(select_button)

	verify_button = Button.new()
	verify_button.text = "验证选中"
	verify_button.pressed.connect(_on_verify_pressed)
	btn_hbox.add_child(verify_button)

	var remove_button := Button.new()
	remove_button.text = "移除选中"
	remove_button.pressed.connect(_on_remove_pressed)
	btn_hbox.add_child(remove_button)

	vbox.add_child(btn_hbox)

	var warn_label := Label.new()
	warn_label.text = "注意：仅验证PCK格式和内容，运行时由PCKLoader自动加载"
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(warn_label)

	return vbox
```

- [ ] **Step 3: 创建空的_create_manage_tab函数**

```gdscript
func _create_manage_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "ManageTab"

	var header := Label.new()
	header.text = "已导入的关卡列表："
	vbox.add_child(header)

	# TODO: 后续任务添加具体实现

	return vbox
```

- [ ] **Step 4: 测试对话框显示**

在Godot编辑器中运行项目，点击"UGC管理"按钮，确认：
1. 对话框显示两个标签页
2. 导入标签页功能正常
3. 管理标签页显示标题

- [ ] **Step 5: 提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "refactor: 重构ugc_import对话框，添加TabContainer结构"
```

---

### Task 2: 实现管理标签页UI

**Files:**
- Modify: `addons/ugc_import/plugin.gd`

- [ ] **Step 1: 添加管理标签页变量**

在文件顶部添加变量声明：

```gdscript
var manage_list: ItemList
var edit_button: Button
var delete_button: Button
var move_up_button: Button
var move_down_button: Button
var edit_dialog: ConfirmationDialog
```

- [ ] **Step 2: 完善_create_manage_tab函数**

```gdscript
func _create_manage_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "ManageTab"

	var header := Label.new()
	header.text = "已导入的关卡列表："
	vbox.add_child(header)

	manage_list = ItemList.new()
	manage_list.custom_minimum_size = Vector2(0, 300)
	manage_list.select_mode = ItemList.SELECT_MULTI
	vbox.add_child(manage_list)

	var btn_hbox := HBoxContainer.new()

	edit_button = Button.new()
	edit_button.text = "编辑选中"
	edit_button.pressed.connect(_on_edit_selected)
	btn_hbox.add_child(edit_button)

	delete_button = Button.new()
	delete_button.text = "删除选中"
	delete_button.pressed.connect(_on_delete_selected)
	btn_hbox.add_child(delete_button)

	move_up_button = Button.new()
	move_up_button.text = "上移"
	move_up_button.pressed.connect(_on_move_up)
	btn_hbox.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "下移"
	move_down_button.pressed.connect(_on_move_down)
	btn_hbox.add_child(move_down_button)

	vbox.add_child(btn_hbox)

	return vbox
```

- [ ] **Step 3: 创建编辑对话框**

在_enter_tree函数末尾添加：

```gdscript
	# 创建编辑对话框
	edit_dialog = ConfirmationDialog.new()
	edit_dialog.title = "编辑关卡信息"
	edit_dialog.size = Vector2i(400, 300)
	edit_dialog.ok_button_text = "保存"
	edit_dialog.confirmed.connect(_on_edit_confirmed)
	add_child(edit_dialog)
```

- [ ] **Step 4: 测试UI显示**

在Godot编辑器中运行项目，切换到"关卡管理"标签页，确认：
1. 列表显示正常
2. 按钮显示正常
3. 点击按钮无报错

- [ ] **Step 5: 提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "feat: 添加管理标签页UI框架"
```

---

### Task 3: 实现关卡列表加载和显示

**Files:**
- Modify: `addons/ugc_import/plugin.gd`

- [ ] **Step 1: 添加加载关卡列表函数**

```gdscript
const LEVEL_LIST_PATH := "res://pck_levels/level_list.tres"

var managed_levels: Array[MenuLevelData] = []

func _load_level_list() -> MenuLevelList:
	if not ResourceLoader.exists(LEVEL_LIST_PATH):
		return null
	var list = load(LEVEL_LIST_PATH)
	if list is MenuLevelList:
		return list
	return null

func _save_level_list(list: MenuLevelList) -> void:
	var err := ResourceSaver.save(list, LEVEL_LIST_PATH)
	if err != OK:
		push_error("Failed to save level list: ", err)
```

- [ ] **Step 2: 添加刷新管理列表函数**

```gdscript
func _refresh_manage_list() -> void:
	manage_list.clear()
	managed_levels.clear()

	var list := _load_level_list()
	if list == null:
		return

	managed_levels = list.levels.duplicate()

	for i in range(managed_levels.size()):
		var level := managed_levels[i]
		var display_text := "%d. %s" % [i + 1, level.title if level.title != "" else "未命名关卡"]
		if not level.pck_path.is_empty():
			display_text += " (%s)" % level.pck_path.get_file()
		manage_list.add_item(display_text)
```

- [ ] **Step 3: 在_on_import_pressed中刷新管理列表**

修改_on_import_pressed函数：

```gdscript
func _on_import_pressed() -> void:
	_refresh_list()
	_refresh_manage_list()
	import_dialog.popup_centered()
```

- [ ] **Step 4: 测试列表显示**

在Godot编辑器中运行项目：
1. 先导入一个PCK文件
2. 打开管理对话框
3. 确认管理标签页显示已导入的关卡

- [ ] **Step 5: 提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "feat: 实现关卡列表加载和显示功能"
```

---

### Task 4: 实现删除功能

**Files:**
- Modify: `addons/ugc_import/plugin.gd`

- [ ] **Step 1: 添加删除确认对话框变量**

```gdscript
var delete_confirm_dialog: ConfirmationDialog
```

- [ ] **Step 2: 创建删除确认对话框**

在_enter_tree函数中添加：

```gdscript
	# 创建删除确认对话框
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "确认删除"
	delete_confirm_dialog.ok_button_text = "删除"
	delete_confirm_dialog.cancel_button_text = "取消"
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_confirm_dialog)
```

- [ ] **Step 3: 实现删除功能函数**

```gdscript
func _on_delete_selected() -> void:
	var selected := manage_list.get_selected_items()
	if selected.is_empty():
		EditorInterface.get_editor_toaster().push_toast("请先选择要删除的关卡", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return

	var names: PackedStringArray = []
	for idx in selected:
		if idx >= 0 and idx < managed_levels.size():
			names.append(managed_levels[idx].title if managed_levels[idx].title != "" else "未命名关卡")

	delete_confirm_dialog.get_label().text = "确定要删除以下关卡吗？\n" + "\n".join(names) + "\n\n这将同时删除PCK文件和关卡数据。"
	delete_confirm_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	var selected := manage_list.get_selected_items()
	if selected.is_empty():
		return

	# 从后往前删除，避免索引问题
	var sorted_selected := selected.duplicate()
	sorted_selected.sort()
	sorted_selected.reverse()

	var list := _load_level_list()
	if list == null:
		return

	var deleted_count := 0
	for idx in sorted_selected:
		if idx >= 0 and idx < list.levels.size():
			var level := list.levels[idx]
			# 删除PCK文件
			if not level.pck_path.is_empty():
				var global_path := ProjectSettings.globalize_path(level.pck_path)
				if FileAccess.file_exists(global_path):
					var err := DirAccess.remove_absolute(global_path)
					if err != OK:
						push_warning("Failed to delete PCK file: ", level.pck_path)
			# 从列表中移除
			list.levels.remove_at(idx)
			deleted_count += 1

	_save_level_list(list)
	_refresh_manage_list()

	EditorInterface.get_editor_toaster().push_toast("已删除 %d 个关卡" % deleted_count, EditorInterface.get_editor_toaster().SEVERITY_INFO)
```

- [ ] **Step 4: 测试删除功能**

在Godot编辑器中运行项目：
1. 导入一个测试PCK文件
2. 打开管理对话框
3. 选中关卡
4. 点击"删除选中"
5. 确认删除
6. 验证PCK文件已删除
7. 验证关卡列表已更新

- [ ] **Step 5: 提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "feat: 实现关卡删除功能"
```

---

### Task 5: 实现编辑功能

**Files:**
- Modify: `addons/ugc_import/plugin.gd`

- [ ] **Step 1: 添加编辑对话框变量**

```gdscript
var edit_title_input: LineEdit
var cover_texture: TextureRect
var music_label: Label
var save_id_input: LineEdit
var current_editing_level: MenuLevelData
var cover_file_dialog: FileDialog
var music_file_dialog: FileDialog
```

- [ ] **Step 2: 创建编辑对话框UI**

在_enter_tree函数中修改edit_dialog的创建：

```gdscript
	# 创建编辑对话框
	edit_dialog = ConfirmationDialog.new()
	edit_dialog.title = "编辑关卡信息"
	edit_dialog.size = Vector2i(450, 400)
	edit_dialog.ok_button_text = "保存"
	edit_dialog.cancel_button_text = "取消"
	edit_dialog.confirmed.connect(_on_edit_confirmed)

	var edit_vbox := VBoxContainer.new()
	edit_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 标题
	var title_label := Label.new()
	title_label.text = "关卡标题："
	edit_vbox.add_child(title_label)

	edit_title_input = LineEdit.new()
	edit_vbox.add_child(edit_title_input)

	# 封面
	var cover_label := Label.new()
	cover_label.text = "封面图片："
	edit_vbox.add_child(cover_label)

	var cover_hbox := HBoxContainer.new()
	cover_texture = TextureRect.new()
	cover_texture.custom_minimum_size = Vector2(100, 100)
	cover_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_hbox.add_child(cover_texture)

	var cover_button := Button.new()
	cover_button.text = "选择封面"
	cover_button.pressed.connect(_on_select_cover)
	cover_hbox.add_child(cover_button)
	edit_vbox.add_child(cover_hbox)

	# 音乐
	var music_hbox_label := Label.new()
	music_hbox_label.text = "背景音乐："
	edit_vbox.add_child(music_hbox_label)

	var music_hbox := HBoxContainer.new()
	music_label = Label.new()
	music_label.text = "未选择"
	music_hbox.add_child(music_label)

	var music_button := Button.new()
	music_button.text = "选择音乐"
	music_button.pressed.connect(_on_select_music)
	music_hbox.add_child(music_button)
	edit_vbox.add_child(music_hbox)

	# 保存ID
	var save_id_label := Label.new()
	save_id_label.text = "保存ID："
	edit_vbox.add_child(save_id_label)

	save_id_input = LineEdit.new()
	edit_vbox.add_child(save_id_input)

	edit_dialog.add_child(edit_vbox)
	add_child(edit_dialog)

	# 封面文件对话框
	cover_file_dialog = FileDialog.new()
	cover_file_dialog.title = "选择封面图片"
	cover_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	cover_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	cover_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; 图片文件"])
	cover_file_dialog.file_selected.connect(_on_cover_selected)
	add_child(cover_file_dialog)

	# 音乐文件对话框
	music_file_dialog = FileDialog.new()
	music_file_dialog.title = "选择背景音乐"
	music_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	music_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	music_file_dialog.filters = PackedStringArray(["*.mp3, *.ogg, *.wav ; 音频文件"])
	music_file_dialog.file_selected.connect(_on_music_selected)
	add_child(music_file_dialog)
```

- [ ] **Step 3: 实现编辑功能函数**

```gdscript
func _on_edit_selected() -> void:
	var selected := manage_list.get_selected_items()
	if selected.is_empty():
		EditorInterface.get_editor_toaster().push_toast("请先选择要编辑的关卡", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return
	if selected.size() > 1:
		EditorInterface.get_editor_toaster().push_toast("只能同时编辑一个关卡", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return

	var idx: int = selected[0]
	if idx < 0 or idx >= managed_levels.size():
		return

	current_editing_level = managed_levels[idx]
	_show_edit_dialog(current_editing_level)

func _show_edit_dialog(level: MenuLevelData) -> void:
	edit_title_input.text = level.title
	cover_texture.texture = level.cover
	music_label.text = level.music.resource_path.get_file() if level.music else "未选择"
	save_id_input.text = level.save_id
	edit_dialog.popup_centered()

func _on_select_cover() -> void:
	cover_file_dialog.popup_centered(Vector2i(800, 600))

func _on_cover_selected(path: String) -> void:
	var texture := load(path) as Texture2D
	if texture:
		cover_texture.texture = texture

func _on_select_music() -> void:
	music_file_dialog.popup_centered(Vector2i(800, 600))

func _on_music_selected(path: String) -> void:
	var audio := load(path) as AudioStream
	if audio:
		current_editing_level.music = audio
		music_label.text = path.get_file()

func _on_edit_confirmed() -> void:
	if current_editing_level == null:
		return

	# 保存修改
	current_editing_level.title = edit_title_input.text
	current_editing_level.cover = cover_texture.texture as Texture2D
	current_editing_level.save_id = save_id_input.text

	# 更新level_list.tres
	var list := _load_level_list()
	if list:
		_save_level_list(list)

	_refresh_manage_list()
	current_editing_level = null

	EditorInterface.get_editor_toaster().push_toast("关卡信息已保存", EditorInterface.get_editor_toaster().SEVERITY_INFO)
```

- [ ] **Step 4: 测试编辑功能**

在Godot编辑器中运行项目：
1. 导入一个测试PCK文件
2. 打开管理对话框
3. 选中关卡
4. 点击"编辑选中"
5. 修改标题、封面、音乐、保存ID
6. 点击保存
7. 验证修改已保存

- [ ] **Step 5: 提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "feat: 实现关卡编辑功能"
```

---

### Task 6: 实现排序功能

**Files:**
- Modify: `addons/ugc_import/plugin.gd`

- [ ] **Step 1: 实现排序功能函数**

```gdscript
func _on_move_up() -> void:
	var selected := manage_list.get_selected_items()
	if selected.is_empty():
		return
	if selected.size() > 1:
		EditorInterface.get_editor_toaster().push_toast("请选择单个关卡进行移动", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return

	var idx: int = selected[0]
	if idx <= 0:
		return

	var list := _load_level_list()
	if list == null:
		return

	# 交换位置
	var temp := list.levels[idx]
	list.levels[idx] = list.levels[idx - 1]
	list.levels[idx - 1] = temp

	_save_level_list(list)
	_refresh_manage_list()

	# 保持选中状态
	manage_list.select(idx - 1)

func _on_move_down() -> void:
	var selected := manage_list.get_selected_items()
	if selected.is_empty():
		return
	if selected.size() > 1:
		EditorInterface.get_editor_toaster().push_toast("请选择单个关卡进行移动", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return

	var idx: int = selected[0]
	var list := _load_level_list()
	if list == null:
		return

	if idx >= list.levels.size() - 1:
		return

	# 交换位置
	var temp := list.levels[idx]
	list.levels[idx] = list.levels[idx + 1]
	list.levels[idx + 1] = temp

	_save_level_list(list)
	_refresh_manage_list()

	# 保持选中状态
	manage_list.select(idx + 1)
```

- [ ] **Step 2: 测试排序功能**

在Godot编辑器中运行项目：
1. 导入多个测试PCK文件
2. 打开管理对话框
3. 选中关卡
4. 点击"上移"或"下移"
5. 验证顺序已更改
6. 刷新对话框，验证顺序已保存

- [ ] **Step 3: 提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "feat: 实现关卡排序功能"
```

---

### Task 7: 完善批量操作和错误处理

**Files:**
- Modify: `addons/ugc_import/plugin.gd`

- [ ] **Step 1: 完善删除功能的批量操作**

修改_on_delete_confirmed函数，支持批量删除：

```gdscript
func _on_delete_confirmed() -> void:
	var selected := manage_list.get_selected_items()
	if selected.is_empty():
		return

	# 从后往前删除，避免索引问题
	var sorted_selected := selected.duplicate()
	sorted_selected.sort()
	sorted_selected.reverse()

	var list := _load_level_list()
	if list == null:
		return

	var deleted_count := 0
	var failed_count := 0
	for idx in sorted_selected:
		if idx >= 0 and idx < list.levels.size():
			var level := list.levels[idx]
			# 删除PCK文件
			if not level.pck_path.is_empty():
				var global_path := ProjectSettings.globalize_path(level.pck_path)
				if FileAccess.file_exists(global_path):
					var err := DirAccess.remove_absolute(global_path)
					if err != OK:
						push_warning("Failed to delete PCK file: ", level.pck_path)
						failed_count += 1
						continue
			# 从列表中移除
			list.levels.remove_at(idx)
			deleted_count += 1

	_save_level_list(list)
	_refresh_manage_list()

	if failed_count > 0:
		EditorInterface.get_editor_toaster().push_toast("删除完成：%d 成功，%d 失败" % [deleted_count, failed_count], EditorInterface.get_editor_toaster().SEVERITY_WARNING)
	else:
		EditorInterface.get_editor_toaster().push_toast("已删除 %d 个关卡" % deleted_count, EditorInterface.get_editor_toaster().SEVERITY_INFO)
```

- [ ] **Step 2: 添加错误处理**

在_load_level_list函数中添加错误处理：

```gdscript
func _load_level_list() -> MenuLevelList:
	if not ResourceLoader.exists(LEVEL_LIST_PATH):
		return null
	var list = load(LEVEL_LIST_PATH)
	if list is MenuLevelList:
		return list
	push_warning("Failed to load level list: invalid resource type")
	return null
```

在_save_level_list函数中添加错误处理：

```gdscript
func _save_level_list(list: MenuLevelList) -> void:
	if list == null:
		push_error("Cannot save null level list")
		return
	var err := ResourceSaver.save(list, LEVEL_LIST_PATH)
	if err != OK:
		push_error("Failed to save level list: ", err)
		EditorInterface.get_editor_toaster().push_toast("保存失败", EditorInterface.get_editor_toaster().SEVERITY_ERROR)
```

- [ ] **Step 3: 测试批量操作和错误处理**

在Godot编辑器中运行项目：
1. 导入多个测试PCK文件
2. 选中多个关卡
3. 批量删除
4. 验证所有选中关卡已删除
5. 测试错误情况（如只读文件）

- [ ] **Step 4: 提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "feat: 完善批量操作和错误处理"
```

---

### Task 8: 最终测试和清理

**Files:**
- Modify: `addons/ugc_import/plugin.gd`

- [ ] **Step 1: 完整功能测试**

在Godot编辑器中运行完整测试：
1. 导入功能测试
2. 删除功能测试（单选和批量）
3. 编辑功能测试（所有属性）
4. 排序功能测试
5. 错误处理测试

- [ ] **Step 2: 代码清理**

检查并清理代码：
1. 移除未使用的变量
2. 确保所有函数都有文档注释
3. 确保代码风格一致

- [ ] **Step 3: 最终提交**

```bash
git add addons/ugc_import/plugin.gd
git commit -m "feat: 完成UGC关卡管理增删功能"
```

---

## 验证清单

- [ ] 导入功能正常工作
- [ ] 删除功能正常工作（单选和批量）
- [ ] 编辑功能正常工作（标题、封面、音乐、保存ID）
- [ ] 排序功能正常工作
- [ ] 错误处理正常工作
- [ ] UI响应正常
- [ ] 数据持久化正常
- [ ] 无GDScript错误或警告
