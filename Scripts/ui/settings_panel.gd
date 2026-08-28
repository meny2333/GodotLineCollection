class_name SettingsPanel
extends Control

signal settings_closed()

const SETTINGS_CFG_PATH := "user://settings.cfg"

@onready var _panel: PanelContainer = $Panel
@onready var _scroll: ScrollContainer = $Panel/Margin/VBox/Scroll
@onready var _source_list: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/SourceSection/SourceList
@onready var _source_section: Control = $Panel/Margin/VBox/Scroll/Content/SourceSection
@onready var _cache_section: Control = $Panel/Margin/VBox/Scroll/Content/CacheSection
@onready var _quality_section: Control = $Panel/Margin/VBox/Scroll/Content/QualitySection
@onready var _display_section: Control = $Panel/Margin/VBox/Scroll/Content/DisplaySection
@onready var _quality_option: OptionButton = $Panel/Margin/VBox/Scroll/Content/QualitySection/QualityRow/QualityOption
@onready var _aa_option: OptionButton = $Panel/Margin/VBox/Scroll/Content/QualitySection/AARow/AAOption
@onready var _shadow_toggle: CheckButton = $Panel/Margin/VBox/Scroll/Content/QualitySection/ShadowRow/ShadowToggle
@onready var _post_toggle: CheckButton = $Panel/Margin/VBox/Scroll/Content/QualitySection/PostRow/PostToggle
@onready var _resolution_option: OptionButton = $Panel/Margin/VBox/Scroll/Content/QualitySection/ResolutionRow/ResolutionOption
@onready var _fps_option: OptionButton = $Panel/Margin/VBox/Scroll/Content/QualitySection/FpsRow/FpsOption
@onready var _cache_size_label: Label = $Panel/Margin/VBox/Scroll/Content/CacheSection/CacheSizeLabel
@onready var _cache_count_label: Label = $Panel/Margin/VBox/Scroll/Content/CacheSection/CacheCountLabel
@onready var _clear_btn: Button = $Panel/Margin/VBox/Scroll/Content/CacheSection/ClearBtn
@onready var _view_option: OptionButton = $Panel/Margin/VBox/Scroll/Content/DisplaySection/ViewRow/ViewOption
@onready var _music_toggle: CheckButton = $Panel/Margin/VBox/Scroll/Content/DisplaySection/MusicRow/MusicToggle
@onready var _back_btn: Button = $Panel/Margin/VBox/TitleBar/HBox/BackBtn
@onready var _confirm_dialog: AcceptDialog = $ConfirmDialog


func _ready() -> void:
	_center_panel()
	_populate_sources()
	_scan_cache()
	_view_option.add_item("卡片视图", 0)
	_view_option.add_item("列表视图", 1)
	for label in GraphicsQuality.QUALITY_LABELS:
		_quality_option.add_item(label)
	for label in GraphicsQuality.ANTIALIASING_LABELS:
		_aa_option.add_item(label)
	for label in GraphicsQuality.RESOLUTION_LABELS:
		_resolution_option.add_item(label)
	for label in GraphicsQuality.FPS_LABELS:
		_fps_option.add_item(label)
	_load_display_settings()
	_load_quality_settings()

	_back_btn.pressed.connect(_on_back_pressed)
	$Panel/Margin/VBox/TitleBar/HBox/NavIcons/QualityNav.pressed.connect(_scroll_to_section.bind(_quality_section))
	$Panel/Margin/VBox/TitleBar/HBox/NavIcons/SourceNav.pressed.connect(_scroll_to_section.bind(_source_section))
	$Panel/Margin/VBox/TitleBar/HBox/NavIcons/CacheNav.pressed.connect(_scroll_to_section.bind(_cache_section))
	$Panel/Margin/VBox/TitleBar/HBox/NavIcons/DisplayNav.pressed.connect(_scroll_to_section.bind(_display_section))
	_clear_btn.pressed.connect(_on_clear_cache)
	_confirm_dialog.confirmed.connect(_do_clear_cache)
	_view_option.item_selected.connect(_on_view_changed)
	_music_toggle.toggled.connect(_on_music_toggled)
	_quality_option.item_selected.connect(_on_quality_changed)
	_aa_option.item_selected.connect(_on_aa_changed)
	_shadow_toggle.toggled.connect(_on_shadow_toggled)
	_post_toggle.toggled.connect(_on_post_toggled)
	_resolution_option.item_selected.connect(_on_resolution_changed)
	_fps_option.item_selected.connect(_on_fps_changed)
	get_viewport().size_changed.connect(_center_panel)


func _center_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var pw := mini(520, viewport_size.x - 80)
	var ph := mini(580, viewport_size.y - 80)
	_panel.position = (viewport_size - Vector2(pw, ph)) / 2.0
	_panel.size = Vector2(pw, ph)


