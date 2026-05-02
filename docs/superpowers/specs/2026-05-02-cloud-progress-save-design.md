# Cloud Progress Save Design

## Overview

Save per-level progress (stars, best percent, diamonds) to GAS cloud archive when the death UI shows. Display progress on the menu scene. No local file persistence — progress lives in-memory and in the cloud.

## Architecture

```
In-Game (death)              Menu Scene
┌──────────────┐            ┌───────────────────┐
│ CustomGameUI  │            │ LevelManager.gd   │
│ _show_revive  │            │ (menu scene)      │
│       │       │            │       │           │
│       ▼       │            │       ▼           │
│ ProgressStore │◄──────────│ ProgressStore     │
│ .update()     │  shared   │ .get_level()      │
│       │       │  memory   │       │           │
│       ▼       │            │       ▼           │
│ CloudArchive  │            │ UI: stars/%/dia   │
│ queue_save()  │            │ on each level card│
└──────────────┘            └───────────────────┘
        │                            │
        └──────────┬─────────────────┘
                   ▼
          GAS Archive API (cloud JSON)
```

## Components

### 1. ProgressStore — New Static Class

**File:** `Scripts/progress_store.gd`

In-memory store for per-level progress. No autoload needed — uses static vars.

```gdscript
class_name ProgressStore
extends RefCounted

static var _progress: Dictionary = {}  # key: save_id (String)
static var current_save_id: String = ""  # set by menu before scene change

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

### 2. MenuLevelData — Add save_id Field

**File:** `Scripts/MenuLevelData.gd`

Add one export:

```gdscript
@export var save_id: String = ""
```

This is the unique key used to identify a level in cloud saves. Must be set per level in the editor.

### 3. CustomGameUI — Trigger Save on Death

**File:** `Scripts/CustomGameUI.gd`

In `_show_revive()`, after updating UI data, save progress:

```gdscript
func _show_revive() -> void:
    if _shown: return
    _shown = true
    ui_layer.visible = true
    _update_ui_data()
    _save_progress()

func _save_progress() -> void:
    var save_id: String = ProgressStore.current_save_id
    if save_id.is_empty():
        return
    ProgressStore.update_level(save_id, LevelManager.crown, LevelManager.percent, LevelManager.diamond)
    CloudArchiveService.queue_save("game_progress")
```

The `current_save_id` is set by the menu `LevelManager._start_level()` before changing scene:

```gdscript
func _start_level() -> void:
    var data: MenuLevelData = levels[current_index]
    ProgressStore.current_save_id = data.save_id
    # ... existing PCK load + scene change
```

### 4. Menu LevelManager — Implement Stubs + Display

**File:** `Scripts/LevelManager.gd`

#### 4a. Implement `get_save_data()` and `apply_save_data()`

```gdscript
func get_save_data() -> Dictionary:
    return {
        "level_progress": ProgressStore.to_dict(),
    }

func apply_save_data(data: Dictionary) -> void:
    if data.has("level_progress"):
        ProgressStore.from_dict(data["level_progress"])
    _update_display()  # refresh UI with new progress
```

#### 4b. Set save_id Before Starting Level

In `_start_level()`, store the current level's save_id:

```gdscript
func _start_level() -> void:
    var data: MenuLevelData = levels[current_index]
    ProgressStore.current_save_id = data.save_id
    # ... existing PCK load + scene change code
```

#### 4c. Add Progress Badge to Level Display

In `_update_display()`, after setting level title, read progress from ProgressStore and show stars/percent/diamonds.

For **card mode**: add a progress label below the title area (in `$Margin/VBox/Info/Actions`).

For **list mode**: append progress text to each list item button.

### 5. GASArchiveAdapter — Fallback for In-Game Context

**File:** `Scripts/gas/gas_archive_adapter.gd`

When `queue_save()` is called from in-game, the menu LevelManager node doesn't exist. The adapter needs a fallback:

```gdscript
func _collect_game_state() -> Dictionary:
    var state: Dictionary = {}
    if Engine.get_main_loop().root.has_node("/root/LevelManager"):
        var lm: Node = Engine.get_main_loop().root.get_node("/root/LevelManager")
        if lm.has_method("get_save_data"):
            state = lm.get_save_data()
    else:
        # Menu scene not loaded — collect from ProgressStore directly
        state = {"level_progress": ProgressStore.to_dict()}
    state["cloud_save_time"] = Time.get_datetime_string_from_system()
    return state
```

## Cloud JSON Format

```json
{
  "level_progress": {
    "level_001": {"stars": 2, "best_percent": 75, "diamonds": 8},
    "level_002": {"stars": 3, "best_percent": 100, "diamonds": 10}
  },
  "cloud_save_time": "2026-05-02T12:00:00"
}
```

## Merge Strategy

Best-run only. When `update_level()` is called, each field takes the max of new vs existing:
- `stars = max(new, existing)`
- `best_percent = max(new, existing)`
- `diamonds = max(new, existing)`

## Data Flow: Login → Display

1. User logs in → `gas_login.gd` calls `CloudArchiveService.sync_on_login()`
2. `sync_on_login()` fetches cloud data via `ArchiveService.read()`
3. If cloud has data: `GASArchiveAdapter.apply_cloud_json()` → calls menu `LevelManager.apply_save_data()`
4. `apply_save_data()` calls `ProgressStore.from_dict()` → stores in memory
5. Menu `_update_display()` reads `ProgressStore.get_level(save_id)` → shows badge

## Data Flow: In-Game → Cloud

1. Player dies → `LevelManager.GameOverNormal()` sets `is_end = true`
2. `CustomGameUI._process()` detects `GameState == Died` → calls `_show_revive()`
3. `_show_revive()` calls `_save_progress()`
4. `_save_progress()` calls `ProgressStore.update_level()` then `CloudArchiveService.queue_save()`
5. After 2-second debounce: `GASArchiveAdapter.to_cloud_json()` → reads `ProgressStore.to_dict()` (menu node not in scene, adapter uses fallback)
6. JSON uploaded to cloud

## Key Decisions

- **No local persistence**: Progress only exists in-memory (ProgressStore static vars) and in the cloud. On app restart without login, progress is empty.
- **save_id in MenuLevelData**: Each level must have a unique save_id set in the editor. Empty save_id = no progress tracking for that level.
- **Best-run merge**: Only updates if the new run is better than the stored one.
- **Save trigger**: Only on death UI show, not on every frame or checkpoint.
