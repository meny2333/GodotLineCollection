extends SceneTree

func _init() -> void:
	var failed := 0
	var manager: GDScript = load("res://Scripts/achievement_manager.gd") as GDScript
	if manager == null:
		push_error("AchievementManager failed to load")
		quit(1)
		return
	manager.register("boot_check", "Boot Check", "headless")
	manager.AddAchievement("boot_check")
	if not manager.HasAchievement("boot_check"):
		push_error("AchievementManager.AddAchievement failed")
		failed += 1
	var roundtrip: Dictionary = manager.to_dict()
	if not roundtrip.get("boot_check", false):
		push_error("AchievementManager.to_dict missing key")
		failed += 1
	var hot: GDScript = load("res://Scripts/hot_update.gd") as GDScript
	if hot == null:
		push_error("HotUpdate failed to load")
		failed += 1
	if failed > 0:
		push_error("[check_boot] FAILED %d" % failed)
		quit(1)
	else:
		print("[check_boot] OK")
		quit(0)