func _populate_sources() -> void:
	if not PCKDownloader.instance.has_sources():
		var label := Label.new()
		label.text = "暂无可用下载源"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		_source_list.add_child(label)
		return

	var group := ButtonGroup.new()
	var current_idx := PCKDownloader.instance.get_source_index()

	for i in range(PCKDownloader.instance.get_source_count()):
		var radio := CheckButton.new()
		radio.text = PCKDownloader.instance.get_source_name(i)
		radio.button_group = group
		radio.button_pressed = (i == current_idx)
		radio.pressed.connect(_on_source_selected.bind(i))
		_source_list.add_child(radio)


func _on_source_selected(index: int) -> void:
	PCKDownloader.instance.set_source(index)


func _scan_cache() -> void:
	var cache_dir := ProjectSettings.globalize_path("user://pck_cache/")
	if not DirAccess.dir_exists_absolute(cache_dir):
		_cache_size_label.text = "缓存大小: —"
		_cache_count_label.text = "关卡数量: 0"
		_clear_btn.disabled = true
		return

	var dir := DirAccess.open(cache_dir)
	if dir == null:
		_cache_size_label.text = "无法读取缓存目录"
		_cache_count_label.text = ""
		_clear_btn.disabled = true
		return

	var total_size: int = 0
	var count: int = 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != ".." and not dir.current_is_dir():
			var file_path := cache_dir.path_join(file_name)
			var f := FileAccess.open(file_path, FileAccess.READ)
			if f:
				total_size += f.get_length()
				f.close()
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	_cache_size_label.text = "缓存大小: %s" % _format_size(total_size)
	_cache_count_label.text = "关卡数量: %d 个" % count
	_clear_btn.disabled = (count == 0)


func _format_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))
	else:
		return "%.2f GB" % (bytes / (1024.0 * 1024.0 * 1024.0))


func _on_clear_cache() -> void:
	_confirm_dialog.popup_centered()


func _do_clear_cache() -> void:
	var cache_dir := ProjectSettings.globalize_path("user://pck_cache/")
	var dir := DirAccess.open(cache_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != ".." and not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	_scan_cache()


func _load_display_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_CFG_PATH)

	var default_view: String = "card"
	var music_preview: bool = true

	if err == OK:
		default_view = cfg.get_value("display", "default_view", "card")
		music_preview = cfg.get_value("display", "music_preview", true)

	_view_option.selected = 0 if default_view == "card" else 1
	_music_toggle.button_pressed = music_preview


func _on_view_changed(index: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_CFG_PATH)
	cfg.set_value("display", "default_view", "card" if index == 0 else "list")
	cfg.save(SETTINGS_CFG_PATH)


func _on_music_toggled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_CFG_PATH)
	cfg.set_value("display", "music_preview", enabled)
	cfg.save(SETTINGS_CFG_PATH)


func _load_quality_settings() -> void:
	GraphicsQuality.loadSettings()
	_quality_option.select(GraphicsQuality.qualityLevel)
	_aa_option.select(GraphicsQuality.antiAliasLevel)
	_shadow_toggle.button_pressed = GraphicsQuality.shadowsEnabled
	_post_toggle.button_pressed = GraphicsQuality.postProcessEnabled
	_resolution_option.select(GraphicsQuality.resolutionIndex)
	_fps_option.select(GraphicsQuality.fpsIndex)


func _apply_quality() -> void:
	GraphicsQuality.saveSettings()
	var env: Environment = null
	var cam := get_viewport().get_camera_3d()
	if cam:
		env = cam.environment
	GraphicsQuality.applyToScene(get_viewport(), get_tree(), env)


func _on_quality_changed(index: int) -> void:
	GraphicsQuality.setLevel(index)
	_apply_quality()


func _on_aa_changed(index: int) -> void:
	GraphicsQuality.antiAliasLevel = index
	_apply_quality()


func _on_shadow_toggled(enabled: bool) -> void:
	GraphicsQuality.shadowsEnabled = enabled
	_apply_quality()


func _on_post_toggled(enabled: bool) -> void:
	GraphicsQuality.postProcessEnabled = enabled
	_apply_quality()


func _on_resolution_changed(index: int) -> void:
	GraphicsQuality.resolutionIndex = index
	_apply_quality()


func _on_fps_changed(index: int) -> void:
	GraphicsQuality.fpsIndex = index
	_apply_quality()


func _scroll_to_section(section: Control) -> void:
	var target_y := maxf(0, section.position.y - 8)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_scroll, "scroll_vertical", target_y, 0.3)


func _on_back_pressed() -> void:
	settings_closed.emit()
	queue_free()
