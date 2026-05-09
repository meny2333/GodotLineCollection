@tool
class_name AnimationEventData
extends Resource

## Stores event keyframe data for an animation track.

class EventKey:
	var time = 0.0
	var event_name = ""
	var args = {}

	func _init(p_time = 0.0, p_name = "", p_args = {}):
		time = p_time
		event_name = p_name
		args = p_args

	func to_dict():
		return {
			"time": time,
			"event_name": event_name,
			"args": args,
		}

	static func from_dict(d):
		var key = EventKey.new()
		key.time = d.get("time", 0.0)
		key.event_name = d.get("event_name", "")
		key.args = d.get("args", {})
		return key


@export var track_name = ""
@export var events = []


func add_event(p_time, p_event_name, p_args = {}):
	var key = EventKey.new(p_time, p_event_name, p_args)
	var idx = events.size()
	events.append(key.to_dict())
	sort_events()
	return idx


func remove_event(p_index):
	if p_index < 0 or p_index >= events.size():
		return false
	events.remove_at(p_index)
	return true


func set_event(p_index, p_time, p_event_name, p_args = {}):
	if p_index < 0 or p_index >= events.size():
		return
	var key = EventKey.new(p_time, p_event_name, p_args)
	events[p_index] = key.to_dict()
	sort_events()


func sort_events():
	events.sort_custom(_compare_by_time)


func get_event_keys():
	var result = []
	var d
	var i = 0
	while i < events.size():
		d = events[i]
		result.append(EventKey.from_dict(d))
		i += 1
	return result


func get_events_in_range(p_from, p_to):
	var result = []
	var d
	var t
	var i = 0
	while i < events.size():
		d = events[i]
		t = d.get("time", 0.0)
		if t >= p_from and t <= p_to:
			result.append(EventKey.from_dict(d))
		i += 1
	return result


func get_events_at_time(p_time, p_epsilon = 0.001):
	return get_events_in_range(p_time - p_epsilon, p_time + p_epsilon)


func clear():
	events.clear()


func get_event_count():
	return events.size()


func get_event_at(p_index):
	if p_index < 0 or p_index >= events.size():
		return EventKey.new()
	return EventKey.from_dict(events[p_index])


static func _compare_by_time(a, b):
	return a.get("time", 0.0) < b.get("time", 0.0)
