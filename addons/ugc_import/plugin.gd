@tool
extends EditorPlugin

var import_button: Button
var import_dialog: ConfirmationDialog
var pck_list: ItemList
var select_button: Button
var verify_button: Button
var file_dialog: FileDialog
var overwrite_dialog: ConfirmationDialog

var pck_entries: Array[Dictionary] = []

const PCK_OUTPUT_DIR := "res://pck_levels"
const LEVEL_LIST_PATH := "res://pck_levels/level_list.tres"

enum VerifyStatus {
	PENDING,
	PASSED,
	FAILED,
	NO_LEVEL,
}

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

func _create_manage_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "ManageTab"

	var header := Label.new()
	header.text = "已导入的关卡列表："
	vbox.add_child(header)

	return vbox

func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_TOOLBAR, import_button)
	import_button.queue_free()
	import_dialog.queue_free()
	file_dialog.queue_free()
	overwrite_dialog.queue_free()

func _on_import_pressed() -> void:
	_refresh_list()
	import_dialog.popup_centered()

func _refresh_list() -> void:
	pck_list.clear()
	for i in pck_entries.size():
		var entry: Dictionary = pck_entries[i]
		pck_list.add_item(_format_entry(entry))

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

func _on_select_pressed() -> void:
	file_dialog.popup_centered(Vector2i(800, 600))

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
	if not tres_path.is_empty():
		save_id_str = _extract_save_id(pck_dir, tres_path)

	var info: Dictionary = {"name": best_dir, "scene_path": best_scene_path}
	if not save_id_str.is_empty():
		info["save_id"] = save_id_str
	return info


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

func _do_import(entries: Array[Dictionary]) -> void:
	var count := 0
	for entry in entries:
		var path: String = entry["file"]
		var dest := PCK_OUTPUT_DIR.path_join(path.get_file())
		var global_dest := ProjectSettings.globalize_path(dest)
		var err := DirAccess.copy_absolute(path, global_dest)
		if err == OK:
			count += 1
			print("Imported PCK: ", dest)
			_upsert_level_list(dest, entry)
		else:
			push_warning("Failed to import PCK: ", path, " error: ", err)

	EditorInterface.get_editor_toaster().push_toast("导入完成！成功 %d 个" % count, EditorInterface.get_editor_toaster().SEVERITY_INFO)
	pck_entries.clear()
	_refresh_list()


func _upsert_level_list(pck_res_path: String, entry: Dictionary) -> void:
	var level_info: Dictionary = entry.get("level_info", {})
	var scene_path := _extract_scene_path(pck_res_path, level_info)
	var title: String = level_info.get("name", pck_res_path.get_file().get_basename())
	var save_id: String = level_info.get("save_id", "")

	var list: MenuLevelList
	if ResourceLoader.exists(LEVEL_LIST_PATH):
		list = load(LEVEL_LIST_PATH) as MenuLevelList
	if list == null:
		list = MenuLevelList.new()

	for data in list.levels:
		if data.pck_path == pck_res_path:
			data.title = title
			data.scene_path = scene_path
			if not save_id.is_empty():
				data.save_id = save_id
			ResourceSaver.save(list, LEVEL_LIST_PATH)
			return

	var data := MenuLevelData.new()
	data.title = title
	data.pck_path = pck_res_path
	data.scene_path = scene_path
	data.save_id = save_id
	list.levels.append(data)
	ResourceSaver.save(list, LEVEL_LIST_PATH)


func _extract_scene_path(pck_path: String, level_info: Dictionary) -> String:
	var scene_path: String = level_info.get("scene_path", "")
	if not scene_path.is_empty():
		return scene_path
	return ""
