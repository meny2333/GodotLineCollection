class_name ProfileReq
extends RefCounted

var appid: int = 0
var email: String = ""
var access_token: String = ""

func to_dict() -> Dictionary:
	return {"appid": appid, "email": email, "access_token": access_token}