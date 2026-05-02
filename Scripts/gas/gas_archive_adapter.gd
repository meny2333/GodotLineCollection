class_name GASArchiveAdapter
extends RefCounted


func to_cloud_json() -> String:
	var save_data: Dictionary = _collect_game_state()
	return JSON.stringify(save_data)


func apply_cloud_json(json: String) -> void:
	var parsed: JSON = JSON.new()
	if parsed.parse(json) != OK:
		push_error("[GASArchiveAdapter] Failed to parse cloud JSON: %s" % parsed.get_error_message())
		return
	var data: Variant = parsed.data
	if data == null or not data is Dictionary:
		push_error("[GASArchiveAdapter] Cloud JSON is not a dictionary")
		return
	print("[GASArchiveAdapter] applying cloud data: ", data)
	_apply_game_state(data)


func _collect_game_state() -> Dictionary:
	var state: Dictionary = {}
	if Engine.get_main_loop().root.has_node("/root/LevelManager"):
		var lm: Node = Engine.get_main_loop().root.get_node("/root/LevelManager")
		if lm.has_method("get_save_data"):
			state = lm.get_save_data()
	else:
		state = {"level_progress": ProgressStore.to_dict()}
	var progress: Dictionary = state.get("level_progress", {})
	if not progress.is_empty():
		state["cloud_save_time"] = Time.get_datetime_string_from_system()
	return state


func _apply_game_state(data: Dictionary) -> void:
	if Engine.get_main_loop().root.has_node("/root/LevelManager"):
		var lm: Node = Engine.get_main_loop().root.get_node("/root/LevelManager")
		if lm.has_method("apply_save_data"):
			print("[GASArchiveAdapter] calling apply_save_data on menu LevelManager")
			lm.apply_save_data(data)
		else:
			print("[GASArchiveAdapter] menu LevelManager has no apply_save_data method")
	else:
		print("[GASArchiveAdapter] menu LevelManager node not found, storing as pending")
		CloudArchiveService._pending_cloud_json = JSON.stringify(data)
