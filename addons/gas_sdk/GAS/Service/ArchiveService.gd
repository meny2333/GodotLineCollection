class_name ArchiveService
extends RefCounted

var _http: GASHttpClient = GASHttpClient.new()

func read(email: String, access_token: String) -> Variant:
	var send_req: ArchiveReadReq = ArchiveReadReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.email = email
	send_req.access_token = access_token
	var resp: Dictionary = await _http.post(GASApiRoute.ARCHIVE, send_req.to_dict(), 1)
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var read_resp: ArchiveReadResp = ArchiveReadResp.new()
	read_resp.code = int(resp.get("code", 0))
	read_resp.msg = str(resp.get("msg", ""))
	read_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(read_resp)
	if err != null:
		return err
	return read_resp

func save(email: String, access_token: String, version: String, plain_content: String) -> Variant:
	var encrypted_content: String = GASEncryption.encrypt(plain_content, GASConfigManager.app_token)
	var encrypted_version: String = GASEncryption.encrypt(version, GASConfigManager.app_token)
	var send_req: ArchiveSaveReq = ArchiveSaveReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.email = email
	send_req.access_token = access_token
	send_req.app_version = encrypted_version
	send_req.content = encrypted_content
	var resp: Dictionary = await _http.post(GASApiRoute.ARCHIVE, send_req.to_dict(), 2)
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var save_resp: ArchiveSaveResp = ArchiveSaveResp.new()
	save_resp.code = int(resp.get("code", 0))
	save_resp.msg = str(resp.get("msg", ""))
	save_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(save_resp)
	if err != null:
		return err
	return save_resp

func delete(email: String, access_token: String) -> Variant:
	var send_req: ArchiveDeleteReq = ArchiveDeleteReq.new()
	send_req.appid = GASConfigManager.app_id
	send_req.email = email
	send_req.access_token = access_token
	var resp: Dictionary = await _http.post(GASApiRoute.ARCHIVE, send_req.to_dict(), 3)
	if resp.has("_is_gas_error"):
		return GASError.new(resp.code, resp.message, resp.raw_text)
	var delete_resp: ArchiveDeleteResp = ArchiveDeleteResp.new()
	delete_resp.code = int(resp.get("code", 0))
	delete_resp.msg = str(resp.get("msg", ""))
	delete_resp.data = resp.get("data") if resp.get("data") != null else {}
	var err: GASError = GASResponseChecker.ensure_success(delete_resp)
	if err != null:
		return err
	return delete_resp

func decrypt_archive_content(encrypted_content: String) -> String:
	return GASEncryption.decrypt(encrypted_content, GASConfigManager.app_token)