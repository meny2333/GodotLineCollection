extends Control

@onready var level_list: ItemList = $VBoxContainer/LevelList
@onready var play_button: Button = $VBoxContainer/ButtonContainer/PlayButton
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var load_pck_button: Button = $VBoxContainer/ButtonContainer/LoadPckButton

var levels: Dictionary = {}
var selected_level: String = ""
var loaded_pcks: Array[String] = []

const LEVELS_DIR := "res://levels"
const PCK_DIR := "res://pck_levels"

func _ready() -> void:
	_scan_levels()
	_try_load_pck_level_data()
	_populate_list()
	play_button.disabled = true
	load_pck_button.disabled = true

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

func _populate_list() -> void:
	level_list.clear()
	for level_name in levels:
		var info = levels[level_name]
		var display: String = level_name
		if info["source"] == "PCK" and info["scene"].is_empty():
			display = "[PCK] " + level_name
		level_list.add_item(display)

func _on_level_list_item_selected(index: int) -> void:
	var display_name: String = level_list.get_item_text(index)
	selected_level = display_name.replace("[PCK] ", "")
	play_button.disabled = false
	
	if levels.has(selected_level):
		var info = levels[selected_level]
		var pck_file: String = info["pck"]
		var data: LevelData = info["data"]
		
		if not pck_file.is_empty():
			load_pck_button.disabled = false
			load_pck_button.text = "已加载" if selected_level in loaded_pcks else "加载PCK"
		else:
			load_pck_button.disabled = true
			load_pck_button.text = "加载PCK"
		
		var title: String = data.levelTitle if data else selected_level
		info_label.text = "关卡: %s\n标题: %s" % [selected_level, title]

func _on_play_button_pressed() -> void:
	if selected_level.is_empty() or not levels.has(selected_level):
		return
	
	var info = levels[selected_level]
	var scene_path: String = info["scene"]
	var pck_file: String = info["pck"]
	
	if not pck_file.is_empty() and not selected_level in loaded_pcks:
		_load_pck(pck_file, selected_level)
	
	if scene_path.is_empty():
		scene_path = _find_tscn("levels/" + selected_level)
	
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		info_label.text = "错误: 场景文件不存在"
		return
	
	get_tree().change_scene_to_file(scene_path)

func _on_load_pck_button_pressed() -> void:
	if selected_level.is_empty() or not levels.has(selected_level):
		return
	
	var info = levels[selected_level]
	var pck_file: String = info["pck"]
	
	if pck_file.is_empty():
		info_label.text = "该关卡没有PCK文件"
		return
	
	if selected_level in loaded_pcks:
		info_label.text = "PCK已加载（需重启卸载）"
		return
	
	_load_pck(pck_file, selected_level)

func _load_pck(pck_path: String, level_name: String) -> void:
	var global_path := ProjectSettings.globalize_path(pck_path)
	if not FileAccess.file_exists(global_path):
		info_label.text = "错误: PCK文件不存在"
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
		
		info_label.text = "PCK加载成功: " + level_name
		_populate_list()
	else:
		info_label.text = "错误: PCK加载失败"

func _on_refresh_button_pressed() -> void:
	_scan_levels()
	_try_load_pck_level_data()
	_populate_list()
	selected_level = ""
	play_button.disabled = true
	load_pck_button.disabled = true
	info_label.text = "已刷新关卡列表"
