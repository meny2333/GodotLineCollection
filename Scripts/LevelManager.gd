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
@onready var header_box: HBoxContainer = $Margin/VBox/Header

var levels: Array[MenuLevelData] = []
var current_index: int = 0
var loaded_pcks: Array[String] = []
var _animating: bool = false
var _default_avatar: ImageTexture
var _detail_popup: AcceptDialog
var _import_dialog: FileDialog

@onready var refresh_btn: Button = $Margin/VBox/Header/RefreshBtn
@onready var import_btn: Button = $Margin/VBox/Header/ImportBtn

enum ViewMode { CARD, LIST }
var _current_mode: ViewMode = ViewMode.CARD
@onready var view_toggle_btn: Button = $Margin/VBox/Header/ViewToggleBtn

var _list_view: ScrollContainer
var _list_container: VBoxContainer

@onready var _verification_ui: ColorRect = $VerificationUI

var _music_preview: MusicPreview
var _energy_system: EnergySystem
var _ad_system: AdSystem
var _pck_loader: PCKLoader

var _slide_wrap: Control
var _panel: PanelContainer
var _texture: TextureRect
var _bg: ColorRect
var _bg_tween: Tween

const LEVEL_LIST_PATH := "res://pck_levels/level_list.tres"
const SLIDE_DUR := 0.3
const FLY_IN_DUR := 0.5

func _ready() -> void:
	Engine.time_scale = 1.0
	_bg = $BG

	_music_preview = MusicPreview.new(self)
	_energy_system = EnergySystem.new(header_box.get_node("EnergyLabel"), header_box.get_node("WatchAdBtn"))
	_ad_system = AdSystem.new(self, info_label)
	_pck_loader = PCKLoader.new()
	_pck_loader.setup(_verification_ui, info_label)

	_pck_loader.load_ready.connect(_on_pck_load_ready)
	_pck_loader.load_failed.connect(func(msg: String): info_label.text = msg)
	_pck_loader.pck_loaded.connect(func(key: String): loaded_pcks.append(key))
	_energy_system.watch_ad_requested.connect(_on_watch_ad_requested)
	_ad_system.reward_claimed.connect(func(amount: int): _energy_system.add(amount))

	_create_panels()
	_create_list_view()
	_scan_levels()
	_update_display()
	_update_user_display()

	UserManager.user_info_updated.connect(_update_user_display)

	_apply_pending_cloud_data()
	_apply_circle_avatar(avatar_rect)
	_create_import_dialog()
	_apply_display_settings()
	PCKDownloader.ensure_instance()
	_fetch_remote_urls()
	_ad_system.prefetch_ads()


func _apply_pending_cloud_data() -> void:
	var pending_json: String = CloudArchiveService.get_pending_cloud_json()
	if pending_json.is_empty():
		return
	print("[LevelManager] applying pending cloud data: ", pending_json.substr(0, 200))
	var parsed: JSON = JSON.new()
	if parsed.parse(pending_json) == OK and parsed.data is Dictionary:
		apply_save_data(parsed.data)


func _fetch_remote_urls() -> void:
	await PCKDownloader.instance.fetch_level_urls()
	print("[LevelManager] Remote level URLs loaded: ", PCKDownloader.instance.get_level_count())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _pck_loader:
			_pck_loader.cleanup()


func _create_import_dialog() -> void:
	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.filters = PackedStringArray(["*.pck ; PCK Files"])
	_import_dialog.title = "选择PCK文件"
	_import_dialog.size = Vector2i(600, 400)
	_import_dialog.file_selected.connect(_on_pck_file_selected)

	if OS.has_feature("android"):
		_import_dialog.use_native_dialog = true

	add_child(_import_dialog)


func _on_settings_pressed() -> void:
	var panel_scene := load("res://Scenes/SettingsPanel.tscn") as PackedScene
	if panel_scene == null:
		return
	var panel := panel_scene.instantiate()
	add_child(panel)
	panel.settings_closed.connect(panel.queue_free)


func _validate_pck(pck_global_path: String) -> Dictionary:
	var pck := preload("res://addons/PCKManager/PCKDirAccess.gd").new()
	pck.open(pck_global_path)
	if pck.file == null:
		return {}
	var paths := pck.get_paths()
	pck.close()
	if paths.is_empty():
		return {}
	return _find_level_scene(paths)


func _find_level_scene(paths: Array[String]) -> Dictionary:
	var scene_dirs: Dictionary = {}
	for p in paths:
		var clean: String = p.trim_suffix(".remap")
		if not clean.contains("[Scenes]/"):
			continue
		var scenes_idx := clean.find("[Scenes]/")
		var after := clean.substr(scenes_idx + "[Scenes]/".length())
		var parts := after.split("/")
		if parts.size() >= 2:
			var dir_name: String = parts[0]
			if not scene_dirs.has(dir_name):
				scene_dirs[dir_name] = {"has_tscn": false, "has_tres": false}
			if parts[1].ends_with(".tscn"):
				scene_dirs[dir_name]["has_tscn"] = true
			elif parts[1].ends_with(".tres"):
				scene_dirs[dir_name]["has_tres"] = true

	var best_dir: String = ""
	for dir_name in scene_dirs:
		if scene_dirs[dir_name]["has_tscn"] and scene_dirs[dir_name]["has_tres"]:
			best_dir = dir_name
			break

	if best_dir.is_empty():
		return {}

	for p in paths:
		var clean: String = p.trim_suffix(".remap")
		if clean.contains("[Scenes]/%s/" % best_dir) and clean.ends_with(".tscn"):
			return {"scene_path": clean, "name": best_dir}
	return {}


