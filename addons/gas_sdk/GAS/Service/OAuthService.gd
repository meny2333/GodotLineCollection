class_name OAuthService
extends RefCounted

var _http: GASHttpClient = GASHttpClient.new()

func get_auth_token() -> Variant:
	var encrypted: String = GASEncryption.encrypt(GASConfigManager.app_token, GASConfigManager.app_token)
	var send_req: OAuthAuthTokenReq = OAuthAuthTokenReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.apptoken = encrypted
	var resp: Dictionary = await _http.post(GASApiRoute.OAUTH, send_req.to_dict(), 1)
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var auth_resp: OAuthAuthTokenResp = OAuthAuthTokenResp.new()
	auth_resp.code = int(resp.get("code", 0))
	auth_resp.msg = str(resp.get("msg", ""))
	auth_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(auth_resp)
	if err != null:
		return err
	return auth_resp

func exchange_auth_token(auth_token: String) -> Variant:
	var send_req: OAuthExchangeReq = OAuthExchangeReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.auth_token = auth_token
	var resp: Dictionary = await _http.post(GASApiRoute.OAUTH, send_req.to_dict(), 4)
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var access_resp: OAuthAccessResp = OAuthAccessResp.new()
	access_resp.code = int(resp.get("code", 0))
	access_resp.msg = str(resp.get("msg", ""))
	access_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(access_resp)
	if err != null:
		return err
	return access_resp

func logout(email: String, access_token: String) -> Variant:
	var send_req: OAuthLogoutReq = OAuthLogoutReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.email = email
	send_req.access_token = access_token
	var resp: Dictionary = await _http.post(GASApiRoute.OAUTH, send_req.to_dict(), 5)
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var logout_resp: OAuthLogoutResp = OAuthLogoutResp.new()
	logout_resp.code = int(resp.get("code", 0))
	logout_resp.msg = str(resp.get("msg", ""))
	logout_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(logout_resp)
	if err != null:
		return err
	return logout_resp
