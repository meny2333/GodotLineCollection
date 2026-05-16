# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.6 rhythm game level collection/launcher. Dynamically loads user levels via PCK files, with cloud save via GAS SDK. Levels are authored using the [godot-line](https://github.com/meny2333/godot-line) template.

## Architecture

```
GodotLineCollection/
├── Scripts/              # Menu UI, cloud saves, user management
│   ├── gas/              # GAS cloud archive integration
│   └── ui/               # UI components (floating_bubbles, etc.)
├── addons/
│   ├── gas_sdk/          # GAS cloud service SDK (OAuth, archive, profile)
│   ├── PCKManager/       # PCK file management tools
│   └── ugc_import/       # Editor plugin for PCK import/verification
├── Scenes/               # Main scenes (LevelManager, gas_login, CustomGameUI)
├── #Template/            # Level template (from godot-line project)
│   ├── [Scripts]/        # Template scripts organized by function
│   │   ├── Level/        # LevelManager (static singleton), RoadMaker, gameui
│   │   ├── Trigger/      # Triggers (checkpoints, speed, turn, fog, etc.)
│   │   ├── Settings/     # Resource classes (LevelData, CameraSettings, etc.)
│   │   ├── Animator/     # Animation controllers
│   │   ├── CameraScripts/# Camera followers
│   │   ├── Editor/       # Editor tools (BeatmapReader, NoteReader, AutoPlay)
│   │   └── Guidance/     # Guidance box system
│   └── [Scenes]/         # Sample scenes
└── pck_levels/           # Published PCK files and level_list.tres
```

## Key Patterns

### Autoloads (defined in project.godot)
- `GameUIHook` — Replaces in-game gameui with custom UI (Scene/CustomGameUI.tscn)
- `CloudArchiveService` — Manages cloud save sync
- `UserManager` — User nickname, avatar, email

### Static Singletons
- `LevelManager` (`#Template/[Scripts]/Level/LevelManager.gd`) — `class_name LevelManager extends RefCounted`, entirely static. Game state, checkpoint save/load, game over logic. NOT an autoload — used via `LevelManager.GameState`, `LevelManager.percent`, etc.
- `ProgressStore` (`Scripts/progress_store.gd`) — `class_name ProgressStore extends RefCounted`, static local progress storage

### Level Loading Flow
1. `LevelManager.tscn` loads `level_list.tres` → `MenuLevelList` → `Array[MenuLevelData]`
2. User clicks a level → `_load_pck()` calls `ProjectSettings.load_resource_pack()`
3. `get_tree().change_scene_to_file()` loads the level scene from the PCK

### Game UI Replacement Flow
1. `GameUIHook` (autoload) listens for `node_added`, detects nodes named `"gameui"`
2. Replaces them with `res://Scenes/CustomGameUI.tscn` at the same position
3. `CustomGameUI` reads `LevelManager.GameState` in `_process()` and reacts to state transitions

### Cloud Save Flow
1. `UserManager` → user logs in via `gas_login.tscn`
2. `CloudArchiveService.set_credentials()` + `sync_on_login()` → compares cloud vs local timestamps
3. `CustomGameUI._save_progress()` → `ProgressStore.update_level()` → `CloudArchiveService.queue_save()`
4. `GASArchiveAdapter` bridges game state ↔ cloud JSON

### PCK Import (Editor Plugin)
- `addons/ugc_import/plugin.gd` adds "UGC管理" toolbar button
- Imports PCK → `pck_levels/`, extracts music, creates/updates `MenuLevelData` entries in `level_list.tres`
- Supports full CRUD on level list via "关卡管理" tab

### @tool Nodes for Level Authoring
- `BeatmapReader` — parse .osu beatmaps, generate GuidanceBox sequences
- `NoteReader` — parse .osu beatmaps, generate roads and auto-triggers
- Both hang on scene nodes, configured via Inspector with "执行生成" checkbox

### XR/Physics Notes
- Custom physics layers: Layer 1 = Player, Layer 2 = BaseFloor, Layer 3 = BaseWall
- Uses Jolt Physics (`3d/physics_engine="Jolt Physics"`)
- Renderer: mobile, Windows driver: D3D12

## Common Commands

```bash
# Run the project (Godot 4.6)
godot4.6 --path .
# Or open in editor
godot4.6 -e --path .
# Run a specific scene
godot4.6 --path . res://Scenes/LevelManager.tscn
```

## Conventions

- Scripts in `#Template/` belong to the upstream template — minimize changes; override behavior via autoloads/replacement nodes in `Scripts/`
- Resource classes (`@tool extends Resource`) used for serializable data: `MenuLevelData`, `MenuLevelList`, `LevelData`, etc.
- Signal-driven UI updates: `UserManager.user_info_updated`, `CloudArchiveService.sync_complete`
- All service methods return `Variant` — check `is GASError` before use
- PCK scene paths use `[Scenes]/` and `[Scripts]/` bracket notation inside PCKs
