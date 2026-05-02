@tool
extends EditorPlugin

## 工具栏按钮，打开UGC管理对话框
var import_button: Button
## UGC管理主对话框
var import_dialog: ConfirmationDialog
## PCK文件列表
var pck_list: ItemList
## 选择PCK文件按钮
var select_button: Button
## 验证选中PCK按钮
var verify_button: Button
## 文件选择对话框
var file_dialog: FileDialog
## 覆盖确认对话框
var overwrite_dialog: ConfirmationDialog

## 待导入的PCK条目列表
var pck_entries: Array[Dictionary] = []

## 关卡管理列表
var manage_list: ItemList
## 编辑按钮
var edit_button: Button
## 删除按钮
var delete_button: Button
## 上移按钮
var move_up_button: Button
## 下移按钮
var move_down_button: Button
## 编辑对话框
var edit_dialog: ConfirmationDialog
## 删除确认对话框
var delete_confirm_dialog: ConfirmationDialog

## 已管理的关卡数据列表
var managed_levels: Array[MenuLevelData] = []

## 编辑对话框中的标题输入框
var edit_title_input: LineEdit
## 编辑对话框中的封面预览
var cover_texture: TextureRect
## 编辑对话框中的音乐标签
var music_label: Label
## 编辑对话框中的保存ID输入框
var save_id_input: LineEdit
## 编辑对话框中的作者输入框
var edit_author_input: LineEdit
## 编辑对话框中的描述输入框
var edit_description_input: LineEdit
## 音乐开始时间输入框
var music_start_input: SpinBox
## 音乐持续时长输入框
var music_duration_input: SpinBox
## 音乐淡入时长输入框
var music_fade_in_input: SpinBox
## 音乐淡出时长输入框
var music_fade_out_input: SpinBox
## 当前正在编辑的关卡数据
var current_editing_level: MenuLevelData
## 封面文件选择对话框
var cover_file_dialog: FileDialog
## 音乐文件选择对话框
var music_file_dialog: FileDialog

## PCK输出目录
const PCK_OUTPUT_DIR := "res://pck_levels"
## 关卡列表资源路径
const LEVEL_LIST_PATH := "res://pck_levels/level_list.tres"

## 验证状态枚举
enum VerifyStatus {
	PENDING,  ## 待验证
	PASSED,   ## 验证通过
	FAILED,   ## 验证失败
	NO_LEVEL, ## 无关卡内容
}

