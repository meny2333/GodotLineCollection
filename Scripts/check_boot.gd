extends SceneTree

func _init() -> void:
	var failed := 0
	AchievementManager.register("boot_check", "Boot Check", "headless")
	AchievementManager.AddAchievement("boot_check")
	if not AchievementManager.HasAchievement("boot_check"):
		push_error("AchievementManager.AddAchievement failed")
		failed += 1
	var roundtrip := AchievementManager.to_dict()
	if not roundtrip.get("boot_check", false):
		push_error("AchievementManager.to_dict missing key")
		failed += 1
	if ClassDB.class_exists("ImGuiController") == false and Engine.get_singleton("ImGuiGD") == null:
		print("[check_boot] ImGui native singleton not ready yet (ok in --script)")
	if failed > 0:
		push_error("[check_boot] FAILED %d" % failed)
		quit(1)
	else:
		print("[check_boot] OK")
		quit(0)
