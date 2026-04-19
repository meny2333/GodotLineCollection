class_name ArchiveSaveReq
extends RefCounted

var appid: int = 0
var email: String = ""
var access_token: String = ""
var app_version: String = ""
var content: String = ""

func to_dict() -> Dictionary:
	return {"appid": appid, "email": email, "access_token": access_token, "app_version": app_version, "content": content}