# GAS Player Info Capsule Design

## Overview

Integrate GAS account system into LevelManager and CustomGameUI scenes, displaying player avatar and nickname in a unified capsule style. Replace the email display in LevelManager and the hardcoded "PLAYER" text in CustomGameUI.

## Decisions

- **Layout:** Capsule button with circular avatar + nickname horizontal (Option A for both scenes)
- **Logged out state:** Default gray avatar + "Guest" text (Option B)
- **Implementation:** Direct modification of existing nodes (Option A), not a reusable component

## Architecture

### Data Flow

```
gas_login.gd (_on_login_success)
  → UserManager.set_user_info(nickname, avatar_url, email)
    → loads avatar via HTTP
    → emits user_info_updated signal
      → LevelManager._update_user_display()
      → CustomGameUI._update_user_display()
```

### Unlogged Flow

```
LevelManager._ready() / CustomGameUI._ready()
  → check UserManager.user_nickname == "" and UserManager.user_email == ""
  → show default avatar + "Guest"
  → on click → navigate to gas_login.tscn
```

## Components

### 1. Login Integration (gas_login.gd)

In `_on_login_success()`, add:
```gdscript
UserManager.set_user_info(nickname, avatar_url, email)
```

UserManager is already an autoload with `set_user_info()`, `get_display_name()`, `get_avatar_texture()`, and `user_info_updated` signal.

### 2. LevelManager Right Capsule

**Scene changes (LevelManager.tscn):**
- Replace `UserButton` (Button) with `PanelContainer` named `UserCapsule`
  - Style: reuse existing `StyleBoxFlat_SecBtn` style
  - `HBoxContainer` inside:
    - `TextureRect` named `AvatarRect` (40x40, circular clip)
    - `Label` named `NameLabel` (nickname)
  - Add `Button` as sibling for click handling (transparent overlay)

**Script changes (LevelManager.gd):**
- Add `@onready` refs for new nodes
- In `_ready()`: connect `UserManager.user_info_updated` to `_update_user_display()`
- Replace `_update_login_state()` with `_update_user_display()`:
  - If `UserManager.user_nickname != ""` or `UserManager.user_email != ""`: show avatar + display name
  - Else: show default avatar + "Guest"
- Click on capsule → `get_tree().change_scene_to_file("res://Scenes/gas_login.tscn")`

### 3. CustomGameUI Left Capsule

**Scene changes (CustomGameUI.tscn):**
- In `PlayerCapsule/VBox`, add `TextureRect` named `AvatarRect` (24x24) above the existing Label
- Keep existing Label for nickname

**Script changes (CustomGameUI.gd):**
- Add `@onready var avatar_rect: TextureRect = $UILayer/TopBar/PlayerCapsule/VBox/AvatarRect`
- In `_ready()`: connect `UserManager.user_info_updated`
- In `_update_ui_data()`:
  - `player_label.text = UserManager.get_display_name()`
  - `avatar_rect.texture = UserManager.get_avatar_texture()` (or default if null)
  - Hide avatar_rect if no texture and not logged in

## Files to Modify

| File | Change |
|------|--------|
| `Scripts/gas/gas_login.gd` | Add `UserManager.set_user_info()` call in `_on_login_success()` |
| `Scripts/LevelManager.gd` | Add signal connection, new `_update_user_display()` method |
| `Scenes/LevelManager.tscn` | Replace UserButton with UserCapsule (PanelContainer > HBox > AvatarRect + NameLabel) |
| `Scripts/CustomGameUI.gd` | Use UserManager data in `_update_ui_data()` |
| `Scenes/CustomGameUI.tscn` | Add AvatarRect TextureRect in PlayerCapsule/VBox |

## UI Style Details

- **Avatar:** Circular clip (use `clip_contents = true` on container, or shader)
- **Capsule background:** Reuse `StyleBoxFlat_SecBtn` from LevelManager (dark semi-transparent, rounded corners)
- **Font size:** 14px for LevelManager, 12px for CustomGameUI (match existing)
- **Spacing:** 8px between avatar and nickname
- **Default avatar:** Solid gray circle (Color(0.3, 0.3, 0.3, 1))

## Error Handling

- Avatar load failure: show default gray avatar, don't block UI
- Network unavailable: UserManager gracefully degrades, shows email or "Guest"
- No credentials: show Guest + default avatar, click navigates to login
