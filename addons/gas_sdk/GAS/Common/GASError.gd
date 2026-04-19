class_name GASError
extends RefCounted

var code: int = -500
var message: String = ""
var raw_text: String = ""


func _init(p_code: int = -500, p_message: String = "", p_raw_text: String = "") -> void:
	code = p_code
	message = p_message
	raw_text = p_raw_text


func _to_string() -> String:
	return "[GASError] code=%d message=%s" % [code, message]


static func network_error(p_code: int, p_message: String, p_raw_text: String = "") -> GASError:
	return GASError.new(p_code, p_message, p_raw_text)


static func parse_error(p_message: String) -> GASError:
	return GASError.new(-1, p_message, "")