extends Node

const USER_PATCH_DIR := "user://patches/"
const RES_PATCH_DIR := "res://patches/"
const MANIFEST_SETTING := "hot_update/manifest_urls"
const DEFAULT_MANIFEST := "https://raw.githubusercontent.com/godotline/GodotLinePatches/main/manifest.json"
const DEFAULT_PROXY := "https://gh-proxy.com/https://raw.githubusercontent.com/godotline/GodotLinePatches/main/manifest.json"

signal pack_loaded(path: String)
signal update_finished(loaded: int)
signal update_available(entries: Array, force: bool)

var loaded_count: int = 0
var pending: Array = []
var force_update: bool = false
var _base_url: String = ""
var _prompt: ConfirmationDialog = null


func _ready() -> void:
	loaded_count = _loadLocalPacks()
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--script"):
		update_finished.emit(loaded_count)
		return
	_fetchRemote()


func extra_search_dirs() -> PackedStringArray:
	return _settingStrings("hot_update/search_dirs")


func extra_manifest_urls() -> PackedStringArray:
	return _settingStrings(MANIFEST_SETTING)


func _settingStrings(name: String) -> PackedStringArray:
	var setting: Variant = ProjectSettings.get_setting(name, PackedStringArray())
	if setting is PackedStringArray:
		return setting
	if setting is Array:
		var out := PackedStringArray()
		for item in setting:
			out.append(str(item))
		return out
	if setting is String and not setting.is_empty():
		return PackedStringArray([setting])
	return PackedStringArray()


func _searchDirs() -> PackedStringArray:
	var dirs := PackedStringArray([
		ProjectSettings.globalize_path(RES_PATCH_DIR),
		OS.get_executable_path().get_base_dir().path_join("patches"),
		ProjectSettings.globalize_path(USER_PATCH_DIR),
	])
	dirs.append_array(extra_search_dirs())
	return dirs


func _loadLocalPacks() -> int:
	var count := 0
	for dir_path in _searchDirs():
		if dir_path.is_empty() or not DirAccess.dir_exists_absolute(dir_path):
			continue
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var packs: Array[String] = []
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.to_lower().ends_with(".pck"):
				packs.append(name)
			name = dir.get_next()
		dir.list_dir_end()
		packs.sort()
		for file_name in packs:
			if _loadPack(dir_path.path_join(file_name), false):
				count += 1
	print("[HotUpdate] loaded %d local pack(s)" % count)
	return count


func _loadPack(abs_path: String, replace: bool) -> bool:
	if not FileAccess.file_exists(abs_path):
		return false
	var ok := ProjectSettings.load_resource_pack(abs_path, replace)
	if ok:
		pack_loaded.emit(abs_path)
		print("[HotUpdate] loaded %s replace=%s" % [abs_path, replace])
	else:
		push_warning("[HotUpdate] failed: %s" % abs_path)
	return ok


func _manifestUrls() -> PackedStringArray:
	var urls := extra_manifest_urls()
	if urls.is_empty():
		urls = PackedStringArray([DEFAULT_MANIFEST, DEFAULT_PROXY])
	return urls


func _fetchRemote() -> void:
	var urls := _manifestUrls()
	if urls.is_empty():
		update_finished.emit(loaded_count)
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 15.0
	for url in urls:
		if url.is_empty():
			continue
		var err := http.request(url)
		if err != OK:
			continue
		var result: Array = await http.request_completed
		var code: int = result[1]
		var body: PackedByteArray = result[3]
		if code == 200 and body.size() > 0:
			_parseManifest(body.get_string_from_utf8())
			break
	http.queue_free()
	if pending.is_empty():
		update_finished.emit(loaded_count)
		return
	update_available.emit(pending, force_update)
	_promptUpdate()


func _parseManifest(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	force_update = bool(parsed.get("force", false))
	_base_url = str(parsed.get("base_url", DEFAULT_MANIFEST.get_base_dir() + "/"))
	if not _base_url.ends_with("/"):
		_base_url += "/"
	var packs: Variant = parsed.get("packs", [])
	if typeof(packs) != TYPE_ARRAY:
		return
	var cache_dir := ProjectSettings.globalize_path(USER_PATCH_DIR)
	DirAccess.make_dir_recursive_absolute(cache_dir)
	pending.clear()
	for entry in packs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var filename := str(entry.get("filename", ""))
		if filename.is_empty():
			continue
		if bool(entry.get("force", false)):
			force_update = true
		var dest := cache_dir.path_join(filename)
		if FileAccess.file_exists(dest):
			if _loadPack(dest, bool(entry.get("replace", false))):
				loaded_count += 1
			continue
		pending.append(entry)


func _promptUpdate() -> void:
	if pending.is_empty():
		update_finished.emit(loaded_count)
		return
	var names: PackedStringArray = PackedStringArray()
	for entry in pending:
		names.append(str(entry.get("filename", "pack")))
	var dlg := ConfirmationDialog.new()
	dlg.title = "发现更新" if not force_update else "必须更新"
	dlg.dialog_text = "发现热更新：\n%s" % "\n".join(names)
	dlg.ok_button_text = "更新"
	dlg.cancel_button_text = "退出" if force_update else "稍后"
	dlg.confirmed.connect(_onAccept)
	if force_update:
		dlg.canceled.connect(_onForceCancel)
	else:
		dlg.canceled.connect(_onSkip)
	add_child(dlg)
	_prompt = dlg
	dlg.popup_centered()


func _onAccept() -> void:
	await _downloadPending()
	update_finished.emit(loaded_count)
	if _prompt:
		_prompt.queue_free()
		_prompt = null


func _onSkip() -> void:
	pending.clear()
	update_finished.emit(loaded_count)
	if _prompt:
		_prompt.queue_free()
		_prompt = null


func _onForceCancel() -> void:
	get_tree().quit()


func _downloadPending() -> void:
	var cache_dir := ProjectSettings.globalize_path(USER_PATCH_DIR)
	for entry in pending:
		var filename := str(entry.get("filename", ""))
		var dest := cache_dir.path_join(filename)
		var file_url := str(entry.get("url", ""))
		if file_url.is_empty():
			file_url = _base_url + filename
		if await _download(file_url, dest):
			if _loadPack(dest, bool(entry.get("replace", false))):
				loaded_count += 1
	pending.clear()


func _download(url: String, dest: String) -> bool:
	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		return false
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 60.0
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return false
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var body: PackedByteArray = result[3]
	if code != 200 or body.is_empty():
		return false
	var file := FileAccess.open(dest, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(body)
	return true
