class_name RedeemAnonymousReq
extends RefCounted

var appid: int = 0
var redeem_code: String = ""

func to_dict() -> Dictionary:
	return {"appid": appid, "redeem_code": redeem_code}