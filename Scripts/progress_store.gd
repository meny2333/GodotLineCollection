class_name ProgressStore
extends RefCounted

static var _progress: Dictionary = {}

static func update_level(save_id: String, stars: int, percent: int, diamonds: int) -> void:
	var existing: Dictionary = _progress.get(save_id, {})
	_progress[save_id] = {
		"stars": maxi(stars, existing.get("stars", 0)),
		"best_percent": maxi(percent, existing.get("best_percent", 0)),
		"diamonds": maxi(diamonds, existing.get("diamonds", 0)),
	}

static func get_level(save_id: String) -> Dictionary:
	return _progress.get(save_id, {"stars": 0, "best_percent": 0, "diamonds": 0})

static func to_dict() -> Dictionary:
	return _progress.duplicate(true)

static func from_dict(data: Dictionary) -> void:
	_progress.clear()
	for key in data:
		var entry: Dictionary = data[key]
		_progress[key] = {
			"stars": int(entry.get("stars", 0)),
			"best_percent": int(entry.get("best_percent", 0)),
			"diamonds": int(entry.get("diamonds", 0)),
		}

static func clear() -> void:
	_progress.clear()