## 插件进入场景树时初始化UI
func _enter_tree() -> void:
	import_button = Button.new()
	import_button.text = "UGC管理"
	import_button.pressed.connect(_on_import_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, import_button)

	import_dialog = ConfirmationDialog.new()
	import_dialog.title = "UGC关卡管理"
	import_dialog.size = Vector2i(550, 380)
	import_dialog.ok_button_text = "导入"
	import_dialog.confirmed.connect(_on_import_confirmed)

	var tab_container := TabContainer.new()
	# tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 移除强制填满

	var import_tab := _create_import_tab()
	tab_container.add_child(import_tab)
	import_tab.name = "导入PCK"

	var manage_tab := _create_manage_tab()
	tab_container.add_child(manage_tab)
	manage_tab.name = "关卡管理"

	import_dialog.add_child(tab_container)
	add_child(import_dialog)

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

	# 创建编辑对话框
	edit_dialog = ConfirmationDialog.new()
	edit_dialog.title = "编辑关卡信息"
	edit_dialog.size = Vector2i(400, 500)
	edit_dialog.ok_button_text = "保存"
	edit_dialog.cancel_button_text = "取消"
	edit_dialog.confirmed.connect(_on_edit_confirmed)

	var edit_vbox := VBoxContainer.new()
	# edit_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 移除强制填满

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
	# cover_texture.custom_minimum_size = Vector2(100, 100)  # 自适应大小
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

	# 音乐时段设置
	var music_section_label := Label.new()
	music_section_label.text = "音乐时段设置："
	edit_vbox.add_child(music_section_label)

	var music_grid := GridContainer.new()
	music_grid.columns = 2

	# 开始时间
	var start_label := Label.new()
	start_label.text = "开始时间(秒)："
	music_grid.add_child(start_label)

	music_start_input = SpinBox.new()
	music_start_input.min_value = 0
	music_start_input.max_value = 9999
	music_start_input.step = 0.1
	music_grid.add_child(music_start_input)

	# 持续时长
	var duration_label := Label.new()
	duration_label.text = "持续时长(秒)："
	music_grid.add_child(duration_label)

	music_duration_input = SpinBox.new()
	music_duration_input.min_value = 0
	music_duration_input.max_value = 9999
	music_duration_input.step = 0.1
	music_duration_input.tooltip_text = "0表示播放到结尾"
	music_grid.add_child(music_duration_input)

	# 淡入时长
	var fade_in_label := Label.new()
	fade_in_label.text = "淡入时长(秒)："
	music_grid.add_child(fade_in_label)

	music_fade_in_input = SpinBox.new()
	music_fade_in_input.min_value = 0
	music_fade_in_input.max_value = 10
	music_fade_in_input.step = 0.1
	music_fade_in_input.value = 1.0
	music_grid.add_child(music_fade_in_input)

	# 淡出时长
	var fade_out_label := Label.new()
	fade_out_label.text = "淡出时长(秒)："
	music_grid.add_child(fade_out_label)

	music_fade_out_input = SpinBox.new()
	music_fade_out_input.min_value = 0
	music_fade_out_input.max_value = 10
	music_fade_out_input.step = 0.1
	music_fade_out_input.value = 1.0
	music_grid.add_child(music_fade_out_input)

	edit_vbox.add_child(music_grid)

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

	# 创建删除确认对话框
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = "确认删除"
	delete_confirm_dialog.ok_button_text = "删除"
	delete_confirm_dialog.cancel_button_text = "取消"
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_confirm_dialog)

## 创建导入标签页
func _create_import_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "ImportTab"
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var header := Label.new()
	header.text = "选择 .pck 文件进行验证和导入："
	vbox.add_child(header)

	pck_list = ItemList.new()
	pck_list.custom_minimum_size = Vector2(500, 250)
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

## 创建管理标签页
func _create_manage_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "ManageTab"
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var header := Label.new()
	header.text = "已导入的关卡列表："
	vbox.add_child(header)

	manage_list = ItemList.new()
	manage_list.custom_minimum_size = Vector2(500, 250)
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

## 插件退出场景树时清理资源
func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_TOOLBAR, import_button)
	import_button.queue_free()
	import_dialog.queue_free()
	file_dialog.queue_free()
	overwrite_dialog.queue_free()
	edit_dialog.queue_free()
	cover_file_dialog.queue_free()
	music_file_dialog.queue_free()
	delete_confirm_dialog.queue_free()

## 打开UGC管理对话框
func _on_import_pressed() -> void:
	_refresh_list()
	_refresh_manage_list()
	import_dialog.popup_centered()

## 刷新PCK文件列表显示
func _refresh_list() -> void:
	pck_list.clear()
	for i in pck_entries.size():
		var entry: Dictionary = pck_entries[i]
		pck_list.add_item(_format_entry(entry))

## 格式化PCK条目显示文本
func _format_entry(entry: Dictionary) -> String:
	var name: String = entry.get("file", "")
	var status: int = entry.get("status", VerifyStatus.PENDING)
	var status_text: String = ""
	match status:
		VerifyStatus.PENDING: status_text = "待验证"
		VerifyStatus.PASSED: status_text = "验证通过"
		VerifyStatus.FAILED: status_text = "验证失败"
		VerifyStatus.NO_LEVEL: status_text = "无关卡内容"
	var level_info: Dictionary = entry.get("level_info", {})
	var detail: String = ""
	if not level_info.is_empty():
		var lvl_name: String = level_info.get("name", "")
		if lvl_name != "":
			detail = " - " + lvl_name
		else:
			detail = " - LevelData"
	return "%s [%s]%s" % [name.get_file(), status_text, detail]

## 打开文件选择对话框
func _on_select_pressed() -> void:
	file_dialog.popup_centered(Vector2i(800, 600))

