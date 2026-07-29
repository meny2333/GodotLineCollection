class_name AnnouncementPanel
extends Control

signal closed()

@onready var _panel: PanelContainer = $Panel
@onready var _rich_text: RichTextLabel = $Panel/Margin/VBox/Content/RichText
@onready var _title_label: Label = $Panel/Margin/VBox/TitleBar/HBox/TitleLabel
@onready var _page_label: Label = $Panel/Margin/VBox/PageBar/HBox/PageLabel
@onready var _prev_btn: Button = $Panel/Margin/VBox/PageBar/HBox/PrevBtn
@onready var _next_btn: Button = $Panel/Margin/VBox/PageBar/HBox/NextBtn
@onready var _close_btn: Button = $Panel/Margin/VBox/TitleBar/HBox/CloseBtn
@onready var _loading_label: Label = $Panel/Margin/VBox/Content/LoadingLabel
@onready var _bg: ColorRect = $BG

var _pages: Array[String] = []
var _current_page: int = 0


func _ready() -> void:
	_bg.gui_input.connect(_on_bg_input)
	_close_btn.pressed.connect(_close)
	_prev_btn.pressed.connect(_prev_page)
	_next_btn.pressed.connect(_next_page)
	_center_panel()
	get_viewport().size_changed.connect(_center_panel)
	_fetch_announcements()


func _center_panel() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = (vp_size - _panel.size) * 0.5


func _fetch_announcements() -> void:
	_loading_label.visible = true
	_rich_text.visible = false
	_prev_btn.visible = false
	_next_btn.visible = false
	_page_label.visible = false
	_next_btn.disabled = true
	_prev_btn.disabled = true

	var config_service := ConfigService.new()
	var resp: Variant = await config_service.get_config()

	if resp is GASError:
		_loading_label.text = "公告加载失败"
		push_error("[AnnouncementPanel] Config error: %s" % resp.message)
		return

	var cfg_resp: ConfigResp = resp
	if not cfg_resp.is_success():
		_loading_label.text = "公告加载失败（%d）" % cfg_resp.code
		return

	var data: Variant = cfg_resp.data
	if typeof(data) != TYPE_DICTIONARY:
		_loading_label.text = "公告数据格式错误"
		return

	if data.has("config") and typeof(data["config"]) == TYPE_STRING:
		var decrypted := GASEncryption.decrypt(data["config"], GASConfigManager.app_token)
		if decrypted.is_empty():
			_loading_label.text = "公告解密失败"
			return
		var json := JSON.new()
		if json.parse(decrypted) != OK:
			_loading_label.text = "公告解析失败"
			return
		data = json.data

	_pages.clear()
	if typeof(data) == TYPE_DICTIONARY and data.has("announcements"):
		var anns = data["announcements"]
		if typeof(anns) == TYPE_ARRAY:
			for ann in anns:
				if typeof(ann) == TYPE_DICTIONARY and ann.has("content"):
					_pages.append(str(ann["content"]))
				elif typeof(ann) == TYPE_STRING:
					_pages.append(ann)
		elif typeof(anns) == TYPE_STRING:
			_pages.append(anns)
	elif typeof(data) == TYPE_DICTIONARY and data.has("announcement"):
		_pages.append(str(data["announcement"]))

	if _pages.is_empty():
		_loading_label.text = "暂无公告"
		return

	_loading_label.visible = false
	_rich_text.visible = true
	_show_page(0)


func _show_page(index: int) -> void:
	_current_page = index
	_rich_text.text = _pages[index]
	_page_label.visible = _pages.size() > 1
	_prev_btn.visible = _pages.size() > 1
	_next_btn.visible = _pages.size() > 1
	if _pages.size() > 1:
		_page_label.text = "%d / %d" % [index + 1, _pages.size()]
	_prev_btn.disabled = index == 0
	_next_btn.disabled = index == _pages.size() - 1


func _prev_page() -> void:
	if _current_page > 0:
		_show_page(_current_page - 1)


func _next_page() -> void:
	if _current_page < _pages.size() - 1:
		_show_page(_current_page + 1)


func _close() -> void:
	closed.emit()
	queue_free()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
