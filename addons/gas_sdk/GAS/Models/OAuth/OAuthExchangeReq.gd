class_name OAuthExchangeReq
extends RefCounted

var appid: int = 0
var auth_token: String = ""

func to_dict() -> Dictionary:
	return {"appid": appid, "auth_token": auth_token}