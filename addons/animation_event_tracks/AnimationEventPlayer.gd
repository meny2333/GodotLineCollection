@tool
class_name AnimationEventPlayer
extends Node

signal event_fired(event_name, args)
signal lerp_updated(pos)

@export var target_node: NodePath


var _player
var _lerp_cache = {}
var _target
var _frame = 0
var _logged_playing = false
var _logged_keys = false
var _logged_target = false
var _last_target_node


func _ready():
	_frame = 0
	_logged_playing = false
	_logged_keys = false
	_logged_target = false
	_player = _find_player(get_parent())
	_resolve_target()
	_last_target_node = target_node
	print("[AEP] _ready  player=", _player, " target=", _target)


func _process(_delta):
	_frame += 1

	# Detect target_node changes
	if target_node != _last_target_node:
		_resolve_target()
		_last_target_node = target_node

	if not _player:
		_player = _find_player(get_parent())
		if _frame % 120 == 1:
			print("[AEP] looking for player... found=", _player)

	if not _player:
		return

	if not _player.is_playing():
		if _logged_playing:
			print("[AEP] stopped playing")
			_logged_playing = false
			_logged_keys = false
		return

	if not _logged_playing:
		print("[AEP] playing anim=", _player.current_animation)
		_logged_playing = true
		_build_lerp_cache()  # rebuild every time playback starts

	var anim = _player.current_animation
	var t = _player.current_animation_position

	var keys = _lerp_cache.get(anim)
	if keys == null:
		_build_lerp_cache()
		keys = _lerp_cache.get(anim, [])

	if keys.size() < 2:
		if not _logged_keys:
			print("[AEP] no keys for '", anim, "'  cache=", _lerp_cache.keys())
			_logged_keys = true
		return

	if not _logged_keys:
		print("[AEP] lerp keys for '", anim, "':")
		var ki = 0
		while ki < keys.size():
			print("  ", keys[ki].time, " -> ", keys[ki].pos)
			ki += 1
		_logged_keys = true

	var prev = keys[0]
	var next = keys[keys.size() - 1]
	var i = 0
	while i < keys.size():
		if keys[i].time <= t:
			prev = keys[i]
		if keys[i].time > t:
			next = keys[i]
			break
		i += 1

	var result
	if prev == next:
		result = prev.pos
	else:
		var progress = (t - prev.time) / (next.time - prev.time)
		progress = clampf(progress, 0.0, 1.0)
		result = prev.pos.lerp(next.pos, progress)

	lerp_updated.emit(result)

	if _target:
		if _target.has_method("set_position"):
			_target.position = result
		elif _target is Node3D:
			_target.position = result
		if _frame % 60 == 1:
			print("[AEP] t=", t, " result=", result)
	elif not _logged_target:
		print("[AEP] no target_node set")
		_logged_target = true


func event(event_name = "", args_json = ""):
	var args = {}
	var j
	var d
	if not args_json.is_empty():
		j = JSON.new()
		if j.parse(args_json) == OK:
			d = j.get_data()
			if d is Dictionary:
				args = d
	event_fired.emit(event_name, args)


func lerp_pos(x = 0.0, y = 0.0, z = 0.0):
	pass


func _resolve_target():
	_target = null
	_logged_target = false
	if target_node.is_empty():
		return
	_target = get_node_or_null(target_node)
	print("[AEP] _resolve_target  path=", target_node, " -> ", _target)


func _build_lerp_cache():
	print("[AEP] _build_lerp_cache start")
	_lerp_cache.clear()
	if not _player:
		print("[AEP] _build_lerp_cache no _player")
		return

	var my_path = _player.get_path_to(self)
	print("[AEP] my_path=", my_path, " name=", name)
	var anim_list = _player.get_animation_list()
	print("[AEP] animations: ", anim_list)
	var anim_name
	var anim
	var keys
	var ti
	var ki
	var path
	var parts
	var target
	var val
	var method
	var args_arr
	var pos
	var key_time
	var n
	var swapped
	var si
	var tmp

	var ai = 0
	while ai < anim_list.size():
		anim_name = anim_list[ai]
		anim = _player.get_animation(anim_name)
		keys = []
		print("[AEP] scanning anim '", anim_name, "'  tracks=", anim.get_track_count())

		ti = 0
		while ti < anim.get_track_count():
			if anim.track_get_type(ti) == Animation.TYPE_METHOD:
				path = anim.track_get_path(ti)
				parts = str(path).split(":")
				if parts.size() > 0:
					target = parts[parts.size() - 1]
				else:
					target = ""
				print("[AEP]   track ", ti, " method path=", path, " target=", target, " keys=", anim.track_get_key_count(ti))

				ki = 0
				while ki < anim.track_get_key_count(ti):
					val = anim.track_get_key_value(ti, ki)
					method = val.get("method", "")
					if method == "lerp_pos":
						if target == name or target == str(my_path):
							args_arr = val.get("args", [])
							pos = Vector3.ZERO
							if args_arr.size() >= 3:
								pos = Vector3(float(args_arr[0]), float(args_arr[1]), float(args_arr[2]))
							key_time = anim.track_get_key_time(ti, ki)
							keys.append({"time": key_time, "pos": pos})
							print("[AEP]     key t=", key_time, " pos=", pos)
					ki += 1
			ti += 1

		n = keys.size()
		swapped = true
		while swapped:
			swapped = false
			si = 0
			while si < n - 1:
				if keys[si].time > keys[si + 1].time:
					tmp = keys[si]
					keys[si] = keys[si + 1]
					keys[si + 1] = tmp
					swapped = true
				si += 1

		_lerp_cache[anim_name] = keys
		print("[AEP] cached ", keys.size(), " lerp keys for '", anim_name, "'")
		ai += 1

	print("[AEP] _build_lerp_cache done. cache keys=", _lerp_cache.keys())


func _find_player(node):
	if not node:
		return null
	if node is AnimationPlayer:
		return node
	var children = node.get_children()
	var i = 0
	var c
	var r
	while i < children.size():
		c = children[i]
		r = _find_player(c)
		if r:
			return r
		i += 1
	return null
