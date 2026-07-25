class_name AdSystem
extends Node

var _overlay: Control
var _player: VLCMediaPlayer
var _skip_label: Label
var _skip_timer: Timer
var _http: HTTPRequest
var _info_label: Label

var _urls: Array[String] = []
var _downloading: bool = false
var _reward_pending: bool = false
var _ad_music_muted: bool = false

signal reward_claimed(amount: int)
signal playback_started()
signal playback_ended()

const AD_LIST_URL := "https://gitee.com/des24k/DLCEADSlib/raw/master/CNads.txt"
const AD_CACHE_DIR := "user://ad_cache"

func _init(parent: Node, info_label: Label) -> void:
	parent.add_child(self)
	_info_label = info_label

	var scene := preload("res://Scenes/ad_overlay.tscn").instantiate()
	_overlay = scene
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	parent.add_child(_overlay)

	_player = VLCMediaPlayer.new()
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_player)

	_skip_label = _overlay.get_node("SkipLabel")

	_skip_timer = _overlay.get_node("SkipTimer")
	_skip_timer.timeout.connect(_on_skip_timer_timeout)

	_http = HTTPRequest.new()
	parent.add_child(_http)

func prefetch_ads() -> void:
	_fetch_list()

func start() -> void:
	if _downloading:
		_info_label.text = "正在加载广告，请稍候..."
		return
	if _urls.is_empty():
		_info_label.text = "广告列表为空，正在获取..."
		await _fetch_list()
	if _urls.is_empty():
		_info_label.text = "无法获取广告列表"
		return
	_download_random()

func _fetch_list() -> void:
	if _http.request_completed.is_connected(_on_list_fetched):
		_http.request_completed.disconnect(_on_list_fetched) 
	else:
		_http.request_completed.connect(_on_list_fetched)
	var err := _http.request(AD_LIST_URL)
	if err != OK:
		print("[Ad] Failed to request ad list: ", err)

func _on_list_fetched(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_list_fetched)
	var text := body.get_string_from_utf8()
	var urls: Array[String] = []
	for line in text.split("\n", false):
		line = line.strip_edges()
		if line.is_empty():
			continue
		if not line.begins_with("http://") and not line.begins_with("https://"):
			line = "https://" + line
		urls.append(line)
	_urls = urls
	print("[Ad] Loaded %d ad URLs" % _urls.size())

func _download_random() -> void:
	if _urls.is_empty():
		return
	_downloading = true
	var url := _urls[randi() % _urls.size()]
	var file_name := url.get_file()
	if file_name.is_empty():
		file_name = "ad_%d.mp4" % Time.get_unix_time_from_system()
	var cache_dir := ProjectSettings.globalize_path(AD_CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var local_path := AD_CACHE_DIR.path_join(file_name)
	var global_path := ProjectSettings.globalize_path(local_path)

	if FileAccess.file_exists(global_path):
		print("[Ad] Using cached ad: ", local_path)
		_downloading = false
		_play(global_path)
		return

	_info_label.text = "加载广告中..."
	_http.request_completed.disconnect(_on_downloaded) if _http.request_completed.is_connected(_on_downloaded) else null
	_http.request_completed.connect(_on_downloaded.bind(local_path))
	var err := _http.request(url)
	if err != OK:
		_downloading = false
		_info_label.text = "广告加载失败"
		print("[Ad] Download request failed: ", err)

func _on_downloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, local_path: String) -> void:
	_http.request_completed.disconnect(_on_downloaded)
	_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_info_label.text = "广告下载失败"
		print("[Ad] Download failed: result=%d code=%d" % [result, response_code])
		return
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		_info_label.text = "广告缓存失败"
		print("[Ad] Failed to write cache: ", local_path)
		return
	file.store_buffer(body)
	file.close()
	print("[Ad] Downloaded and cached: ", local_path, " (", body.size(), " bytes)")
	_play(ProjectSettings.globalize_path(local_path))

func _play(video_path: String) -> void:
	playback_started.emit()
	_overlay.visible = true
	_skip_label.visible = false
	_reward_pending = false

	var media := VLCMedia.load_from_file(video_path)
	_player.set_media(media)

	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		_ad_music_muted = AudioServer.is_bus_mute(music_bus_idx)
		AudioServer.set_bus_mute(music_bus_idx, true)

	_player.play()
	_skip_timer.start()

	_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.3)

func _on_skip_timer_timeout() -> void:
	_skip_label.visible = true

func _on_overlay_input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if not _skip_label.visible:
		return
	if event is InputEventMouseButton:
		_on_skip()

func _on_skip() -> void:
	if _reward_pending:
		return
	_skip_timer.stop()
	_player.stop_async()
	_overlay.visible = false

	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		AudioServer.set_bus_mute(music_bus_idx, _ad_music_muted)

	if _skip_label.visible:
		_claim_reward()

func _claim_reward() -> void:
	if _reward_pending:
		return
	_reward_pending = true
	var amount := 10
	reward_claimed.emit(amount)
	_info_label.text = "获得%d个代币！" % amount
	print("[Ad] Reward claimed: +%d energy" % amount)
	_skip_timer.stop()
	_player.stop_async()
	_overlay.visible = false

	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		AudioServer.set_bus_mute(music_bus_idx, _ad_music_muted)
