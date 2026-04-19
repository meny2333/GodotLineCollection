class_name GASLoginConfig
extends RefCounted

const CONFIG_PATH: String = "user://gas_config.cfg"
const SECTION: String = "auth"

var email: String = ""
var access_token: String = ""


func save(p_email: String, p_access_token: String) -> void:
	email = p_email
	access_token = p_access_token
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "email", email)
	config.set_value(SECTION, "access_token", access_token)
	config.save(CONFIG_PATH)


func load() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return false
	email = config.get_value(SECTION, "email", "")
	access_token = config.get_value(SECTION, "access_token", "")
	return email != "" and access_token != ""


func clear() -> void:
	email = ""
	access_token = ""
	var config: ConfigFile = ConfigFile.new()
	config.save(CONFIG_PATH)