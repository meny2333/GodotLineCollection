class_name AutoLoginService
extends RefCounted

var _http: GASHttpClient = GASHttpClient.new()

func auto_login(email: String, access_token: String) -> Variant:
	var send_req: AutoLoginReq = AutoLoginReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.email = email
	send_req.access_token = access_token
	var resp: Dictionary = await _http.post(GASApiRoute.AUTO_LOGIN, send_req.to_dict())
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var login_resp: AutoLoginResp = AutoLoginResp.new()
	login_resp.code = int(resp.get("code", 0))
	login_resp.msg = str(resp.get("msg", ""))
	login_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(login_resp)
	if err != null:
		return err
	return login_resp