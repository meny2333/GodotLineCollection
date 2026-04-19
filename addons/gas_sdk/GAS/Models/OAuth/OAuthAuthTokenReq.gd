class_name OAuthAuthTokenReq
extends RefCounted

var appid: int = 0
var apptoken: String = ""

func to_dict() -> Dictionary:
	return {"appid": appid, "apptoken": apptoken}