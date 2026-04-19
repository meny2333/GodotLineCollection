class_name GASResponseLogger
extends RefCounted

const TAG: String = "[GAS HTTP]"


static func log_request(method: String, url: String, body: String) -> void:
	var body_line: String = "\nBody: %s" % body if body != "" else ""
	print("%s REQUEST BEGIN ▶\nMethod: %s\nURL: %s%s\n──────────────────────────────────────────" % [TAG, method, url, body_line])


static func log_response(method: String, url: String, status: int, response: String, ms: float) -> void:
	print("%s RESPONSE ✔\nMethod: %s\nURL: %s\nStatus: %d\nTime: %.1f ms\nResponse:\n%s\n──────────────────────────────────────────" % [TAG, method, url, status, ms, response])


static func log_error(method: String, url: String, status: int, response: String, error: String, ms: float) -> void:
	push_error("%s RESPONSE ERROR ✖\nMethod: %s\nURL: %s\nStatus: %d\nTime: %.1f ms\nError: %s\nResponse:\n%s\n──────────────────────────────────────────" % [TAG, method, url, status, ms, error, response])