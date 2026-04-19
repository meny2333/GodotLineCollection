extends Control

var _oauth: OAuthService = OAuthService.new()
var _auto_login: AutoLoginService = AutoLoginService.new()
var _profile: ProfileService = ProfileService.new()
var _archive: ArchiveService = ArchiveService.new()
var _version: VersionService = VersionService.new()
var _redeem: RedeemService = RedeemService.new()

var _auth_token: String = ""
var _access_token: String = ""
var _email: String = ""
var _app_id: int = 0
var _app_token: String = ""

@onready var btn_oauth: Button = $VBox/BtnOAuth
@onready var btn_profile: Button = $VBox/BtnProfile
@onready var btn_save_archive: Button = $VBox/BtnSaveArchive
@onready var btn_read_archive: Button = $VBox/BtnReadArchive
@onready var btn_version: Button = $VBox/BtnVersion
@onready var btn_redeem: Button = $VBox/BtnRedeem
@onready var btn_logout: Button = $VBox/BtnLogout
@onready var btn_lang_zh: Button = $VBox/HBoxLang/BtnLangZH
@onready var btn_lang_en: Button = $VBox/HBoxLang/BtnLangEN
@onready var log_text: RichTextLabel = $VBox/LogPanel/LogText
@onready var version_input: LineEdit = $VBox/HBoxVersion/VersionInput
@onready var redeem_input: LineEdit = $VBox/HBoxRedeem/RedeemInput


func _ready() -> void:
	_app_id = GASConfigManager.app_id
	_app_token = GASConfigManager.app_token
	
	btn_oauth.pressed.connect(_on_btn_oauth)
	btn_profile.pressed.connect(_on_btn_profile)
	btn_save_archive.pressed.connect(_on_btn_save_archive)
	btn_read_archive.pressed.connect(_on_btn_read_archive)
	btn_version.pressed.connect(_on_btn_version)
	btn_redeem.pressed.connect(_on_btn_redeem)
	btn_logout.pressed.connect(_on_btn_logout)
	btn_lang_zh.pressed.connect(func(): GASConfigManager.lang = GASLang.ZH; _log("切换接口语言：zh"))
	btn_lang_en.pressed.connect(func(): GASConfigManager.lang = GASLang.EN; _log("切换接口语言：en"))
	
	btn_logout.disabled = true


func _log(msg: String) -> void:
	print(msg)
	log_text.append_text(msg + "\n")


func _on_btn_oauth() -> void:
	if _app_token == "" or _app_id == 0:
		_log("请先设置 app_id 和 app_token")
		return
	_log("请求 auth_token ...")
	btn_oauth.disabled = true
	
	var resp = await _oauth.get_auth_token()
	if resp is GASError:
		_log("错误：%s" % resp.message)
		btn_oauth.disabled = false
		return
	
	_auth_token = resp.data.get("auth_token", "")
	_log("auth_token = %s" % _auth_token)
	
	GASBrowserHandler.open_auth_browser(_app_id, _auth_token)
	_log("已打开浏览器进行授权，请授权后回到游戏")
	_poll_auth(_auth_token)


func _poll_auth(auth_token: String) -> void:
	var max_retry: int = 10
	var interval_ms: int = 1000
	
	for i in range(1, max_retry + 1):
		_log("OAuth 回调轮询第 %d/%d 次..." % [i, max_retry])
		
		var resp = await _oauth.exchange_auth_token(auth_token)
		if resp is GASError:
			_log("回调检查失败：%s" % resp.message)
		elif resp.is_success():
			_access_token = str(resp.data.get("access_token", ""))
			_email = str(resp.data.get("email", ""))
			btn_logout.disabled = false
			_log("%s\naccess_token = %s\nemail = %s" % [resp.msg, _access_token, _email])
			return
		
		await Engine.get_main_loop().create_timer(interval_ms / 1000.0).timeout
	
	_log("轮询结束：未获得授权，请确认是否已在浏览器完成授权。")
	btn_oauth.disabled = false


func _on_btn_profile() -> void:
	if _access_token == "":
		_log("请先完成 OAuth")
		return
	var resp = await _profile.get_profile(_email, _access_token)
	if resp is GASError:
		_log("错误：%s" % resp.message)
		return
	_log("Profile = %s" % str(resp.data.get("nickname", "")))


func _on_btn_save_archive() -> void:
	if _access_token == "":
		_log("请先完成 OAuth")
		return
	var content: String = '{"level":1, "percent":100, "diamond":10}'
	var resp = await _archive.save(_email, _access_token, ProjectSettings.get_setting("application/config/version"), content)
	if resp is GASError:
		_log("错误：%s" % resp.message)
		return
	_log(resp.msg)


func _on_btn_read_archive() -> void:
	if _access_token == "":
		_log("请先完成 OAuth")
		return
	var resp = await _archive.read(_email, _access_token)
	if resp is GASError:
		_log("错误：%s" % resp.message)
		return
	var decrypted: String = _archive.decrypt_archive_content(str(resp.data.get("content", "")))
	_log("存档内容 = %s" % decrypted)


func _on_btn_version() -> void:
	if _access_token == "":
		_log("请先完成 OAuth")
		return
	var sequence: String = version_input.text
	var resp = await _version.get_version(sequence)
	if resp is GASError:
		_log("错误：%s" % resp.message)
		return
	var encrypted_versions: String = str(resp.data.get("version", ""))
	var versions: PackedStringArray = _version.decrypt_version(encrypted_versions)
	_log("加密版本号：%s" % encrypted_versions)
	_log("解密版本号：%s" % ",".join(versions))


func _on_btn_redeem() -> void:
	if _access_token == "":
		_log("请先完成 OAuth")
		return
	var code: String = redeem_input.text
	var resp = await _redeem.redeem_with_account(_email, _access_token, code)
	if resp is GASError:
		_log("错误：%s" % resp.message)
		return
	var decrypted: String = _redeem.decrypt_redeem_content(str(resp.data.get("content", "")))
	_log("兑换结果：%s" % decrypted)


func _on_btn_logout() -> void:
	if _access_token == "":
		_log("请先完成 OAuth")
		return
	var resp = await _oauth.logout(_email, _access_token)
	if resp is GASError:
		_log("错误：%s" % resp.message)
		return
	btn_logout.disabled = true
	btn_oauth.disabled = false
	_access_token = ""
	_email = ""
	_log("已注销登录状态：%d" % resp.code)