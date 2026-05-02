extends Node

# 用户信息
var user_nickname: String = ""
var user_avatar_url: String = ""
var user_avatar_texture: ImageTexture = null
var user_email: String = ""

signal user_info_updated

func set_user_info(nickname: String, avatar_url: String, email: String) -> void:
	user_nickname = nickname
	user_avatar_url = avatar_url
	user_email = email
	
	if avatar_url != "":
		_load_avatar(avatar_url)
	else:
		user_info_updated.emit()

func _load_avatar(url: String) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		user_info_updated.emit()
		return
	
	var result: Array = await http.request_completed
	var result_code: int = result[1]
	var body: PackedByteArray = result[3]
	
	if result_code == 200 and body.size() > 0:
		var image := Image.new()
		var ext: String = url.get_extension().to_lower()
		var load_err: int
		
		if ext == "png":
			load_err = image.load_png_from_buffer(body)
		elif ext == "jpg" or ext == "jpeg":
			load_err = image.load_jpg_from_buffer(body)
		elif ext == "webp":
			load_err = image.load_webp_from_buffer(body)
		else:
			load_err = image.load_jpg_from_buffer(body)
		
		if load_err == OK:
			image.resize(64, 64)
			user_avatar_texture = ImageTexture.create_from_image(image)
	
	http.queue_free()
	user_info_updated.emit()

func get_display_name() -> String:
	if user_nickname != "":
		return user_nickname
	elif user_email != "":
		return user_email
	else:
		return "Player"

func get_avatar_texture() -> ImageTexture:
	return user_avatar_texture

func has_avatar() -> bool:
	return user_avatar_texture != null

func clear() -> void:
	user_nickname = ""
	user_avatar_url = ""
	user_avatar_texture = null
	user_email = ""
	user_info_updated.emit()