## 处理文件选择完成事件
func _on_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		var already := false
		for entry in pck_entries:
			if entry["file"] == path:
				already = true
				break
		if not already:
			pck_entries.append({
				"file": path,
				"status": VerifyStatus.PENDING,
			})
	_refresh_list()

## 移除选中的PCK条目
func _on_remove_pressed() -> void:
	var selected := pck_list.get_selected_items()
	if selected.is_empty():
		return
	var to_remove: Array[int] = []
	for idx in selected:
		to_remove.append(idx)
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		pck_entries.remove_at(idx)
	_refresh_list()

const PCK_DIR_ACCESS_PATH := "res://addons/PCKManager/PCKDirAccess.gd"

## 验证选中的PCK文件
func _on_verify_pressed() -> void:
	var selected := pck_list.get_selected_items()
	if selected.is_empty():
		EditorInterface.get_editor_toaster().push_toast("请先选择要验证的PCK", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return

	var pck_dir_script := load(PCK_DIR_ACCESS_PATH)
	if pck_dir_script == null:
		EditorInterface.get_editor_toaster().push_toast("无法加载 PCKDirAccess", EditorInterface.get_editor_toaster().SEVERITY_ERROR)
		return

	for idx in selected:
		if idx < 0 or idx >= pck_entries.size():
			continue
		var entry: Dictionary = pck_entries[idx]
		var path: String = entry["file"]
		print("[ugc_import] Verifying: ", path)

		if not FileAccess.file_exists(path):
			print("[ugc_import] FAIL: file does not exist: ", path)
			entry["status"] = VerifyStatus.FAILED
			continue

		var pck_dir: RefCounted = pck_dir_script.new()
		pck_dir.open(path)
		var paths: Array = pck_dir.get_paths()

		if paths.is_empty():
			pck_dir.close()
			print("[ugc_import] FAIL: PCK has no file entries")
			entry["status"] = VerifyStatus.FAILED
			continue

		var level_info := _find_level_data_in_pck(pck_dir, paths)
		pck_dir.close()

		if level_info.is_empty():
			print("[ugc_import] NO_LEVEL: PCK has no level content")
			entry["status"] = VerifyStatus.NO_LEVEL
			entry.erase("level_info")
		else:
			entry["status"] = VerifyStatus.PASSED
			entry["level_info"] = level_info
			print("[ugc_import] PASS: found level: ", level_info)

	_refresh_list()
	EditorInterface.get_editor_toaster().push_toast("验证完成", EditorInterface.get_editor_toaster().SEVERITY_INFO)

## 在PCK中查找关卡数据
func _find_level_data_in_pck(pck_dir: RefCounted, paths: Array) -> Dictionary:
	var scene_dirs: Dictionary = {}
	for p in paths:
		var p_str: String = str(p)
		var clean := p_str.trim_suffix(".remap")
		if not clean.contains("[Scenes]/"):
			continue
		var scenes_idx := clean.find("[Scenes]/")
		var after := clean.substr(scenes_idx + "[Scenes]/".length())
		var parts := after.split("/")
		if parts.size() >= 2:
			var dir_name: String = parts[0]
			var file_name: String = parts[1]
			if not scene_dirs.has(dir_name):
				scene_dirs[dir_name] = {"has_tscn": false, "has_tres": false}
			if file_name.ends_with(".tscn"):
				scene_dirs[dir_name]["has_tscn"] = true
			elif file_name.ends_with(".tres"):
				scene_dirs[dir_name]["has_tres"] = true

	var best_dir: String = ""
	var best_scene_path: String = ""
	for dir_name in scene_dirs:
		var info: Dictionary = scene_dirs[dir_name]
		if info["has_tscn"] and info["has_tres"]:
			best_dir = dir_name
			break

	if best_dir.is_empty():
		for p in paths:
			var p_str: String = str(p).trim_suffix(".remap")
			if p_str.ends_with(".tscn"):
				best_dir = "unknown"
				best_scene_path = p_str.trim_suffix(".remap")
				break
	else:
		for p in paths:
			var p_str: String = str(p).trim_suffix(".remap")
			if p_str.contains("[Scenes]/%s/" % best_dir) and p_str.ends_with(".tscn"):
				best_scene_path = p_str
				break

	if best_dir.is_empty():
		return {}

	var tres_path := _find_tres_in_dir(paths, best_dir)
	var save_id_str := ""
	var author_str := ""
	if not tres_path.is_empty():
		save_id_str = _extract_save_id(pck_dir, tres_path)
		author_str = _extract_authors(pck_dir, tres_path)

	var info: Dictionary = {"name": best_dir, "scene_path": best_scene_path}
	if not save_id_str.is_empty():
		info["save_id"] = save_id_str
	if not author_str.is_empty():
		info["author"] = author_str
	return info


## 在目录中查找tres文件
func _find_tres_in_dir(paths: Array, dir_name: String) -> String:
	for p in paths:
		var p_str: String = str(p).trim_suffix(".remap")
		if dir_name == "unknown":
			if p_str.ends_with(".tres"):
				return p_str
		else:
			if p_str.contains("[Scenes]/%s/" % dir_name) and p_str.ends_with(".tres"):
				return p_str
	return ""


## 从tres文件中提取saveID
func _extract_save_id(pck_dir: RefCounted, tres_path: String) -> String:
	var raw: PackedByteArray = pck_dir.get_buffer(tres_path)
	if raw.is_empty():
		return ""
	var text: String = raw.get_string_from_utf8()
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("saveID"):
			var eq_idx := trimmed.find("=")
			if eq_idx >= 0:
				var val := trimmed.substr(eq_idx + 1).strip_edges()
				return val
	return ""

## 从tres文件中提取authors（Array[AuthorInfo]格式）
func _extract_authors(pck_dir: RefCounted, tres_path: String) -> String:
	var raw: PackedByteArray = pck_dir.get_buffer(tres_path)
	if raw.is_empty():
		return ""
	var text: String = raw.get_string_from_utf8()
	var lines := text.split("\n")
	
	# 查找 authors = Array[ExtResource("...")]([SubResource("..."), ...])
	var author_sub_resource_ids: Array[String] = []
	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.begins_with("authors"):
			# 提取所有 SubResource ID
			var regex := RegEx.new()
			regex.compile("SubResource\\(\"([^\"]+)\"\\)")
			var matches := regex.search_all(trimmed)
			for match in matches:
				author_sub_resource_ids.append(match.get_string(1))
			break
	
	if author_sub_resource_ids.is_empty():
		return ""
	
	# 查找每个 SubResource 的 name 字段
	var author_names: Array[String] = []
	for sub_id in author_sub_resource_ids:
		var in_target := false
		for line in lines:
			var trimmed := line.strip_edges()
			if trimmed.begins_with("[sub_resource") and trimmed.contains(sub_id):
				in_target = true
				continue
			if in_target and trimmed.begins_with("[sub_resource"):
				break  # 进入下一个 sub_resource，停止
			if in_target and trimmed.begins_with("name"):
				var eq_idx := trimmed.find("=")
				if eq_idx >= 0:
					var val := trimmed.substr(eq_idx + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
					if not val.is_empty():
						author_names.append(val)
				break
	
	if author_names.is_empty():
		return ""
	return ", ".join(author_names)


## 确认导入PCK文件
func _on_import_confirmed() -> void:
	var to_import: Array[Dictionary] = []
	for entry in pck_entries:
		if entry["status"] == VerifyStatus.PASSED:
			to_import.append(entry)

	if to_import.is_empty():
		EditorInterface.get_editor_toaster().push_toast("没有验证通过的PCK可导入", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return

	DirAccess.make_dir_recursive_absolute(PCK_OUTPUT_DIR)

	var conflicts: Array[Dictionary] = []
	for entry in to_import:
		var path: String = entry["file"]
		var dest := PCK_OUTPUT_DIR.path_join(path.get_file())
		var global_dest := ProjectSettings.globalize_path(dest)
		if FileAccess.file_exists(global_dest):
			conflicts.append(entry)

	if not conflicts.is_empty():
		_import_with_overwrite_check(to_import, conflicts)
	else:
		_do_import(to_import)

## 处理覆盖确认
func _import_with_overwrite_check(to_import: Array[Dictionary], conflicts: Array[Dictionary]) -> void:
	var conflict_names := conflicts.map(func(e: Dictionary) -> String: return e["file"].get_file())
	overwrite_dialog.get_label().text = "以下PCK文件已存在：\n" + "\n".join(conflict_names) + "\n\n是否覆盖？"
	overwrite_dialog.confirmed.connect(
		func(): _do_import(to_import),
		Object.CONNECT_ONE_SHOT
	)
	overwrite_dialog.canceled.connect(
		func(): _do_import(to_import.filter(func(e: Dictionary) -> bool: return e not in conflicts)),
		Object.CONNECT_ONE_SHOT
	)
	overwrite_dialog.popup_centered()

## 执行PCK导入操作
func _do_import(entries: Array[Dictionary]) -> void:
	var pck_dir_script := load(PCK_DIR_ACCESS_PATH)
	var count := 0
	for entry in entries:
		var path: String = entry["file"]
		var dest := PCK_OUTPUT_DIR.path_join(path.get_file())
		var global_dest := ProjectSettings.globalize_path(dest)
		var err := DirAccess.copy_absolute(path, global_dest)
		if err == OK:
			count += 1
			print("Imported PCK: ", dest)
			# 提取音乐文件
			var music_path := _extract_music_from_pck(dest, pck_dir_script)
			_upsert_level_list(dest, entry, music_path)
		else:
			push_warning("Failed to import PCK: ", path, " error: ", err)

	EditorInterface.get_editor_toaster().push_toast("导入完成！成功 %d 个" % count, EditorInterface.get_editor_toaster().SEVERITY_INFO)
	pck_entries.clear()
	_refresh_list()


## 从PCK中提取音乐文件
func _extract_music_from_pck(pck_res_path: String, pck_dir_script: Script) -> String:
	if pck_dir_script == null:
		return ""

	var pck_dir: RefCounted = pck_dir_script.new()
	pck_dir.open(pck_res_path)
	var paths: Array = pck_dir.get_paths()

	print("[ugc_import] PCK paths: ", paths)

	# 查找音频文件
	var music_extensions := [".mp3", ".ogg", ".wav"]
	var music_path := ""

	for p in paths:
		var p_str: String = str(p).trim_suffix(".remap")
		for ext in music_extensions:
			if p_str.ends_with(ext):
				music_path = p_str
				break
		if not music_path.is_empty():
			break

	if music_path.is_empty():
		pck_dir.close()
		print("[ugc_import] No music file found in PCK")
		return ""

	print("[ugc_import] Found music file: ", music_path)

	# 提取音频文件
	var audio_data = pck_dir.get_buffer(music_path)
	pck_dir.close()

	# 检查返回值是否为null或空
	if audio_data == null:
		print("[ugc_import] get_buffer returned null for: ", music_path)
		return ""

	if audio_data is PackedByteArray and audio_data.is_empty():
		print("[ugc_import] get_buffer returned empty array for: ", music_path)
		return ""

	print("[ugc_import] Audio data size: ", audio_data.size())

	# 保存到pck_levels目录
	var file_name := music_path.get_file()
	var dest_path := PCK_OUTPUT_DIR.path_join(file_name)
	var global_dest := ProjectSettings.globalize_path(dest_path)

	var file := FileAccess.open(global_dest, FileAccess.WRITE)
	if file:
		file.store_buffer(audio_data)
		file.close()
		print("[ugc_import] Extracted music: ", dest_path)
		return dest_path

	print("[ugc_import] Failed to write file: ", global_dest)
	return ""


## 更新或插入关卡列表
func _upsert_level_list(pck_res_path: String, entry: Dictionary, music_path: String = "") -> void:
	var level_info: Dictionary = entry.get("level_info", {})
	var scene_path := _extract_scene_path(pck_res_path, level_info)
	var title: String = level_info.get("name", pck_res_path.get_file().get_basename())
	var save_id: String = level_info.get("save_id", "")
	var author: String = level_info.get("author", "")

	var list: MenuLevelList
	if ResourceLoader.exists(LEVEL_LIST_PATH):
		list = load(LEVEL_LIST_PATH) as MenuLevelList
	if list == null:
		list = MenuLevelList.new()

	# 加载音乐资源
	var music: AudioStream = null
	if not music_path.is_empty():
		music = load(music_path) as AudioStream

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


## 提取场景路径
func _extract_scene_path(pck_path: String, level_info: Dictionary) -> String:
	var scene_path: String = level_info.get("scene_path", "")
	if not scene_path.is_empty():
		return scene_path
	return ""

## 加载关卡列表资源
func _load_level_list() -> MenuLevelList:
	if not ResourceLoader.exists(LEVEL_LIST_PATH):
		return null
	var list = load(LEVEL_LIST_PATH)
	if list is MenuLevelList:
		return list
	push_warning("Failed to load level list: invalid resource type")
	return null

## 保存关卡列表资源
func _save_level_list(list: MenuLevelList) -> void:
	if list == null:
		push_error("Cannot save null level list")
		return
	var err := ResourceSaver.save(list, LEVEL_LIST_PATH)
	if err != OK:
		push_error("Failed to save level list: ", err)
		EditorInterface.get_editor_toaster().push_toast("保存失败", EditorInterface.get_editor_toaster().SEVERITY_ERROR)

## 刷新关卡管理列表显示
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

## 打开编辑选中关卡对话框
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

## 删除选中关卡
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

## 确认删除关卡
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

## 上移选中关卡
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

	var temp := list.levels[idx]
	list.levels[idx] = list.levels[idx - 1]
	list.levels[idx - 1] = temp

	_save_level_list(list)
	_refresh_manage_list()
	manage_list.select(idx - 1)

## 下移选中关卡
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

	var temp := list.levels[idx]
	list.levels[idx] = list.levels[idx + 1]
	list.levels[idx + 1] = temp

	_save_level_list(list)
	_refresh_manage_list()
	manage_list.select(idx + 1)

## 确认编辑关卡信息
func _on_edit_confirmed() -> void:
	if current_editing_level == null:
		return

	current_editing_level.title = edit_title_input.text
	current_editing_level.cover = cover_texture.texture as Texture2D
	current_editing_level.save_id = save_id_input.text
	current_editing_level.author = edit_author_input.text
	current_editing_level.description = edit_description_input.text

	# 保存音乐时段参数
	current_editing_level.music_start = music_start_input.value
	current_editing_level.music_duration = music_duration_input.value
	current_editing_level.music_fade_in = music_fade_in_input.value
	current_editing_level.music_fade_out = music_fade_out_input.value

	var list := _load_level_list()
	if list:
		_save_level_list(list)

	_refresh_manage_list()
	current_editing_level = null

	EditorInterface.get_editor_toaster().push_toast("关卡信息已保存", EditorInterface.get_editor_toaster().SEVERITY_INFO)

## 显示编辑对话框
func _show_edit_dialog(level: MenuLevelData) -> void:
	edit_title_input.text = level.title
	cover_texture.texture = level.cover
	music_label.text = level.music.resource_path.get_file() if level.music else "未选择"
	save_id_input.text = level.save_id
	edit_author_input.text = level.author
	edit_description_input.text = level.description

	# 加载音乐时段参数
	music_start_input.value = level.music_start
	music_duration_input.value = level.music_duration
	music_fade_in_input.value = level.music_fade_in
	music_fade_out_input.value = level.music_fade_out

	edit_dialog.popup_centered()

## 打开封面选择对话框
func _on_select_cover() -> void:
	cover_file_dialog.popup_centered(Vector2i(800, 600))

## 处理封面图片选择
func _on_cover_selected(path: String) -> void:
	var texture := load(path) as Texture2D
	if texture:
		cover_texture.texture = texture

## 打开音乐选择对话框
func _on_select_music() -> void:
	music_file_dialog.popup_centered(Vector2i(800, 600))

## 处理音乐文件选择
func _on_music_selected(path: String) -> void:
	var audio := load(path) as AudioStream
	if audio:
		current_editing_level.music = audio
		music_label.text = path.get_file()
