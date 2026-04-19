extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in range(10):
		_add_bubble(true)
	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_add_bubble.bind(false))
	add_child(timer)


func _add_bubble(random_y: bool) -> void:
	var vp := get_viewport().get_visible_rect()
	var s := randf_range(4.0, 22.0)
	var bubble := ColorRect.new()
	bubble.color = Color(0.4, 0.55, 0.9, randf_range(0.02, 0.08))
	bubble.size = Vector2(s, s)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start_y := randf_range(0, vp.size.y) if random_y else (vp.size.y + s)
	var start_x := randf_range(0, vp.size.x)
	bubble.position = Vector2(start_x, start_y)
	add_child(bubble)
	var duration := randf_range(8.0, 16.0)
	var drift := randf_range(-50.0, 50.0)
	var tween := create_tween()
	if random_y:
		var frac := 1.0 - (start_y / vp.size.y)
		var adj := duration * frac
		tween.tween_property(bubble, "position:y", -s, adj)
		tween.parallel().tween_property(bubble, "position:x", start_x + drift * frac, adj)
		tween.tween_callback(bubble.queue_free)
	else:
		tween.tween_property(bubble, "position:y", -s - 20.0, duration)
		tween.parallel().tween_property(bubble, "position:x", start_x + drift, duration)
		tween.tween_callback(bubble.queue_free)
