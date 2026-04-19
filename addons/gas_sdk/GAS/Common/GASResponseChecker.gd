class_name GASResponseChecker
extends RefCounted


static func ensure_success(resp) -> GASError:
	if resp == null:
		return GASError.parse_error("Response is null")
	if resp.code != 200:
		var msg: String = resp.msg if resp.msg != "" else "Unknown error"
		return GASError.new(resp.code, msg, "")
	return null