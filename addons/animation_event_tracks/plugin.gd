@tool
extends EditorPlugin

var _event_btn
var _lerp_btn


func _enter_tree():
	_event_btn = Button.new()
	_event_btn.text = "Event"
	_event_btn.tooltip_text = "Add event track to current animation"
	_event_btn.pressed.connect(_add_event_track)
	add_control_to_container(CONTAINER_TOOLBAR, _event_btn)

	_lerp_btn = Button.new()
	_lerp_btn.text = "Lerp"
	_lerp_btn.tooltip_text = "Add lerp track to current animation"
	_lerp_btn.pressed.connect(_add_lerp_track)
	add_control_to_container(CONTAINER_TOOLBAR, _lerp_btn)


func _exit_tree():
	if _event_btn:
		remove_control_from_container(CONTAINER_TOOLBAR, _event_btn)
		_event_btn.queue_free()
	if _lerp_btn:
		remove_control_from_container(CONTAINER_TOOLBAR, _lerp_btn)
		_lerp_btn.queue_free()


func _get_player():
	var ei = get_editor_interface()
	var sel = ei.get_selection().get_selected_nodes()
	for n in sel:
		if n is AnimationPlayer:
			return n
	return _find_player(ei.get_edited_scene_root())


func _get_edited_anim_name(player):
	# Read the animation currently open in the animation editor panel.
	# The animation editor has a dropdown (OptionButton) showing the anim name.
	var base = get_editor_interface().get_base_control()
	var dropdown = _find_anim_dropdown(base)
	var name = ""
	if dropdown:
		name = dropdown.text

	# Verify this name belongs to the player
	var list = player.get_animation_list()
	var i = 0
	while i < list.size():
		if list[i] == name:
			return name
		i += 1

	# Fallback: first non-RESET animation
	i = 0
	while i < list.size():
		if list[i] != "RESET":
			return list[i]
		i += 1
	return ""


func _get_anim(player):
	if not player:
		return null
	var name = _get_edited_anim_name(player)
	if name.is_empty():
		return null
	return player.get_animation(name)


func _ensure_ev_player(player):
	for c in player.get_children():
		if c is AnimationEventPlayer:
			return c
	var ep = AnimationEventPlayer.new()
	ep.name = "AnimationEventPlayer"
	player.add_child(ep)
	ep.owner = player.owner
	return ep


func _add_event_track():
	var player = _get_player()
	if not player:
		print("[Event] No AnimationPlayer selected.")
		return

	var anim = _get_anim(player)
	if not anim:
		print("[Event] No animation open in editor.")
		return

	var ep = _ensure_ev_player(player)
	var ti = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(ti, player.get_path_to(ep))
	anim.track_set_enabled(ti, true)

	var key = {"method": "event", "args": ["my_event", "{}"]}
	anim.track_insert_key(ti, 0.0, key)

	get_editor_interface().mark_scene_as_unsaved()
	print("[Event] Track added.")


func _add_lerp_track():
	var player = _get_player()
	if not player:
		print("[Lerp] No AnimationPlayer found.")
		return

	var anim = _get_anim(player)
	if not anim:
		print("[Lerp] No animation open in editor.")
		return

	var ep = _ensure_ev_player(player)
	var ti = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(ti, player.get_path_to(ep))
	anim.track_set_enabled(ti, true)

	# Detect selected target node
	var target = _get_selected_target(player)
	var start_pos = Vector3.ZERO
	var end_pos = Vector3(10, 0, 0)

	if target:
		ep.target_node = player.get_path_to(target)
		if target is Node3D:
			start_pos = target.position
			end_pos = start_pos + Vector3(10, 0, 0)
		elif target.has_method("get_position"):
			start_pos = target.position
			end_pos = start_pos + Vector3(10, 0, 0)

	anim.track_insert_key(ti, 0.0, {"method": "lerp_pos", "args": [start_pos.x, start_pos.y, start_pos.z]})
	anim.track_insert_key(ti, 1.0, {"method": "lerp_pos", "args": [end_pos.x, end_pos.y, end_pos.z]})

	get_editor_interface().mark_scene_as_unsaved()
	print("[Lerp] Track added.")


func _get_selected_target(player):
	var sel = get_editor_interface().get_selection().get_selected_nodes()
	for n in sel:
		if not n is AnimationPlayer and (n is Node3D or n.has_method("set_position")):
			return n
	return null


func _find_anim_dropdown(node):
	# Search for the OptionButton inside the animation editor panel.
	if not node:
		return null
	var cn = str(node.get_class())
	if cn == "OptionButton":
		var p = node.get_parent()
		if p:
			var pn = p.name.to_lower()
			if "animation" in pn or "anim" in pn:
				return node
	var child
	var result
	var children = node.get_children()
	var i = 0
	while i < children.size():
		child = children[i]
		result = _find_anim_dropdown(child)
		if result:
			return result
		i += 1
	return null


func _find_player(node):
	if not node:
		return null
	if node is AnimationPlayer:
		return node
	var children = node.get_children()
	var i = 0
	var r
	while i < children.size():
		r = _find_player(children[i])
		if r:
			return r
		i += 1
	return null
