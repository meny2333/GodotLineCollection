# Cloud Progress Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save per-level progress (stars, best percent, diamonds) to GAS cloud archive on death, display in menu, no local persistence.

**Architecture:** ProgressStore static class holds in-memory progress keyed by save_id. Menu LevelManager passes save_id before scene change. CustomGameUI triggers cloud save on death. GASArchiveAdapter reads from ProgressStore when menu node is absent.

**Tech Stack:** Godot 4.6, GDScript, GAS SDK (ArchiveService, GASArchiveAdapter, CloudArchiveService)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `Scripts/progress_store.gd` | In-memory per-level progress store |
| Modify | `Scripts/MenuLevelData.gd` | Add `save_id` export field |
| Modify | `Scripts/gas/gas_archive_adapter.gd` | Fallback to ProgressStore when menu node absent |
| Modify | `Scripts/LevelManager.gd` | Set save_id on start, implement save/load stubs, progress badge |
| Modify | `Scripts/CustomGameUI.gd` | Trigger save on death UI show |

---

### Task 1: Create ProgressStore

**Files:**
- Create: `Scripts/progress_store.gd`

- [ ] **Step 1: Create the ProgressStore class**

```gdscript
class_name ProgressStore
extends RefCounted

static var _progress: Dictionary = {}
static var current_save_id: String = ""

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
	for key: String in data:
		var entry: Dictionary = data[key]
		_progress[key] = {
			"stars": int(entry.get("stars", 0)),
			"best_percent": int(entry.get("best_percent", 0)),
			"diamonds": int(entry.get("diamonds", 0)),
		}

static func clear() -> void:
	_progress.clear()
```

- [ ] **Step 2: Verify file exists and has correct class_name**

Open the file in Godot editor — it should be recognized as `ProgressStore` class.

---

### Task 2: Add save_id to MenuLevelData

**Files:**
- Modify: `Scripts/MenuLevelData.gd`

- [ ] **Step 1: Add save_id export field**

Add after the existing exports:

```gdscript
@export var save_id: String = ""
```

Full file after edit:

```gdscript
@tool
class_name MenuLevelData
extends Resource

@export var cover: Texture2D
@export var music: AudioStream
@export var pck_path: String = ""
@export var title: String = ""
@export var scene_path: String = ""
@export var save_id: String = ""
```

- [ ] **Step 2: Verify in Godot editor**

Open any `.tres` level list resource — the `save_id` field should appear in the inspector.

---

### Task 3: Update GASArchiveAdapter with Fallback

**Files:**
- Modify: `Scripts/gas/gas_archive_adapter.gd:22-29`

- [ ] **Step 1: Update `_collect_game_state()` to fallback to ProgressStore**

Replace the `_collect_game_state` method:

```gdscript
func _collect_game_state() -> Dictionary:
	var state: Dictionary = {}
	if Engine.get_main_loop().root.has_node("/root/LevelManager"):
		var lm: Node = Engine.get_main_loop().root.get_node("/root/LevelManager")
		if lm.has_method("get_save_data"):
			state = lm.get_save_data()
	else:
		state = {"level_progress": ProgressStore.to_dict()}
	state["cloud_save_time"] = Time.get_datetime_string_from_system()
	return state
```

- [ ] **Step 2: Verify no syntax errors**

Open Godot editor — the script should load without errors.

---

### Task 4: Update Menu LevelManager

**Files:**
- Modify: `Scripts/LevelManager.gd`

This task has 3 sub-parts: set save_id on start, implement save/load stubs, add progress badge.

#### Task 4a: Set save_id Before Scene Change

- [ ] **Step 1: Update `_start_level()` to set ProgressStore.current_save_id**

In `Scripts/LevelManager.gd`, find `_start_level()` (line 310) and add the save_id assignment after getting `data`:

```gdscript
func _start_level() -> void:
	var data: MenuLevelData = levels[current_index]
	ProgressStore.current_save_id = data.save_id
	if data.pck_path.is_empty():
		info_label.text = "未配置PCK文件"
		return

	var key: String = data.resource_path if data.resource_path != "" else data.title
	if not key in loaded_pcks:
		_load_pck(data.pck_path, key)

	var scene: String = data.scene_path
	if scene.is_empty():
		info_label.text = "未配置场景路径"
		return

	get_tree().change_scene_to_file(scene)
```

