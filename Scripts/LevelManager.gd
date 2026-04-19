extends Control

@onready var level_title: Label = $Margin/VBox/Info/LevelTitle
@onready var author_label: Label = $Margin/VBox/Info/AuthorLabel
@onready var preview_label: Label = $Margin/VBox/Preview/PreviewRow/PreviewPanel/CenterContainer/PreviewLabel
@onready var left_arrow: Button = $Margin/VBox/Preview/PreviewRow/LeftArrow
@onready var right_arrow: Button = $Margin/VBox/Preview/PreviewRow/RightArrow
@onready var user_button: Button = $Margin/VBox/Header/UserButton
@onready var play_button: Button = $Margin/VBox/Info/Actions/PlayButton
@onready var info_button: Button = $Margin/VBox/Info/Actions/InfoButton
@onready var bookmark_button: Button = $Margin/VBox/Info/Actions/BookmarkButton
@onready var stars_label: Label = $Margin/VBox/Info/Actions/StarsLabel
@onready var counter_label: Label = $Margin/VBox/Preview/CounterLabel
@onready var load_pck_button: Button = $Margin/VBox/Bottom/LoadPckButton
@onready var info_label: Label = $Margin/VBox/Bottom/InfoLabel

var levels: Dictionary = {}
var level_keys: Array = []
var current_index: int = 0
var loaded_pcks: Array[String] = []
var _bookmarks: Dictionary = {}

const LEVELS_DIR := "res://levels"
const PCK_DIR := "res://pck_levels"
const BOOKMARK_PATH := "user://bookmarks.cfg"

func _ready() -> void:
	_load_bookmarks()
	_scan_levels()
	_try_load_pck_level_data()
	_rebuild_keys()
	_update_display()
	_update_login_state()


func _rebuild_keys() -> void:
	level_keys = levels.keys()


func _update_display() -> void:
	if level_keys.is_empty():
		level_title.text = "暂无关卡"
		author_label.text = ""
		preview_label.text = ""
		play_button.disabled = true
		load_pck_button.disabled = true
		left_arrow.visible = false
		right_arrow.visible = false
		counter_label.text = ""
		bookmark_button.text = "收藏"
		return
	
	left_arrow.visible = level_keys.size() > 1
	right_arrow.visible = level_keys.size() > 1
	
	var key: String = str(level_keys[current_index])
	var info = levels[key]
	var data: LevelData = info["data"]
	var title: String = data.levelTitle if data else key
	var source: String = info["source"]
	
	var authors_text := ""
	if data and data.authors.size() > 0:
		var names: PackedStringArray = []
		for a in data.authors:
			if a and a.name != "":
				names.append(a.name)
		if names.size() > 0:
			authors_text = "  ".join(names)
	if authors_text == "":
		authors_text = "来源: %s" % source
	
	level_title.text = title
	author_label.text = authors_text
	preview_label.text = key
	counter_label.text = "%d / %d" % [current_index + 1, level_keys.size()]
	
	play_button.disabled = false
	bookmark_button.text = "已收藏" if _bookmarks.has(key) else "收藏"
	
	var pck_file: String = info["pck"]
	if not pck_file.is_empty():
		load_pck_button.disabled = key in loaded_pcks
		load_pck_button.text = "已加载" if key in loaded_pcks else "加载PCK"
	else:
		load_pck_button.disabled = true
		load_pck_button.text = "加载PCK"
	
	info_label.text = ""


func _on_left_arrow() -> void:
	if level_keys.is_empty():
		return
	current_index = (current_index - 1 + level_keys.size()) % level_keys.size()
	_update_display()


func _on_right_arrow() -> void:
	if level_keys.is_empty():
		return
	current_index = (current_index + 1) % level_keys.size()
	_update_display()


