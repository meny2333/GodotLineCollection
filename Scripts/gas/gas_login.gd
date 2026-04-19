extends Control

signal login_finish(email: String, access_token: String)

var _oauth: OAuthService = OAuthService.new()
var _auto_login: AutoLoginService = AutoLoginService.new()
var _profile: ProfileService = ProfileService.new()
var _config: GASLoginConfig = GASLoginConfig.new()

var _auth_token: String = ""
var _access_token: String = ""
var _email: String = ""
var _app_id: int = 0
var _app_token: String = ""

@onready var card: PanelContainer = $CenterContainer/Card
@onready var title_label: Label = $CenterContainer/Card/VBox/TitleLabel
@onready var avatar_rect: TextureRect = $CenterContainer/Card/VBox/AvatarContainer/AvatarRect
@onready var avatar_container: PanelContainer = $CenterContainer/Card/VBox/AvatarContainer
@onready var status_label: Label = $CenterContainer/Card/VBox/StatusLabel
@onready var btn_login: Button = $CenterContainer/Card/VBox/BtnLogin
@onready var user_info: Label = $CenterContainer/Card/VBox/UserInfo
@onready var btn_back: Button = $CenterContainer/Card/VBox/BtnBack


func _ready() -> void:
	_app_id = GASConfigManager.app_id
	_app_token = GASConfigManager.app_token
	
	btn_login.pressed.connect(_on_login)
	btn_back.pressed.connect(_on_back)
	
	avatar_container.visible = false
	user_info.visible = false
	btn_back.visible = false
	
	card.modulate = Color.TRANSPARENT
	var tween := create_tween()
	tween.tween_property(card, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT)
	
	status_label.text = "正在尝试自动登录..."
	_try_auto_login()


func _try_auto_login() -> void:
	if not _config.load():
		status_label.text = "请点击登录按钮进行授权"
		btn_login.disabled = false
		return
	
	btn_login.disabled = true
	var resp = await _auto_login.auto_login(_config.email, _config.access_token)
	if resp is GASError:
		status_label.text = "自动登录失败，请重新登录"
		btn_login.disabled = false
		return
	
	_email = _config.email
	_access_token = _config.access_token
	
	var profile_resp = await _profile.get_profile(_email, _access_token)
	if profile_resp is GASError:
		status_label.text = "自动登录失败，请重新登录"
		btn_login.disabled = false
		return
	
	_on_login_success(profile_resp.data)


func _on_login() -> void:
	if _app_token == "" or _app_id == 0:
		status_label.text = "请先在 GASConfig.tres 中设置 app_id 和 app_token"
		return
	
	btn_login.disabled = true
	status_label.text = "请求 auth_token ..."
	
	var resp = await _oauth.get_auth_token()
	if resp is GASError:
		status_label.text = "错误：%s" % resp.message
		btn_login.disabled = false
		return
	
	_auth_token = str(resp.data.get("auth_token", ""))
	status_label.text = "已在浏览器打开授权页面，请授权后回到游戏"
	
	GASBrowserHandler.open_auth_browser(_app_id, _auth_token)
	_poll_auth(_auth_token)


func _poll_auth(auth_token: String) -> void:
	var max_retry: int = 10
	var interval_sec: float = 1.0
	
	for i in range(1, max_retry + 1):
		status_label.text = "OAuth 回调轮询第 %d/%d 次..." % [i, max_retry]
		
		var resp = await _oauth.exchange_auth_token(auth_token)
		if resp is GASError:
			pass
		elif resp.is_success():
			_access_token = str(resp.data.get("access_token", ""))
			_email = str(resp.data.get("email", ""))
			_config.save(_email, _access_token)
			
			var profile_resp = await _profile.get_profile(_email, _access_token)
			var data: Dictionary = {}
			if profile_resp is GASError:
				data = {"email": _email}
			else:
				data = profile_resp.data
			
			_on_login_success(data)
			return
		
		await Engine.get_main_loop().create_timer(interval_sec).timeout
	
	status_label.text = "授权超时，请重试"
	btn_login.disabled = false


func _on_login_success(data: Dictionary) -> void:
	var nickname: String = str(data.get("nickname", ""))
	var avatar_url: String = str(data.get("avatar", ""))
	var location: String = str(data.get("location", ""))
	var email: String = str(data.get("email", _email))
	
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


func _load_avatar(url: String) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return
	var result: Array = await http.request_completed
	var result_code: int = result[1]
	var body: PackedByteArray = result[3]
	if result_code == 200 and body.size() > 0:
		var image := Image.new()
		var ext: String = url.get_extension().to_lower()
		var img_err: int
		if ext == "png":
			img_err = image.load_png_from_buffer(body)
		elif ext == "jpg" or ext == "jpeg":
			img_err = image.load_jpg_from_buffer(body)
		elif ext == "webp":
			img_err = image.load_webp_from_buffer(body)
		else:
			img_err = image.load_jpg_from_buffer(body)
		if img_err == OK:
			var texture := ImageTexture.create_from_image(image)
			avatar_rect.texture = texture
	http.queue_free()


func _on_back() -> void:
	_navigate_back()


func _navigate_back() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	await tween.finished
	get_tree().change_scene_to_file("res://Scenes/LevelManager.tscn")
