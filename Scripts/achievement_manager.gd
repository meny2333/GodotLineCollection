class_name AchievementManager
extends RefCounted

const SAVE_PATH := "user://achievements.cfg"
const LEGACY_SAVE_PATH := "user://playerdata.shl"
const LEGACY_KEY := "shinnline"

static var unlocked: Dictionary = {}
static var catalog: Dictionary = {}
static var _loaded: bool = false

static func register(key: String, title: String, description: String = "") -> void:
	if key.is_empty():
		return
	catalog[key] = {"title": title, "description": description}


static func AddAchievement(key: String) -> void:
	_ensureLoaded()
	if key.is_empty() or unlocked.get(key, false):
		return
	unlocked[key] = true
	_save()
	var title: String = str(catalog.get(key, {}).get("title", key))
	if Engine.get_main_loop() != null and Engine.get_main_loop().root.has_node("/root/PopupToast"):
		PopupToast.show("成就解锁：%s" % title)
	if Engine.get_main_loop() != null and Engine.get_main_loop().root.has_node("/root/CloudArchiveService"):
		CloudArchiveService.queue_save("achievement")


static func HasAchievement(key: String) -> bool:
	_ensureLoaded()
	return bool(unlocked.get(key, false))


static func to_dict() -> Dictionary:
	_ensureLoaded()
	return unlocked.duplicate()


static func from_dict(data: Dictionary) -> void:
	_ensureLoaded()
	for key in data:
		if data[key]:
			unlocked[str(key)] = true
	_save()


static func migrateLegacySave() -> void:
	_ensureLoaded()
	var cfg := ConfigFile.new()
	if cfg.load_encrypted_pass(LEGACY_SAVE_PATH, LEGACY_KEY) != OK:
		return
	var changed := false
	if cfg.has_section("ach"):
		for key in cfg.get_section_keys("ach"):
			if cfg.get_value("ach", key) == 1 and not unlocked.get(key, false):
				unlocked[key] = true
				changed = true
	if changed:
		_save()


static func _ensureLoaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section("unlocked"):
		return
	for key in cfg.get_section_keys("unlocked"):
		if cfg.get_value("unlocked", key, false):
			unlocked[key] = true


static func _save() -> void:
	var cfg := ConfigFile.new()
	for key in unlocked:
		if unlocked[key]:
			cfg.set_value("unlocked", key, true)
	cfg.save(SAVE_PATH)
