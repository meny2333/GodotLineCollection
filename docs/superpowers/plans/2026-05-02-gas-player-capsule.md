# GAS Player Info Capsule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate GAS account system into LevelManager and CustomGameUI, displaying player avatar and nickname in a unified capsule style.

**Architecture:** Modify existing scene nodes to add avatar TextureRect and connect to UserManager autoload for real-time updates. Login flow updated to populate UserManager on success.

**Tech Stack:** Godot 4.6, GDScript, UserManager autoload, GAS SDK

---

## File Structure

| File | Responsibility |
|------|----------------|
| `Scripts/gas/gas_login.gd` | Login flow - call `UserManager.set_user_info()` on success |
| `Scripts/LevelManager.gd` | Menu scene - display user capsule in top-right header |
| `Scenes/LevelManager.tscn` | Menu scene - replace UserButton with UserCapsule structure |
| `Scripts/CustomGameUI.gd` | Game UI - display user capsule in top-left PlayerCapsule |
| `Scenes/CustomGameUI.tscn` | Game UI - add AvatarRect to PlayerCapsule/VBox |

---

### Task 1: Update Login Flow to Populate UserManager

**Files:**
- Modify: `Scripts/gas/gas_login.gd:122-143`

- [ ] **Step 1: Add UserManager.set_user_info() call in _on_login_success()**

```gdscript
func _on_login_success(data: Dictionary) -> void:
	var nickname: String = str(data.get("nickname", ""))
	var avatar_url: String = str(data.get("avatar", ""))
	var location: String = str(data.get("location", ""))
	var email: String = str(data.get("email", _email))
	
	UserManager.set_user_info(nickname, avatar_url, email)
	
	if nickname != "":
		user_info.text = "%s\n%s" % [nickname, email]
	else:
		user_info.text = email
	
	user_info.visible = true
	status_label.text = "登录成功"
	btn_login.visible = false
	
	if avatar_url != "":
		avatar_container.visible = true
		_load_avatar(avatar_url)
	
	CloudArchiveService.set_credentials(_email, _access_token)
	CloudArchiveService.sync_on_login()
	login_finish.emit(_email, _access_token)
	
	btn_back.visible = true
	var tween := create_tween()
	tween.tween_property(btn_back, "modulate", Color.WHITE, 0.3)
	
	await create_tween().tween_interval(1.5).finished
	_navigate_back()
```

- [ ] **Step 2: Verify code compiles**

Open project in Godot Editor, check for parse errors in Output panel.

---

### Task 2: Modify LevelManager.tscn - Replace UserButton with UserCapsule

**Files:**
- Modify: `Scenes/LevelManager.tscn:154-162`

- [ ] **Step 1: Replace UserButton node with UserCapsule structure**

Remove the existing UserButton node (lines 154-162) and replace with:

```tscn
[node name="UserCapsule" type="PanelContainer" parent="Margin/VBox/Header" index="4"]
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_SecBtn")

[node name="HBox" type="HBoxContainer" parent="Margin/VBox/Header/UserCapsule"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 8

[node name="AvatarRect" type="TextureRect" parent="Margin/VBox/Header/UserCapsule/HBox"]
custom_minimum_size = Vector2(28, 28)
layout_mode = 2
expand_mode = 3
stretch_mode = 6

[node name="NameLabel" type="Label" parent="Margin/VBox/Header/UserCapsule/HBox"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.85)
theme_override_font_sizes/font_size = 14
text = "Guest"
```

- [ ] **Step 2: Update signal connection**

Replace the old connection line:
```
[connection signal="pressed" from="Margin/VBox/Header/UserButton" to="." method="_on_login_button_pressed"]
```

With:
```
[connection signal="gui_input" from="Margin/VBox/Header/UserCapsule" to="." method="_on_user_capsule_input"]
```

- [ ] **Step 3: Verify scene loads in Godot Editor**

Open LevelManager.tscn in editor, verify structure shows UserCapsule with HBox containing AvatarRect and NameLabel.

---

### Task 3: Update LevelManager.gd - Display User Info

**Files:**
- Modify: `Scripts/LevelManager.gd:1-20, 37-46, 340-352`

- [ ] **Step 1: Update @onready references**

Replace the `user_button` reference and add new refs:

```gdscript
@onready var user_capsule: PanelContainer = $Margin/VBox/Header/UserCapsule
@onready var avatar_rect: TextureRect = $Margin/VBox/Header/UserCapsule/HBox/AvatarRect
@onready var name_label: Label = $Margin/VBox/Header/UserCapsule/HBox/NameLabel
```

