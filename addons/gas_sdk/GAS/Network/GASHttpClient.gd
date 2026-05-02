class_name GASHttpClient
extends RefCounted


func post(url: String, body: Dictionary, type: int = -1) -> Dictionary:
	var full_url: String
	if type == -1:
		full_url = "%s?lang=%s" % [url, GASConfigManager.lang_string]
	else:
		full_url = "%s?type=%d&lang=%s" % [url, type, GASConfigManager.lang_string]
	
	var json_body: String = JSON.stringify(body)
	GASResponseLogger.log_request("POST", full_url, json_body)
	
	var http: HTTPRequest = HTTPRequest.new()
	Engine.get_main_loop().root.add_child.call_deferred(http)
	await http.tree_entered
	
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var start_time: float = Time.get_ticks_msec()
	var error: Error = http.request(full_url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		http.queue_free()
		var err: GASError = GASError.network_error(error, "HTTP request failed")
		GASResponseLogger.log_error("POST", full_url, 0, "", err.message, 0)
		return {"_is_gas_error": true, "code": err.code, "message": err.message, "raw_text": err.raw_text}
	
	var result: Array = await http.request_completed
	var result_code: int = result[0]
	var response_code: int = result[1]
	var _headers: PackedStringArray = result[2]
	var body_bytes: PackedByteArray = result[3]
	var elapsed: float = Time.get_ticks_msec() - start_time
	var response_text: String = body_bytes.get_string_from_utf8()
	
	http.queue_free()
	
	if result_code != HTTPRequest.RESULT_SUCCESS:
		var err: GASError = GASError.network_error(response_code, "Network error: result_code=%d" % result_code, response_text)
		GASResponseLogger.log_error("POST", full_url, response_code, response_text, err.message, elapsed)
		return {"_is_gas_error": true, "code": err.code, "message": err.message, "raw_text": err.raw_text}
	
	GASResponseLogger.log_response("POST", full_url, response_code, response_text, elapsed)
	
	var parsed: Dictionary = _parse_json(response_text)
	if parsed.has("_is_gas_error"):
		return parsed
	
	parsed["_http_status"] = response_code
	return parsed


func http_get(url: String) -> Dictionary:
	var full_url: String = "%s?lang=%s" % [url, GASConfigManager.lang_string]
	GASResponseLogger.log_request("GET", full_url, "")
	
	var http: HTTPRequest = HTTPRequest.new()
	Engine.get_main_loop().root.add_child.call_deferred(http)
	await http.tree_entered
	
	var start_time: float = Time.get_ticks_msec()
	var error: Error = http.request(full_url, [], HTTPClient.METHOD_GET)
	
	if error != OK:
		http.queue_free()
		var err: GASError = GASError.network_error(error, "HTTP request failed")
		GASResponseLogger.log_error("GET", full_url, 0, "", err.message, 0)
		return {"_is_gas_error": true, "code": err.code, "message": err.message, "raw_text": err.raw_text}
	
	var result: Array = await http.request_completed
	var result_code: int = result[0]
	var response_code: int = result[1]
	var _headers: PackedStringArray = result[2]
	var body_bytes: PackedByteArray = result[3]
	var elapsed: float = Time.get_ticks_msec() - start_time
	var response_text: String = body_bytes.get_string_from_utf8()
	
	http.queue_free()
	
	if result_code != HTTPRequest.RESULT_SUCCESS:
		var err: GASError = GASError.network_error(response_code, "Network error: result_code=%d" % result_code, response_text)
		GASResponseLogger.log_error("GET", full_url, response_code, response_text, err.message, elapsed)
		return {"_is_gas_error": true, "code": err.code, "message": err.message, "raw_text": err.raw_text}
	
	GASResponseLogger.log_response("GET", full_url, response_code, response_text, elapsed)
	
	var parsed: Dictionary = _parse_json(response_text)
	if parsed.has("_is_gas_error"):
		return parsed
	
	parsed["_http_status"] = response_code
	return parsed


func _parse_json(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		var parse_err: GASError = GASError.parse_error("Failed to parse JSON: %s\nRaw: %s" % [json.get_error_message(), text])
		return {"_is_gas_error": true, "code": parse_err.code, "message": parse_err.message, "raw_text": text}
	var data: Variant = json.data
	if data == null:
		return {}
	if data is Dictionary:
		return data
	return {}
