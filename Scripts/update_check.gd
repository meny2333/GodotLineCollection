extends Control

const NEXT_SCENE := "res://Scenes/gas_login.tscn"

@onready var _status: Label = $Center/VBox/Status
@onready var _bar: ProgressBar = $Center/VBox/Bar
@onready var _update_btn: Button = $Center/VBox/Buttons/UpdateBtn
@onready var _skip_btn: Button = $Center/VBox/Buttons/SkipBtn


func _ready() -> void:
	_bar.visible = false
	_update_btn.visible = false
	_skip_btn.visible = false
	_update_btn.pressed.connect(_on_update)
	_skip_btn.pressed.connect(_on_skip)
	HotUpdate.download_progress.connect(_on_progress)
	_status.text = "正在检查更新…"
	await HotUpdate.check_updates()
	if HotUpdate.pending.is_empty():
		_go_next()
		return
	var names: PackedStringArray = PackedStringArray()
	for entry in HotUpdate.pending:
		names.append(str(entry.get("filename", "pack")))
	_status.text = ("必须更新：\n" if HotUpdate.force_update else "发现更新：\n") + "\n".join(names)
	_update_btn.visible = true
	_skip_btn.visible = true
	_skip_btn.text = "退出" if HotUpdate.force_update else "稍后"
	_skip_btn.disabled = false


func _on_update() -> void:
	_update_btn.disabled = true
	_skip_btn.disabled = true
	_bar.visible = true
	_status.text = "正在下载…"
	HotUpdate._progress = _bar
	HotUpdate._status = _status
	var ok: bool = await HotUpdate._downloadPending()
	_status.text = "更新完成" if ok else "下载失败"
	await get_tree().create_timer(0.4).timeout
	_go_next()


func _on_skip() -> void:
	if HotUpdate.force_update:
		get_tree().quit()
		return
	HotUpdate.pending.clear()
	_go_next()


func _on_progress(_filename: String, percent: float) -> void:
	_bar.value = percent


func _go_next() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