#### Task 4b: Implement get_save_data and apply_save_data

- [ ] **Step 2: Replace empty stubs at lines 391-396**

```gdscript
func get_save_data() -> Dictionary:
	return {
		"level_progress": ProgressStore.to_dict(),
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("level_progress"):
		ProgressStore.from_dict(data["level_progress"])
	_update_display()
```

#### Task 4c: Add Progress Badge to Display

- [ ] **Step 3: Create `_make_progress_label()` helper**

Add this new method after `_update_user_display()`:

```gdscript
var _progress_label: Label

func _ensure_progress_label() -> void:
	if _progress_label:
		return
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_container.add_child(_progress_label)
	info_container.move_child(_progress_label, 0)
```

- [ ] **Step 4: Update `_update_display()` to show progress**

In `_update_display()`, after setting `level_title.text` (line 185), add:

```gdscript
	_ensure_progress_label()
	var sid: String = data.save_id
	if not sid.is_empty():
		var prog: Dictionary = ProgressStore.get_level(sid)
		var stars: int = prog.get("stars", 0)
		var pct: int = prog.get("best_percent", 0)
		var dia: int = prog.get("diamonds", 0)
		var star_str: String = ""
		for i in range(3):
			star_str += "★" if i < stars else "☆"
		_progress_label.text = "%s  %d%%  💎%d" % [star_str, pct, dia]
		_progress_label.visible = true
	else:
		_progress_label.visible = false
```

Also add an early return path — inside the `if levels.is_empty():` block (line 165), hide the progress label:

```gdscript
	if levels.is_empty():
		level_title.text = "暂无关卡"
		author_label.text = ""
		_texture.texture = null
		left_arrow.visible = false
		right_arrow.visible = false
		counter_label.text = ""
		if _progress_label:
			_progress_label.visible = false
		return
```

- [ ] **Step 5: Update list view to show progress**

In `_update_list()`, after creating each button (line 235), append progress text:

```gdscript
	for i in range(levels.size()):
		var data := levels[i]
		var btn := Button.new()
		var title_text: String = "  %d. %s" % [i + 1, data.title if data.title != "" else "未命名关卡"]
		var sid: String = data.save_id
		if not sid.is_empty():
			var prog: Dictionary = ProgressStore.get_level(sid)
			var stars: int = prog.get("stars", 0)
			var pct: int = prog.get("best_percent", 0)
			var star_str: String = ""
			for j in range(3):
				star_str += "★" if j < stars else "☆"
			title_text += "  %s %d%%" % [star_str, pct]
		btn.text = title_text
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 44
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# ... rest of existing button setup
```

- [ ] **Step 6: Verify in Godot editor**

Run the menu scene — the progress label should appear above the level title (showing `☆☆☆  0%  💎0` for levels with no progress).

---

### Task 5: Trigger Cloud Save on Death

**Files:**
- Modify: `Scripts/CustomGameUI.gd`

- [ ] **Step 1: Add `_save_progress()` method**

Add after `_hide_revive()`:

```gdscript
func _save_progress() -> void:
	var save_id: String = ProgressStore.current_save_id
	if save_id.is_empty():
		return
	ProgressStore.update_level(save_id, LevelManager.crown, LevelManager.percent, LevelManager.diamond)
	CloudArchiveService.queue_save("game_progress")
```

- [ ] **Step 2: Call `_save_progress()` from `_show_revive()`**

Update `_show_revive()`:

```gdscript
func _show_revive() -> void:
	if _shown: return
	_shown = true
	ui_layer.visible = true
	_update_ui_data()
	_save_progress()
```

- [ ] **Step 3: Verify in Godot editor**

Play a level, die, and check the Godot output console for `[CloudArchiveService] Cloud save successful` (appears after 2-second debounce).

---

## Verification Checklist

After all tasks:

1. **Menu scene loads without errors** — no script errors in Godot output
2. **Progress badge shows** — `☆☆☆  0%  💎0` on levels with save_id set
3. **Death triggers save** — die in a level, check console for cloud save log
4. **Login fetches progress** — log in, return to menu, progress badge updates
5. **Best-run merge** — play same level twice with different scores, only the best is kept
6. **No local files** — no progress data written to `user://` (check with file explorer)
