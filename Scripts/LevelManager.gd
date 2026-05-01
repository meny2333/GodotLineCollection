extends Control

@onready var level_title: Label = $Margin/VBox/Info/LevelTitle
@onready var author_label: Label = $Margin/VBox/Info/AuthorLabel
@onready var preview_clip: Control = $Margin/VBox/Preview/PreviewRow/PreviewClip
@onready var left_arrow: Button = $Margin/VBox/Preview/PreviewRow/LeftArrow
@onready var right_arrow: Button = $Margin/VBox/Preview/PreviewRow/RightArrow
@onready var user_button: Button = $Margin/VBox/Header/UserButton
@onready var info_button: Button = $Margin/VBox/Info/Actions/InfoButton
@onready var counter_label: Label = $Margin/VBox/Preview/CounterLabel
@onready var info_label: Label = $Margin/VBox/Bottom/InfoLabel
@onready var info_container: VBoxContainer = $Margin/VBox/Info

var levels: Array[MenuLevelData] = []
var current_index: int = 0
var loaded_pcks: Array[String] = []
var _music_player: AudioStreamPlayer
var _animating: bool = false

@onready var refresh_btn: Button = $Margin/VBox/Header/RefreshBtn

enum ViewMode { CARD, LIST }
var _current_mode: ViewMode = ViewMode.CARD
var _view_toggle_btn: Button

var _list_view: ScrollContainer
var _list_container: VBoxContainer

var _slide_wrap: Control
var _panel: PanelContainer
var _texture: TextureRect

const LEVEL_LIST_PATH := "res://pck_levels/level_list.tres"
const SLIDE_DUR := 0.3
const FLY_IN_DUR := 0.5

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_create_view_toggle()
	_create_panels()
	_create_list_view()
	_scan_levels()
	_update_display()
	_update_login_state()


func _create_view_toggle() -> void:
	_view_toggle_btn = Button.new()
	_view_toggle_btn.custom_minimum_size = Vector2(80, 36)
	_view_toggle_btn.add_theme_font_size_override("font_size", 14)
	_view_toggle_btn.text = "切换视图"
	
	# 复用已有的样式
	var style := refresh_btn.get_theme_stylebox("normal")
	var hover := refresh_btn.get_theme_stylebox("hover")
	_view_toggle_btn.add_theme_stylebox_override("normal", style)
	_view_toggle_btn.add_theme_stylebox_override("hover", hover)
	_view_toggle_btn.add_theme_stylebox_override("pressed", style)
	
	$Margin/VBox/Header.add_child(_view_toggle_btn)
	$Margin/VBox/Header.move_child(_view_toggle_btn, 1) # 放在刷新按钮后面
	_view_toggle_btn.pressed.connect(_on_view_toggle_pressed)


func _create_panels() -> void:
	_slide_wrap = Control.new()
	_slide_wrap.set_anchors_preset(PRESET_FULL_RECT)
	_slide_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_clip.add_child(_slide_wrap)
	
	var style := _make_panel_style()
	
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_texture = TextureRect.new()
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_texture)
	
	_slide_wrap.add_child(_panel)
	
	# 点击面板: 启动关卡
	_panel.gui_input.connect(_on_panel_gui_input)
	
	# 渲染后初始定位 + 飞入动画
	preview_clip.resized.connect(_position_panels)
	call_deferred("_setup_and_fly_in")


func _create_list_view() -> void:
	_list_view = ScrollContainer.new()
	_list_view.set_anchors_preset(PRESET_FULL_RECT)
	_list_view.visible = false
	preview_clip.add_child(_list_view)
	
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	_list_view.add_child(_list_container)


func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.13, 0.85)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.25, 0.3, 0.45, 0.4)
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	return s


func _setup_and_fly_in() -> void:
	# 等待布局完成
	await get_tree().process_frame
	_position_panels()
	
	if levels.is_empty() or _slide_wrap.size.x < 2:
		return
	
	_animating = true
	
	# 初始状态: 透明
	_panel.modulate.a = 0.0
	
	# 淡入动画
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, FLY_IN_DUR)
	
	await tw.finished
	_animating = false


func _position_panels() -> void:
	if preview_clip.size.x < 2:
		return
	
	var clip_size: Vector2 = preview_clip.size
	# 单个面板占据中间 1/3 宽度并居中
	var pw: float = clip_size.x / 3.0
	var h: float = clip_size.y
	
	_panel.position = Vector2(pw, 0)
	_panel.size = Vector2(pw, h)


