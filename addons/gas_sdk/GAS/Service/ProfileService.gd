class_name ProfileService
extends RefCounted

var _http: GASHttpClient = GASHttpClient.new()

func get_profile(email: String, access_token: String) -> Variant:
	var send_req: ProfileReq = ProfileReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.email = email
	send_req.access_token = access_token
	var resp: Dictionary = await _http.post(GASApiRoute.PROFILE, send_req.to_dict())
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var profile_resp: ProfileResp = ProfileResp.new()
	profile_resp.code = int(resp.get("code", 0))
	profile_resp.msg = str(resp.get("msg", ""))
	profile_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(profile_resp)
	if err != null:
		return err
	return profile_resp