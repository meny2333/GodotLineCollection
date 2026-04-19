class_name ConfigResp
extends RefCounted

var code: int = 0
var msg: String = ""
var data: Variant = {}

func is_success() -> bool:
	return code == 200