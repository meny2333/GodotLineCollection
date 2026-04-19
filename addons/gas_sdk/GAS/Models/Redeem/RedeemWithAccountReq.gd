class_name RedeemWithAccountReq
extends RefCounted

var appid: int = 0
var email: String = ""
var access_token: String = ""
var redeem_code: String = ""

func to_dict() -> Dictionary:
	return {"appid": appid, "email": email, "access_token": access_token, "redeem_code": redeem_code}