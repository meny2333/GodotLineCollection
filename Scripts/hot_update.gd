extends Node

const USER_PATCH_DIR := "user://patches/"
const RES_PATCH_DIR := "res://patches/"
const MANIFEST_SETTING := "hot_update/manifest_urls"
const DEFAULT_MANIFEST := "https://raw.githubusercontent.com/godotline/GodotLinePatches/main/manifest.json"
const DEFAULT_PROXY := "https://gh-proxy.com/https://raw.githubusercontent.com/godotline/GodotLinePatches/main/manifest.json"

signal pack_loaded(path: String)
signal update_finished(loaded: int)

var loaded_count: int = 0


func _ready() -> void:
	loaded_count = _loadLocalPacks()
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
			_applyManifest(body.get_string_from_utf8())
			break
	http.queue_free()
	update_finished.emit(loaded_count)


func _applyManifest(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var packs: Variant = parsed.get("packs", [])
	if typeof(packs) != TYPE_ARRAY:
		return
	var cache_dir := ProjectSettings.globalize_path(USER_PATCH_DIR)
	DirAccess.make_dir_recursive_absolute(cache_dir)
	for entry in packs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var filename := str(entry.get("filename", ""))
		if filename.is_empty():
			continue
		var dest := cache_dir.path_join(filename)
		var replace := bool(entry.get("replace", false))
		if FileAccess.file_exists(dest):
			if _loadPack(dest, replace):
				loaded_count += 1
			continue
		var file_url := str(entry.get("url", ""))
		if file_url.is_empty():
			var base := str(parsed.get("base_url", DEFAULT_MANIFEST.get_base_dir() + "/"))
			if not base.ends_with("/"):
				base += "/"
			file_url = base + filename
		if await _download(file_url, dest):
			if _loadPack(dest, replace):
				loaded_count += 1


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
