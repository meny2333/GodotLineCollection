class_name RedeemService
extends RefCounted

var _http: GASHttpClient = GASHttpClient.new()

func redeem_anonymous(redeem_code: String) -> Variant:
	var send_req: RedeemAnonymousReq = RedeemAnonymousReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.redeem_code = redeem_code
	var resp: Dictionary = await _http.post(GASApiRoute.REDEEM, send_req.to_dict())
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var redeem_resp: RedeemResp = RedeemResp.new()
	redeem_resp.code = int(resp.get("code", 0))
	redeem_resp.msg = str(resp.get("msg", ""))
	redeem_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(redeem_resp)
	if err != null:
		return err
	return redeem_resp

func redeem_with_account(email: String, access_token: String, redeem_code: String) -> Variant:
	var send_req: RedeemWithAccountReq = RedeemWithAccountReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.email = email
	send_req.access_token = access_token
	send_req.redeem_code = redeem_code
	var resp: Dictionary = await _http.post(GASApiRoute.REDEEM, send_req.to_dict())
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var redeem_resp: RedeemResp = RedeemResp.new()
	redeem_resp.code = int(resp.get("code", 0))
	redeem_resp.msg = str(resp.get("msg", ""))
	redeem_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(redeem_resp)
	if err != null:
		return err
	return redeem_resp

func decrypt_redeem_content(encrypted_content: String) -> String:
	return GASEncryption.decrypt(encrypted_content, GASConfigManager.app_token)