class_name VersionService
extends RefCounted

var _http: GASHttpClient = GASHttpClient.new()

func get_version(sequence: String) -> Variant:
	var encrypted: String = GASEncryption.encrypt(sequence, GASConfigManager.app_token)
	var send_req: VersionReq = VersionReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.sequence = encrypted
	var resp: Dictionary = await _http.post(GASApiRoute.VERSION, send_req.to_dict())
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var version_resp: VersionResp = VersionResp.new()
	version_resp.code = int(resp.get("code", 0))
	version_resp.msg = str(resp.get("msg", ""))
	version_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(version_resp)
	if err != null:
		return err
	return version_resp

func decrypt_version(encrypted_content: String) -> PackedStringArray:
	var decrypted: String = GASEncryption.decrypt(encrypted_content, GASConfigManager.app_token)
	if decrypted == "":
		return PackedStringArray()
	var parts: PackedStringArray = decrypted.split(",", false)
	var result: PackedStringArray = PackedStringArray()
	for part in parts:
		var trimmed: String = part.strip_edges()
		if trimmed != "":
			result.append(trimmed)
	return result