func _on_play_button_pressed() -> void:
	if level_keys.is_empty():
		return
	var key: String = str(level_keys[current_index])
	if not levels.has(key):
		return
	
	var info = levels[key]
	var scene_path: String = info["scene"]
	var pck_file: String = info["pck"]
	
	if not pck_file.is_empty() and not key in loaded_pcks:
		_load_pck(pck_file, key)
	
	if scene_path.is_empty():
		scene_path = _find_tscn("levels/" + key)
	
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		info_label.text = "场景文件不存在"
		return
	
	get_tree().change_scene_to_file(scene_path)


func _on_info_button() -> void:
	if level_keys.is_empty():
		return
	var key: String = str(level_keys[current_index])
	if not levels.has(key):
		return
	var info = levels[key]
	var data: LevelData = info["data"]
	var title: String = data.levelTitle if data else key
	var source: String = info["source"]
	var detail := "关卡: %s\n来源: %s" % [title, source]
	if data:
		detail += "\n速度: %.1f" % data.speed
		if data.authors.size() > 0:
			detail += "\n作者: "
			for a in data.authors:
				if a:
					detail += a.name
					if a.page_url != "":
						detail += " (%s)" % a.page_url
					detail += " "
	if not info["pck"].is_empty():
		detail += "\nPCK: %s" % info["pck"]
	info_label.text = detail


func _on_bookmark_button() -> void:
	if level_keys.is_empty():
		return
	var key: String = str(level_keys[current_index])
	if _bookmarks.has(key):
		_bookmarks.erase(key)
		bookmark_button.text = "收藏"
	else:
		_bookmarks[key] = true
		bookmark_button.text = "已收藏"
	_save_bookmarks()


func _on_load_pck_button_pressed() -> void:
	if level_keys.is_empty():
		return
	var key: String = str(level_keys[current_index])
	if not levels.has(key):
		return
	var info = levels[key]
	var pck_file: String = info["pck"]
	if pck_file.is_empty() or key in loaded_pcks:
		return
	_load_pck(pck_file, key)


func _on_refresh_button_pressed() -> void:
	_scan_levels()
	_try_load_pck_level_data()
	_rebuild_keys()
	current_index = 0
	_update_display()
	info_label.text = "已刷新"


func _on_login_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/gas_login.tscn")


func _update_login_state() -> void:
	if CloudArchiveService.has_credentials():
		var config := GASLoginConfig.new()
		if config.load():
			user_button.text = config.email
		else:
			user_button.text = "用户"
	else:
		user_button.text = "登录"


func _load_bookmarks() -> void:
	var config := ConfigFile.new()
	if config.load(BOOKMARK_PATH) == OK:
		for key in config.get_section_keys("bookmarks"):
			_bookmarks[key] = true


func _save_bookmarks() -> void:
	var config := ConfigFile.new()
	config.erase_section("bookmarks")
	for key in _bookmarks:
		config.set_value("bookmarks", key, true)
	config.save(BOOKMARK_PATH)


func _scan_levels() -> void:
	levels.clear()
	_scan_directory(LEVELS_DIR)
	_scan_pck_directory(PCK_DIR)


func _scan_directory(base_dir: String) -> void:
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			_scan_directory(base_dir.path_join(name))
		elif name.ends_with(".tres"):
			var res_path := base_dir.path_join(name)
			var res := load(res_path)
			if res is LevelData:
				var level_name: String = name.get_basename()
				var tscn_file: String = _find_tscn(base_dir)
				levels[level_name] = {
					"tres": res_path,
					"scene": tscn_file,
					"data": res,
					"source": "目录",
					"pck": ""
				}
		name = dir.get_next()
	dir.list_dir_end()