func _create_panels() -> void:
	_slide_wrap = Control.new()
	_slide_wrap.set_anchors_preset(PRESET_FULL_RECT)
	_slide_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_clip.add_child(_slide_wrap)

	var style := _make_panel_style()

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.clip_children = CLIP_CHILDREN_ONLY
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_texture = TextureRect.new()
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_texture)

	_slide_wrap.add_child(_panel)

	_panel.gui_input.connect(_on_panel_gui_input)

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
	s.content_margin_left = 1
	s.content_margin_top = 1
	s.content_margin_right = 1
	s.content_margin_bottom = 1
	return s


func _setup_and_fly_in() -> void:
	await get_tree().process_frame
	_position_panels()

	if levels.is_empty() or _slide_wrap.size.x < 2:
		return

	_animating = true

	_panel.modulate.a = 0.0

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, FLY_IN_DUR)

	await tw.finished
	_animating = false


func _position_panels() -> void:
	if preview_clip.size.x < 2:
		return

	_panel.position = Vector2.ZERO
	_panel.size = preview_clip.size


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
	_music_preview.play(data)
	info_label.text = ""
	_transition_bg_color(data.accent_color)


func _transition_bg_color(target: Color) -> void:
	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()
	_bg_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bg_tween.tween_property(_bg, "color", target, 0.5)
	var bubbles = $Bubbles
	if bubbles.has_method("set_base_color"):
		_bg_tween.parallel().tween_method(bubbles.set_base_color, bubbles.base_color, target.lightened(0.3), 0.5)


func _apply_display_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	var default_view: String = cfg.get_value("display", "default_view", "card")
	var music_preview: bool = cfg.get_value("display", "music_preview", true)

	if default_view == "list" and _current_mode == ViewMode.CARD:
		_on_view_toggle_pressed()

	if not music_preview and _music_preview.player.playing:
		_music_preview.player.stop()
		_music_preview.player.stream = null
		_music_preview.current_data = null


func _process(_delta: float) -> void:
	_music_preview.process(_delta)
	_pck_loader.poll_verify()


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

	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw_out.tween_property(_panel, "modulate:a", 0.0, SLIDE_DUR)
	tw_out.tween_property(info_container, "modulate:a", 0.0, SLIDE_DUR * 0.6)

	await tw_out.finished

	current_index = (current_index + direction + levels.size()) % levels.size()
	_update_display()

	_panel.modulate.a = 0.0
	info_container.modulate.a = 0.0

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
	if _pck_loader.is_busy():
		if _pck_loader.phase == PCKLoader.Phase.IDLE:
			info_label.text = "正在下载中，请稍候..."
		return
	_pck_loader.start_level(levels[current_index])


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


func _on_import_pck_pressed() -> void:
	_import_dialog.popup_centered()


func _on_pck_file_selected(path: String) -> void:
	if path.begins_with("content://"):
		path = _copy_content_uri(path)
		if path.is_empty():
			info_label.text = "无法读取文件"
			return

	var result := _validate_pck(path)
	if result.is_empty():
		info_label.text = "无效PCK：未找到关卡场景"
		return

	var scene_path: String = result["scene_path"]
	var level_name: String = result["name"]

	print('[LevelManager] Importing PCK: "%s" -> scene: "%s"' % [path, scene_path])

	var success := ProjectSettings.load_resource_pack(path)
	if not success:
		print('[LevelManager] FAILED to load PCK: "%s"' % path)
		info_label.text = "PCK加载失败"
		return

	loaded_pcks.append(path)
	print('[LevelManager] PCK loaded successfully, switching to scene: "%s"' % scene_path)
	info_label.text = "正在加载: %s" % level_name
	get_tree().call_deferred("change_scene_to_file", scene_path)

func _copy_content_uri(uri: String) -> String:
	var src := FileAccess.open(uri, FileAccess.READ)
	if src == null:
		push_error("SAF: failed to open content URI: %s" % uri)
		return ""

	var cache_dir := ProjectSettings.globalize_path("user://cache/imports")
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var dest := cache_dir.path_join("import_%d.pck" % Time.get_unix_time_from_system())

	var dst := FileAccess.open(dest, FileAccess.WRITE)
	if dst == null:
		push_error("SAF: failed to write cache file: %s" % dest)
		return ""

	var buf: PackedByteArray
	while true:
		buf = src.get_buffer(1 << 16)
		if buf.is_empty():
			break
		dst.store_buffer(buf)

	src.close()
	dst.close()

	if FileAccess.file_exists(dest):
		print("SAF: copied %s -> %s" % [uri, dest])
		return dest
	push_error("SAF: copy completed but file not found at %s" % dest)
	return ""


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
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/gas_login.tscn")


func _scan_levels() -> void:
	levels.clear()
	if not ResourceLoader.exists(LEVEL_LIST_PATH):
		return
	var list := load(LEVEL_LIST_PATH)
	if list is MenuLevelList:
		levels = list.levels


func _on_pck_load_ready(data: MenuLevelData, scene_path: String) -> void:
	_sync_long_scene_manager_current_scene()
	LongSceneManager.switch_scene(scene_path,
		LongSceneManager.LoadMethod.DIRECT, false,
		"res://Scenes/CustomLoadScreen.tscn")


func _sync_long_scene_manager_current_scene() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	LongSceneManager.current_scene = tree.current_scene
	LongSceneManager.current_scene_path = tree.current_scene.scene_file_path


func _on_watch_ad_requested() -> void:
	_ad_system.start()


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
