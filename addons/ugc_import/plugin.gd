@tool
extends EditorPlugin

var import_button: Button
var import_dialog: ConfirmationDialog
var level_list: ItemList
var source_path_edit: LineEdit
var pack_pck_check: CheckBox

const LEVELS_DIR := "res://levels"
const PCK_OUTPUT_DIR := "res://pck_levels"

func _enter_tree() -> void:
	import_button = Button.new()
	import_button.text = "UGC导入"
	import_button.pressed.connect(_on_import_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, import_button)
	
	import_dialog = ConfirmationDialog.new()
	import_dialog.title = "导入关卡"
	import_dialog.size = Vector2i(600, 520)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var header_label := Label.new()
	header_label.text = "选择要导入的关卡（扫描 LevelData .tres）:"
	vbox.add_child(header_label)
	
	level_list = ItemList.new()
	level_list.custom_minimum_size = Vector2(0, 300)
	level_list.select_mode = 3
	vbox.add_child(level_list)
	
	var path_hbox := HBoxContainer.new()
	path_hbox.add_child(Label.new())
	path_hbox.get_child(0).text = "关卡目录:"
	
	source_path_edit = LineEdit.new()
	source_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_path_edit.text = ProjectSettings.globalize_path(LEVELS_DIR)
	path_hbox.add_child(source_path_edit)
	
	var browse_button := Button.new()
	browse_button.text = "浏览"
	browse_button.pressed.connect(_on_browse_pressed)
	path_hbox.add_child(browse_button)
	
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(_refresh_level_list)
	path_hbox.add_child(refresh_button)
	
	vbox.add_child(path_hbox)
	
	pack_pck_check = CheckBox.new()
	pack_pck_check.text = "同时打包为 .pck 文件"
	vbox.add_child(pack_pck_check)
	
	import_dialog.add_child(vbox)
	import_dialog.confirmed.connect(_on_import_confirmed)
	add_child(import_dialog)

func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_TOOLBAR, import_button)
	import_button.queue_free()
	import_dialog.queue_free()

func _on_import_pressed() -> void:
	_refresh_level_list()
	import_dialog.popup_centered()

func _refresh_level_list() -> void:
	level_list.clear()
	_scan_for_level_data(source_path_edit.text)

func _scan_for_level_data(base_dir: String) -> void:
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			_scan_for_level_data(base_dir.path_join(name))
		elif name.ends_with(".tres"):
			var res_path := base_dir.path_join(name)
			var res := load(res_path)
			if res is LevelData:
				var dir_name: String = base_dir.get_file()
				var display: String = dir_name + "/" + name
				level_list.add_item(display)
				level_list.set_item_metadata(level_list.item_count - 1, {
					"dir": base_dir,
					"tres": res_path,
					"name": name.get_basename()
				})
		name = dir.get_next()
	dir.list_dir_end()

