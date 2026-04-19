class_name ConfigReq
extends RefCounted

var appid: int = 0

func to_dict() -> Dictionary:
	return {"appid": appid}