Remove:
```gdscript
@onready var user_button: Button = $Margin/VBox/Header/UserButton
```

- [ ] **Step 2: Update _ready() to connect UserManager signal**

```gdscript
func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_create_view_toggle()
	_create_panels()
	_create_list_view()
	_scan_levels()
	_update_display()
	_update_user_display()
	
	UserManager.user_info_updated.connect(_update_user_display)
```

- [ ] **Step 3: Replace _update_login_state() with _update_user_display()**

Remove the old method and add:

```gdscript
func _update_user_display() -> void:
	if UserManager.user_nickname != "" or UserManager.user_email != "":
		name_label.text = UserManager.get_display_name()
		if UserManager.has_avatar():
			avatar_rect.texture = UserManager.get_avatar_texture()
		else:
			avatar_rect.texture = _make_default_avatar()
	else:
		name_label.text = "Guest"
		avatar_rect.texture = _make_default_avatar()


func _make_default_avatar() -> ImageTexture:
	var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.3, 0.3, 1))
	return ImageTexture.create_from_image(image)


func _on_user_capsule_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file("res://Scenes/gas_login.tscn")
```

- [ ] **Step 4: Remove old _on_login_button_pressed() method**

Delete:
```gdscript
func _on_login_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/gas_login.tscn")
```

- [ ] **Step 5: Verify compilation**

Open project in Godot Editor, check Output panel for errors.

---

### Task 4: Modify CustomGameUI.tscn - Add Avatar to PlayerCapsule

**Files:**
- Modify: `Scenes/CustomGameUI.tscn:65-79`

- [ ] **Step 1: Add AvatarRect to PlayerCapsule/VBox**

Insert before the existing Label node (line 69):

```tscn
[node name="AvatarRect" type="TextureRect" parent="UILayer/TopBar/PlayerCapsule/VBox"]
custom_minimum_size = Vector2(24, 24)
layout_mode = 2
expand_mode = 3
stretch_mode = 6
```

- [ ] **Step 2: Verify scene loads in Godot Editor**

Open CustomGameUI.tscn, check PlayerCapsule/VBox contains AvatarRect and Label.

---

### Task 5: Update CustomGameUI.gd - Display User Info

**Files:**
- Modify: `Scripts/CustomGameUI.gd:12-18, 29-33, 60-72`

- [ ] **Step 1: Add @onready reference for AvatarRect**

Add after line 17:
```gdscript
@onready var avatar_rect: TextureRect = $UILayer/TopBar/PlayerCapsule/VBox/AvatarRect
```

- [ ] **Step 2: Connect UserManager signal in _ready()**

```gdscript
func _ready() -> void:
	retry_btn.pressed.connect(_on_revive_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	_hide_revive()
	set_process(true)
	
	UserManager.user_info_updated.connect(_on_user_info_updated)
```

- [ ] **Step 3: Add signal handler and update _update_ui_data()**

Add new method:
```gdscript
func _on_user_info_updated() -> void:
	if _shown:
		_update_user_display()


func _update_user_display() -> void:
	player_label.text = UserManager.get_display_name()
	if UserManager.has_avatar():
		avatar_rect.texture = UserManager.get_avatar_texture()
		avatar_rect.visible = true
	else:
		avatar_rect.visible = false
```

Update `_update_ui_data()` - replace line 68:
```gdscript
	player_label.text = "PLAYER"
```

With:
```gdscript
	_update_user_display()
```

- [ ] **Step 4: Verify compilation**

Open project in Godot Editor, check Output panel for errors.

---

### Task 6: Final Verification

- [ ] **Step 1: Test login flow**

1. Run project
2. Navigate to LevelManager scene
3. Click UserCapsule → should navigate to gas_login.tscn
4. Complete login → should return to LevelManager
5. Verify avatar and nickname display in UserCapsule

- [ ] **Step 2: Test CustomGameUI**

1. Load a level from LevelManager
2. Verify PlayerCapsule shows avatar and nickname
3. Die in game → UI appears with correct player info

- [ ] **Step 3: Test logged-out state**

1. Clear credentials (delete `user://gas_config.cfg`)
2. Run project
3. Verify both scenes show "Guest" with default gray avatar

- [ ] **Step 4: Commit**

```bash
git add Scripts/gas/gas_login.gd Scripts/LevelManager.gd Scripts/CustomGameUI.gd Scenes/LevelManager.tscn Scenes/CustomGameUI.tscn
git commit -m "feat: integrate GAS player info capsule in LevelManager and CustomGameUI"
```
