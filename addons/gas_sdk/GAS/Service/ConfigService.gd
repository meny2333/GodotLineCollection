class_name ConfigService
extends RefCounted

var _http: GASHttpClient = GASHttpClient.new()

func get_config() -> Variant:
	var send_req: ConfigReq = ConfigReq.new()
	send_req.appid = GASConfigManager.app_id
	var resp: Dictionary = await _http.post(GASApiRoute.CONFIG, send_req.to_dict())
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var config_resp: ConfigResp = ConfigResp.new()
	config_resp.code = int(resp.get("code", 0))
	config_resp.msg = str(resp.get("msg", ""))
	config_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(config_resp)
	if err != null:
		return err
	return config_resp

func decrypt_config(encrypted_config: String) -> String:
	return GASEncryption.decrypt(encrypted_config, GASConfigManager.app_token)