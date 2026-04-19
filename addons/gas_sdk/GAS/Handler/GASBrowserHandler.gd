class_name GASBrowserHandler
extends RefCounted

const OAUTH_URL: String = "https://gas.chinadlrs.com/oauth?appid={appid}&token={token}"


static func open_auth_browser(app_id: int, auth_token: String) -> void:
	var url: String = OAUTH_URL.replace("{appid}", str(app_id)).replace("{token}", auth_token)
	OS.shell_open(url)


static func to_register() -> void:
	OS.shell_open("https://chinadlrs.com/register/")


static func to_acc_rules() -> void:
	OS.shell_open("https://chinadlrs.com/policy/?page=account")