func _on_browse_pressed() -> void:
	import_dialog.hide()
	var dialog := FileDialog.new()
	dialog.title = "选择关卡目录"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String):
		source_path_edit.text = path
		_refresh_level_list()
		dialog.queue_free()
		import_dialog.popup_centered()
	)
	dialog.close_requested.connect(func():
		dialog.queue_free()
		import_dialog.popup_centered()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_import_confirmed() -> void:
	var selected := level_list.get_selected_items()
	if selected.is_empty():
		EditorInterface.get_editor_toaster().push_toast("请先选择关卡", EditorInterface.get_editor_toaster().SEVERITY_WARNING)
		return
	
	var do_pack_pck := pack_pck_check.button_pressed
	DirAccess.make_dir_recursive_absolute(LEVELS_DIR)
	if do_pack_pck:
		DirAccess.make_dir_recursive_absolute(PCK_OUTPUT_DIR)
	
	for index in selected:
		var meta: Dictionary = level_list.get_item_metadata(index)
		_import_level(meta, do_pack_pck)
	
	EditorInterface.get_editor_toaster().push_toast("导入完成！共 %d 个" % selected.size(), EditorInterface.get_editor_toaster().SEVERITY_INFO)

func _import_level(meta: Dictionary, do_pack_pck: bool) -> void:
	var level_name: String = meta["name"]
	var source_dir: String = meta["dir"]
	var target_dir := LEVELS_DIR.path_join(level_name)
	
	DirAccess.make_dir_recursive_absolute(target_dir)
	_copy_directory_recursive(source_dir, target_dir)
	_import_missing_template_resources(source_dir)
	
	if do_pack_pck:
		_pack_to_pck(level_name, target_dir)
	
	print("Imported: ", level_name, " -> ", target_dir)

func _import_missing_template_resources(source_dir: String) -> void:
	var dir := DirAccess.open(source_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			_import_missing_template_resources(source_dir.path_join(name))
		elif name.ends_with(".tscn") or name.ends_with(".tres"):
			_copy_missing_resources(source_dir.path_join(name), source_dir)
		name = dir.get_next()
	dir.list_dir_end()

func _copy_missing_resources(file_path: String, source_dir: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	
	var regex := RegEx.new()
	regex.compile('\\[ext_resource[^\\]]*path="([^"]+)"[^\\]]*\\]')
	var matches := regex.search_all(content)
	for m in matches:
		var res_path := m.get_string(1)
		if res_path.begins_with("res://") and not res_path.begins_with("res://levels/"):
			var global_path := ProjectSettings.globalize_path(res_path)
			if not FileAccess.file_exists(global_path):
				_try_copy_from_source(res_path, source_dir)

func _try_copy_from_source(res_path: String, source_dir: String) -> void:
	var relative_path := res_path.replace("res://", "")
	var template_pos := source_dir.find("#Template")
	var source_project_root: String
	if template_pos >= 0:
		source_project_root = source_dir.left(template_pos).path_join("")
	else:
		source_project_root = source_dir.get_base_dir().get_base_dir()
	var source_file := source_project_root.path_join(relative_path)
	var dest_file := ProjectSettings.globalize_path(res_path)
	
	if not FileAccess.file_exists(source_file):
		push_warning("Source not found: " + source_file)
		return
	
	DirAccess.make_dir_recursive_absolute(dest_file.get_base_dir())
	DirAccess.copy_absolute(source_file, dest_file)
	print("  Copied: ", res_path)
	
	var import_src := source_file + ".import"
	var import_dst := dest_file + ".import"
	if FileAccess.file_exists(import_src):
		DirAccess.copy_absolute(import_src, import_dst)
		print("  Copied import: ", res_path + ".import")
		_copy_imported_cache_files(import_src, source_project_root)

func _copy_imported_cache_files(import_file_path: String, source_project_root: String) -> void:
	var import_file := ConfigFile.new()
	if import_file.load(import_file_path) != OK:
		return
	
	if import_file.has_section_key("remap", "path.s3tc"):
		var cache_path: String = str(import_file.get_value("remap", "path.s3tc", ""))
		if cache_path != "":
			var cache_relative: String = cache_path.replace("res://", "")
			var cache_src: String = source_project_root.path_join(cache_relative)
			var cache_dst: String = ProjectSettings.globalize_path(cache_path)
			if FileAccess.file_exists(cache_src):
				DirAccess.make_dir_recursive_absolute(cache_dst.get_base_dir())
				DirAccess.copy_absolute(cache_src, cache_dst)
				print("  Copied cache: ", cache_path)

func _copy_directory_recursive(source: String, target: String) -> void:
	var dir := DirAccess.open(source)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var src := source.path_join(name)
			var dst := target.path_join(name)
			if dir.current_is_dir():
				DirAccess.make_dir_recursive_absolute(dst)
				_copy_directory_recursive(src, dst)
			else:
				DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
				DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst))
		name = dir.get_next()
	dir.list_dir_end()

func _pack_to_pck(level_name: String, level_dir: String) -> void:
	var pck_path := ProjectSettings.globalize_path(PCK_OUTPUT_DIR).path_join(level_name + ".pck")
	var packer := PCKPacker.new()
	if packer.pck_start(pck_path) != OK:
		return
	_add_dir_to_pck(packer, level_dir, "levels/" + level_name)
	_add_template_resources(packer, level_dir)
	packer.flush()
	print("Packed: ", pck_path)

func _add_template_resources(packer: PCKPacker, level_dir: String) -> void:
	var dir := DirAccess.open(level_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			_add_template_resources(packer, level_dir.path_join(name))
		elif name.ends_with(".tscn") or name.ends_with(".tres"):
			var file_path := level_dir.path_join(name)
			_pack_external_resources(packer, file_path)
		name = dir.get_next()
	dir.list_dir_end()

func _pack_external_resources(packer: PCKPacker, file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	
	var regex := RegEx.new()
	regex.compile('\\[ext_resource[^\\]]*path="([^"]+)"[^\\]]*\\]')
	var matches := regex.search_all(content)
	for m in matches:
		var res_path := m.get_string(1)
		if res_path.begins_with("res://") and not res_path.begins_with("res://levels/"):
			var global_path := ProjectSettings.globalize_path(res_path)
			if FileAccess.file_exists(global_path):
				packer.add_file(res_path, global_path)
				print("  Added template resource: ", res_path)
				_pack_imported_cache(packer, res_path)
			else:
				push_warning("  Template resource not found: " + res_path)

func _pack_imported_cache(packer: PCKPacker, res_path: String) -> void:
	var import_path := res_path + ".import"
	var import_global := ProjectSettings.globalize_path(import_path)
	if not FileAccess.file_exists(import_global):
		return
	
	var import_file := ConfigFile.new()
	if import_file.load(import_global) != OK:
		return
	
	if import_file.has_section_key("remap", "path.s3tc"):
		var cache_path := import_file.get_value("remap", "path.s3tc", "")
		if cache_path != "":
			var cache_global := ProjectSettings.globalize_path(cache_path)
			if FileAccess.file_exists(cache_global):
				packer.add_file(cache_path, cache_global)
				print("  Added imported cache: ", cache_path)
	
	if import_file.has_section_key("deps", "dest_files"):
		var dest_files: PackedStringArray = import_file.get_value("deps", "dest_files", [])
		for dest in dest_files:
			var dest_global := ProjectSettings.globalize_path(dest)
			if FileAccess.file_exists(dest_global):
				packer.add_file(dest, dest_global)

func _add_dir_to_pck(packer: PCKPacker, dir_path: String, prefix: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var file := dir_path.path_join(name)
			var pck := prefix.path_join(name)
			if dir.current_is_dir():
				_add_dir_to_pck(packer, file, pck)
			else:
				packer.add_file(pck, ProjectSettings.globalize_path(file))
		name = dir.get_next()
	dir.list_dir_end()
