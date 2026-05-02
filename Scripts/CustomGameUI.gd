## CustomGameUI.gd — 优雅复古复活 UI
## 视觉：删除背景层，保留胶囊布局
## 参数：参照 DebugOverlay & GAMEUI
## 逻辑：数据现在由 #Template 控制在加载前重置
extends Control

# --- 状态 ---
var _was_dead: bool = false
var _shown: bool = false
var _cloud_saved: bool = false

# --- 节点引用 ---
@onready var ui_layer = $UILayer

# TopBar
@onready var level_label = $UILayer/TopBar/LevelCapsule/Label
@onready var player_label = $UILayer/TopBar/PlayerCapsule/VBox/Label
@onready var avatar_rect: TextureRect = $UILayer/TopBar/PlayerCapsule/VBox/AvatarRect
@onready var time_label = $UILayer/TopBar/TimeCapsule/VBox/Label

# BottomBar
@onready var diamond_val = $UILayer/BottomBar/DataCards/DiamondCard/VBox/Value
@onready var crowns_hbox = $UILayer/BottomBar/DataCards/CrownCard/VBox/HBox
@onready var progress_val = $UILayer/BottomBar/DataCards/ProgressCard/VBox/Value
@onready var progress_detail = $UILayer/BottomBar/DataCards/ProgressCard/VBox/Detail

@onready var retry_btn = $UILayer/BottomBar/RetryBtn
@onready var back_btn = $UILayer/BottomBar/BackBtn

func _ready() -> void:
	retry_btn.pressed.connect(_on_revive_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	_hide_revive()
	set_process(true)
	
	UserManager.user_info_updated.connect(_on_user_info_updated)
	
	_apply_circle_avatar(avatar_rect)

func _process(_delta: float) -> void:
	var current_state = LevelManager.GameState
	var is_dead = (current_state == LevelManager.GameStatus.Died)
	
	if is_dead and not _was_dead:
		_show_revive()
	
	if not is_dead and _was_dead:
		_hide_revive()
	
	_was_dead = is_dead
	
	if _shown:
		_update_ui_data()

func _show_revive() -> void:
	if _shown: return
	_shown = true
	_cloud_saved = false
	ui_layer.visible = true
	time_label.text = "..."
	_update_ui_data()
	_save_progress()

func _hide_revive() -> void:
	_shown = false
	ui_layer.visible = false

func _save_progress() -> void:
	var p = Player.instance
	if not p or not p.level_data:
		print("[CustomGameUI] save skipped: no player or level_data")
		return
	var save_id: int = p.level_data.saveID
	print("[CustomGameUI] saving progress: save_id=%d crown=%d percent=%d diamond=%d" % [save_id, LevelManager.crown, LevelManager.percent, LevelManager.diamond])
	ProgressStore.update_level(str(save_id), LevelManager.crown, LevelManager.percent, LevelManager.diamond)
	CloudArchiveService.queue_save("game_progress")
	CloudArchiveService.save_completed.connect(_on_cloud_saved, CONNECT_ONE_SHOT)

func _on_cloud_saved(update_time: String) -> void:
	if not update_time.is_empty():
		_cloud_saved = true
		time_label.text = "☁ " + update_time

func _update_ui_data() -> void:
	var p = Player.instance
	if not p: return
	
	# 1. 顶部栏信息
	if p.level_data:
		level_label.text = p.level_data.levelTitle
	
	_update_user_display()

	# 2. 底部数据卡片
	diamond_val.text = "%d/10" % LevelManager.diamond
	progress_val.text = "%d%%" % LevelManager.percent
	
	var music_player = p.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player and music_player.stream:
		var total_sec = p.level_data.levelTotalTime if p.level_data.useCustomLevelTime else music_player.stream.get_length()
		var current_sec = music_player.get_playback_position()
		progress_detail.text = "%.1fs / %.1fs" % [current_sec, total_sec]
	
	var crowns = crowns_hbox.get_children()
	for i in range(crowns.size()):
		crowns[i].color = Color.GOLD if i < LevelManager.crown else Color(0.2, 0.2, 0.2, 0.5)
	
	# 3. 自动取色
	_update_colors()

func _update_colors() -> void:
	var bg_col = _get_background_color()
	var text_col = LevelManager.GetColorByContent(bg_col)
	_apply_theme_recursive(ui_layer, bg_col, text_col)

func _apply_theme_recursive(node: Node, bg: Color, text: Color) -> void:
	if node is PanelContainer:
		var style = node.get_theme_stylebox("panel").duplicate()
		if style is StyleBoxFlat:
			style.bg_color = bg
			style.bg_color.a = 0.7
			style.border_color = text
			style.border_color.a = 0.3
			node.add_theme_stylebox_override("panel", style)
	elif node is Label:
		node.add_theme_color_override("font_color", text)
	elif node is Button:
		var style = node.get_theme_stylebox("normal").duplicate()
		if style is StyleBoxFlat:
			style.bg_color = bg
			style.bg_color.a = 0.8
			style.border_color = text
			style.border_color.a = 0.5
			node.add_theme_stylebox_override("normal", style)
			node.add_theme_stylebox_override("hover", style)
		node.add_theme_color_override("font_color", text)

	for child in node.get_children():
		_apply_theme_recursive(child, bg, text)

func _get_background_color() -> Color:
	if Player.instance and Player.instance.level_data:
		var colors = Player.instance.level_data.colors
		if colors.size() > 0: return colors[0].color
	var cam = get_viewport().get_camera_3d()
	if cam and cam.environment:
		if cam.environment.background_mode == Environment.BG_COLOR:
			return cam.environment.background_color
		elif cam.environment.fog_enabled:
			return cam.environment.fog_light_color
	return Color(0.05, 0.1, 0.2)

func _on_user_info_updated() -> void:
	if _shown:
		_update_user_display()


func _apply_circle_avatar(rect: TextureRect) -> void:
	var shader: Shader = load("res://Scripts/circle_avatar.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat


func _update_user_display() -> void:
	player_label.text = UserManager.get_display_name()
	if UserManager.has_avatar():
		avatar_rect.texture = UserManager.get_avatar_texture()
		avatar_rect.visible = true
	else:
		avatar_rect.visible = false


# --- 按钮逻辑 ---
func _on_revive_pressed() -> void:
	_hide_revive()
	if Player.instance.is_end:
		_on_gamereplay_pressed()
	elif LevelManager.current_checkpoint:
		LevelManager.current_checkpoint.revive()
		if LevelManager.crown > 0:
			LevelManager.is_relive = true
	else:
		_on_gamereplay_pressed()

func _on_back_pressed() -> void:
	LevelManager.is_end = false
	LevelManager.is_relive = false
	LevelManager.camera_checkpoint.restore_pending = false
	LevelManager.diamond = 0
	LevelManager.crown = 0
	LevelManager.percent = 0
	get_tree().change_scene_to_file("res://Scenes/LevelManager.tscn")

func _on_gamereplay_pressed() -> void:
	if Player.instance:
		Player.instance.reload()
	LevelManager.reset_to_defaults()
