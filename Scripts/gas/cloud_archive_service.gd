extends Node

var _archive_service: ArchiveService = ArchiveService.new()
var _adapter: GASArchiveAdapter = GASArchiveAdapter.new()
var _email: String = ""
var _access_token: String = ""
var _save_timer: Timer
var _has_credentials: bool = false

signal sync_complete(success: bool)


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 2.0
	_save_timer.timeout.connect(_on_save_timer_timeout)
	add_child(_save_timer)


func set_credentials(email: String, access_token: String) -> void:
	_email = email
	_access_token = access_token
	_has_credentials = email != "" and access_token != ""


func has_credentials() -> bool:
	return _has_credentials


func sync_on_login() -> void:
	if not _has_credentials:
		push_warning("[CloudArchiveService] No credentials set")
		sync_complete.emit(false)
		return
	
	var resp = await _archive_service.read(_email, _access_token)
	if resp is GASError:
		push_warning("[CloudArchiveService] Read failed: %s" % resp.message)
		sync_complete.emit(false)
		return
	
	var cloud_content: String = str(resp.data.get("content", ""))
	var cloud_update_time: String = str(resp.data.get("update_time", ""))
	
	if cloud_content == "" or cloud_content == "null":
		queue_save("first_upload")
		sync_complete.emit(true)
		return
	
	var decrypted: String = _archive_service.decrypt_archive_content(cloud_content)
	
	var local_json: String = _adapter.to_cloud_json()
	var local_data: Dictionary = {}
	var cloud_data: Dictionary = {}
	
	var local_parse: JSON = JSON.new()
	if local_parse.parse(local_json) == OK and local_parse.data is Dictionary:
		local_data = local_parse.data
	
	var cloud_parse: JSON = JSON.new()
	if cloud_parse.parse(decrypted) == OK and cloud_parse.data is Dictionary:
		cloud_data = cloud_parse.data
	
	var local_time: String = str(local_data.get("cloud_save_time", ""))
	var cloud_time: String = cloud_update_time
	
	if local_time == "" or cloud_time > local_time:
		_adapter.apply_cloud_json(decrypted)
		sync_complete.emit(true)
	else:
		queue_save("local_newer")
		sync_complete.emit(true)


func queue_save(reason: String = "runtime") -> void:
	_save_timer.start(2.0)


func _on_save_timer_timeout() -> void:
	if not _has_credentials:
		return
	var content: String = _adapter.to_cloud_json()
	var version: String = ProjectSettings.get_setting("application/config/version")
	var resp = await _archive_service.save(_email, _access_token, version, content)
	if resp is GASError:
		push_error("[CloudArchiveService] Save failed: %s" % resp.message)
	else:
		print("[CloudArchiveService] Cloud save successful")
