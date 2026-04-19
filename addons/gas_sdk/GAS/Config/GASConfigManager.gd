class_name GASConfigManager
extends RefCounted

static var _config: GASConfig = null
static var _lang: int = 0

static var config: GASConfig:
	get:
		if _config == null:
			_config = ResourceLoader.load("res://addons/gas_sdk/Resources/GASConfig.tres") as GASConfig
			if _config == null:
				push_error("[GAS] GASConfig not found! Please create GASConfig.tres under res://addons/gas_sdk/Resources/")
		return _config

static var app_id: int:
	get:
		return config.app_id if config != null else 0

static var app_token: String:
	get:
		return config.app_token if config != null else ""

static var lang: int:
	get:
		return _lang
	set(value):
		_lang = value

static var lang_string: String:
	get:
		return "zh" if _lang == 0 else "en"