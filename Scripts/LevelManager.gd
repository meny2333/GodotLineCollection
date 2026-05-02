extends Control

@onready var level_title: Label = $Margin/VBox/Info/LevelTitle
@onready var author_label: Label = $Margin/VBox/Info/AuthorLabel
@onready var preview_clip: Control = $Margin/VBox/Preview/PreviewRow/PreviewClip
@onready var left_arrow: Button = $Margin/VBox/Preview/PreviewRow/LeftArrow
@onready var right_arrow: Button = $Margin/VBox/Preview/PreviewRow/RightArrow
@onready var user_capsule: PanelContainer = $Margin/VBox/Header/UserCapsule
@onready var avatar_rect: TextureRect = $Margin/VBox/Header/UserCapsule/HBox/AvatarRect
@onready var name_label: Label = $Margin/VBox/Header/UserCapsule/HBox/NameLabel
@onready var info_button: Button = $Margin/VBox/Info/Actions/InfoButton
@onready var counter_label: Label = $Margin/VBox/Preview/CounterLabel
@onready var info_label: Label = $Margin/VBox/Bottom/InfoLabel
@onready var info_container: VBoxContainer = $Margin/VBox/Info

var levels: Array[MenuLevelData] = []
var current_index: int = 0
var loaded_pcks: Array[String] = []
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _current_music_data: MenuLevelData
var _music_loop_timer: float = 0.0
var _is_music_fading: bool = false
var _animating: bool = false
var _default_avatar: ImageTexture
var _detail_popup: AcceptDialog

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
	_update_user_display()
	
	UserManager.user_info_updated.connect(_update_user_display)
	
	_apply_pending_cloud_data()
	_apply_circle_avatar(avatar_rect)


func _apply_pending_cloud_data() -> void:
	var pending_json: String = CloudArchiveService.get_pending_cloud_json()
	if pending_json.is_empty():
		return
	print("[LevelManager] applying pending cloud data: ", pending_json.substr(0, 200))
	var parsed: JSON = JSON.new()
	if parsed.parse(pending_json) == OK and parsed.data is Dictionary:
		apply_save_data(parsed.data)


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
		if _progress_label:
			_progress_label.visible = false
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
	author_label.text = ""
	counter_label.text = "%d / %d" % [current_index + 1, sz]
	_play_level_music(data)
	info_label.text = ""


func _play_level_music(data: MenuLevelData) -> void:
	if data == null or data.music == null:
		_fade_out_music()
		_current_music_data = null
		return
	if _current_music_data == data and _music_player.playing:
		return

	_current_music_data = data
	_music_player.stream = data.music

	# 设置开始播放位置
	if data.music_start > 0:
		_music_player.play(data.music_start)
	else:
		_music_player.play()

	# 淡入效果
	if data.music_fade_in > 0:
		_music_player.volume_db = -80.0
		_fade_in_music(data.music_fade_in)
	else:
		_music_player.volume_db = 0.0

	# 设置循环计时器
	_setup_music_loop(data)


## 淡入音乐
func _fade_in_music(duration: float) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", 0.0, duration)


## 淡出音乐
func _fade_out_music() -> void:
	if _music_tween:
		_music_tween.kill()
	if _current_music_data and _current_music_data.music_fade_out > 0:
		_is_music_fading = true
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -80.0, _current_music_data.music_fade_out)
		_music_tween.tween_callback(_on_music_fade_out_complete)
	else:
		_music_player.stop()
		_is_music_fading = false


## 淡出完成回调
func _on_music_fade_out_complete() -> void:
	_music_player.stop()
	_is_music_fading = false


## 设置音乐循环
func _setup_music_loop(data: MenuLevelData) -> void:
	_music_loop_timer = 0.0
	if data.music_duration > 0:
		# 使用计时器在指定时长后淡出并循环
		var timer := get_tree().create_timer(data.music_duration - data.music_fade_out)
		timer.timeout.connect(_on_music_segment_end)


## 音乐片段结束时淡出并循环
func _on_music_segment_end() -> void:
	if _current_music_data == null:
		return

	# 淡出
	_fade_out_music()

	# 等待淡出完成后重新开始
	await get_tree().create_timer(_current_music_data.music_fade_out).timeout

	# 重新播放
	if _current_music_data:
		_play_level_music(_current_music_data)


func _process(delta: float) -> void:
	# 检查音乐是否播放到结尾（用于没有指定时长的情况）
	if _current_music_data and _current_music_data.music_duration <= 0:
		if _music_player.playing and not _is_music_fading:
			# 检查是否接近结尾
			var remaining := _music_player.stream.get_length() - _music_player.get_playback_position()
			if remaining <= _current_music_data.music_fade_out:
				# 淡出并循环
				_fade_out_music()
				await get_tree().create_timer(_current_music_data.music_fade_out).timeout
				if _current_music_data:
					_play_level_music(_current_music_data)


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
	_show_detail_popup(data)


func _show_detail_popup(data: MenuLevelData) -> void:
	if _detail_popup:
		_detail_popup.queue_free()

	_detail_popup = AcceptDialog.new()
	_detail_popup.title = "关卡详情"
	_detail_popup.size = Vector2i(500, 300)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var cover_rect := TextureRect.new()
	cover_rect.custom_minimum_size = Vector2(200, 200)
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_rect.texture = data.cover
	hbox.add_child(cover_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = data.title if data.title != "" else "未命名关卡"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	vbox.add_child(title_label)

	var author_label := Label.new()
	author_label.text = "作者: %s" % data.author if not data.author.is_empty() else "作者: 未知"
	author_label.add_theme_font_size_override("font_size", 14)
	author_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7, 1))
	vbox.add_child(author_label)

	var desc_label := Label.new()
	desc_label.text = data.description if not data.description.is_empty() else "暂无描述"
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	hbox.add_child(vbox)
	_detail_popup.add_child(hbox)
	add_child(_detail_popup)
	_detail_popup.popup_centered()


func _on_refresh_button_pressed() -> void:
	_scan_levels()
	current_index = 0
	_update_display()
	info_label.text = "已刷新"


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


var _progress_label: Label

func _ensure_progress_label() -> void:
	if _progress_label:
		return
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_container.add_child(_progress_label)
	info_container.move_child(_progress_label, 0)


func _make_default_avatar() -> ImageTexture:
	if _default_avatar == null:
		var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.3, 0.3, 0.3, 1))
		_default_avatar = ImageTexture.create_from_image(image)
	return _default_avatar


func _apply_circle_avatar(rect: TextureRect) -> void:
	var shader: Shader = load("res://Scripts/circle_avatar.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat


func _on_user_capsule_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file("res://Scenes/gas_login.tscn")


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
	return {
		"level_progress": ProgressStore.to_dict(),
	}


func apply_save_data(data: Dictionary) -> void:
	print("[LevelManager] apply_save_data called with: ", data)
	if data.has("level_progress"):
		print("[LevelManager] restoring level_progress: ", data["level_progress"])
		ProgressStore.from_dict(data["level_progress"])
	else:
		print("[LevelManager] no level_progress key in data")
	_update_display()