func _find_tscn(dir_path: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tscn"):
			return dir_path.path_join(name)
		name = dir.get_next()
	dir.list_dir_end()
	return ""


func _scan_pck_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".pck"):
			var level_name: String = name.get_basename()
			var pck_path: String = dir_path.path_join(name)
			var level_paths := _find_level_paths_in_pck(pck_path)
			if not levels.has(level_name):
				levels[level_name] = {
					"tres": level_paths.get("tres", ""),
					"scene": level_paths.get("scene", ""),
					"data": null,
					"source": "PCK",
					"pck": pck_path
				}
			else:
				levels[level_name]["pck"] = pck_path
				if levels[level_name]["tres"].is_empty() and level_paths.has("tres"):
					levels[level_name]["tres"] = level_paths["tres"]
				if levels[level_name]["scene"].is_empty() and level_paths.has("scene"):
					levels[level_name]["scene"] = level_paths["scene"]
		name = dir.get_next()
	dir.list_dir_end()


func _find_level_paths_in_pck(pck_path: String) -> Dictionary:
	var pck_dir_script := load("res://addons/PCKManager/PCKDirAccess.gd")
	if pck_dir_script == null:
		return {}
	var pck_dir: RefCounted = pck_dir_script.new()
	pck_dir.open(ProjectSettings.globalize_path(pck_path))
	var paths: Array = pck_dir.get_paths()
	pck_dir.close()
	
	var scene_dirs: Dictionary = {}
	for p in paths:
		var p_str: String = str(p).trim_suffix(".remap")
		if not p_str.contains("[Scenes]/"):
			continue
		var scenes_idx := p_str.find("[Scenes]/")
		var after := p_str.substr(scenes_idx + "[Scenes]/".length())
		var parts := after.split("/")
		if parts.size() < 2:
			continue
		var dir_name: String = parts[0]
		var file_name: String = parts[1]
		if not scene_dirs.has(dir_name):
			scene_dirs[dir_name] = {"has_tscn": false, "has_tres": false, "tscn_path": "", "tres_path": ""}
		if file_name.ends_with(".tscn"):
			scene_dirs[dir_name]["has_tscn"] = true
			scene_dirs[dir_name]["tscn_path"] = "res://" + p_str
		elif file_name.ends_with(".tres"):
			scene_dirs[dir_name]["has_tres"] = true
			scene_dirs[dir_name]["tres_path"] = "res://" + p_str
	
	for dir_name in scene_dirs:
		var info: Dictionary = scene_dirs[dir_name]
		if info["has_tscn"] and info["has_tres"]:
			return {"name": dir_name, "scene": info["tscn_path"], "tres": info["tres_path"]}
	return {}


func _try_load_pck_level_data() -> void:
	for level_name in levels:
		var info = levels[level_name]
		if info["source"] != "PCK" or info["data"] != null:
			continue
		var tres_path: String = info["tres"]
		if tres_path.is_empty():
			continue
		if ResourceLoader.exists(tres_path):
			var res := load(tres_path)
			if res is LevelData:
				info["data"] = res


func _load_pck(pck_path: String, level_name: String) -> void:
	var global_path := ProjectSettings.globalize_path(pck_path)
	if not FileAccess.file_exists(global_path):
		info_label.text = "PCK文件不存在"
		return
	
	var success := ProjectSettings.load_resource_pack(global_path)
	if success:
		loaded_pcks.append(level_name)
		load_pck_button.text = "已加载"
		load_pck_button.disabled = true
		
		if levels.has(level_name):
			var tres_path: String = levels[level_name]["tres"]
			if not tres_path.is_empty() and ResourceLoader.exists(tres_path):
				var res := load(tres_path)
				if res is LevelData:
					levels[level_name]["data"] = res
			var scene_path: String = levels[level_name]["scene"]
			if scene_path.is_empty():
				scene_path = _find_tscn("levels/" + level_name)
			if not scene_path.is_empty():
				levels[level_name]["scene"] = scene_path
		
		info_label.text = "PCK加载成功"
		_update_display()
	else:
		info_label.text = "PCK加载失败"


func get_save_data() -> Dictionary:
	return {}


func apply_save_data(data: Dictionary) -> void:
	pass
