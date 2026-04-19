class_name VersionReq
extends RefCounted

var appid: int = 0
var sequence: String = ""

func to_dict() -> Dictionary:
	return {"appid": appid, "sequence": sequence}