func _update_display() -> void:
	if levels.is_empty():
		level_title.text = "暂无关卡"
		author_label.text = ""
		_texture.texture = null
		left_arrow.visible = false
		right_arrow.visible = false
		counter_label.text = ""
		return
	
	var sz: int = levels.size()
	left_arrow.visible = (_current_mode == ViewMode.CARD) and (sz > 1)
	right_arrow.visible = (_current_mode == ViewMode.CARD) and (sz > 1)
	counter_label.visible = (_current_mode == ViewMode.CARD)
	
	var data: MenuLevelData = levels[current_index]
	_texture.texture = data.cover
	_texture.visible = data.cover != null
	
	_panel.modulate.a = 1.0
	
	level_title.text = data.title if data.title != "" else "未命名关卡"
	author_label.text = ""
	counter_label.text = "%d / %d" % [current_index + 1, sz]
	_play_level_music(data)
	info_label.text = ""


func _play_level_music(data: MenuLevelData) -> void:
	if data == null or data.music == null:
		_music_player.stop()
		return
	if _music_player.stream == data.music and _music_player.playing:
		return
	_music_player.stream = data.music
	_music_player.play()


func _on_view_toggle_pressed() -> void:
	if _animating:
		return
	
	_current_mode = ViewMode.LIST if _current_mode == ViewMode.CARD else ViewMode.CARD
	
	if _current_mode == ViewMode.LIST:
		_update_list()
		_slide_wrap.visible = false
		_list_view.visible = true
		left_arrow.visible = false
		right_arrow.visible = false
		counter_label.visible = false
	else:
		_slide_wrap.visible = true
		_list_view.visible = false
		left_arrow.visible = levels.size() > 1
		right_arrow.visible = levels.size() > 1
		counter_label.visible = true
		_update_display()


func _update_list() -> void:
	# 清空现有列表
	for child in _list_container.get_children():
		child.queue_free()
	
	var style := _make_panel_style()
	style.set_content_margin_all(8)
	
	for i in range(levels.size()):
		var data := levels[i]
		var btn := Button.new()
		btn.text = "  %d. %s" % [i + 1, data.title if data.title != "" else "未命名关卡"]
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 44
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# 样式
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.15, 0.15, 0.22, 0.9)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		
		btn.pressed.connect(_on_list_item_selected.bind(i))
		_list_container.add_child(btn)


func _on_list_item_selected(index: int) -> void:
	current_index = index
	_update_display()
	_start_level()


func _on_left_arrow() -> void:
	if levels.size() <= 1 or _animating:
		return
	_animate_switch(-1)


func _on_right_arrow() -> void:
	if levels.size() <= 1 or _animating:
		return
	_animate_switch(1)


func _animate_switch(direction: int) -> void:
	_animating = true
	
	# 1. 淡出当前内容
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tw_out.tween_property(_panel, "modulate:a", 0.0, SLIDE_DUR)
	tw_out.tween_property(info_container, "modulate:a", 0.0, SLIDE_DUR * 0.6)
	
	await tw_out.finished
	
	# 2. 更新内容
	current_index = (current_index + direction + levels.size()) % levels.size()
	_update_display()
	
	# 3. 准备淡入
	_panel.modulate.a = 0.0
	info_container.modulate.a = 0.0
	
	# 4. 淡入新内容
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tw_in.tween_property(_panel, "modulate:a", 1.0, FLY_IN_DUR)
	tw_in.tween_property(info_container, "modulate:a", 1.0, FLY_IN_DUR * 0.6)
	
	await tw_in.finished
	
	_animating = false


func _on_panel_gui_input(event: InputEvent) -> void:
	if levels.is_empty() or _animating:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_level()


func _start_level() -> void:
	var data: MenuLevelData = levels[current_index]
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


func _on_info_button() -> void:
	if levels.is_empty():
		return
	var data: MenuLevelData = levels[current_index]
	var detail := "关卡: %s" % data.title
	if not data.pck_path.is_empty():
		detail += "\nPCK: %s" % data.pck_path
	info_label.text = detail


func _on_refresh_button_pressed() -> void:
	_scan_levels()
	current_index = 0
	_update_display()
	info_label.text = "已刷新"


func _on_login_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/gas_login.tscn")


func _update_login_state() -> void:
	if CloudArchiveService.has_credentials():
		var config := GASLoginConfig.new()
		if config.load():
			user_button.text = config.email
		else:
			user_button.text = "用户"
	else:
		user_button.text = "登录"


func _scan_levels() -> void:
	levels.clear()
	if not ResourceLoader.exists(LEVEL_LIST_PATH):
		return
	var list := load(LEVEL_LIST_PATH)
	if list is MenuLevelList:
		levels = list.levels


func _load_pck(pck_path: String, level_key: String) -> void:
	var global_path := ProjectSettings.globalize_path(pck_path)
	if not FileAccess.file_exists(global_path):
		info_label.text = "PCK文件不存在"
		return
	var success := ProjectSettings.load_resource_pack(global_path)
	if success:
		loaded_pcks.append(level_key)
	else:
		info_label.text = "PCK加载失败"


func get_save_data() -> Dictionary:
	return {}


func apply_save_data(data: Dictionary) -> void:
	pass
