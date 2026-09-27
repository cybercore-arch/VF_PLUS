extends Node

class_name PatternManager

@export var arena: Node2D

var current_time: float = 0.0
var is_playing: bool = false
var timeline: Array = []
var next_event_index: int = 0

func load_level(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Файл не найден: " + path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var data = JSON.parse_string(content)
	if data and data.has("events"):
		timeline = data["events"]
		current_time = 0.0
		next_event_index = 0
		is_playing = true
		print("level loaded:", timeline.size())

func _trigger_event(event_data: Dictionary) -> void:
	var pattern_name = event_data.get("pattern", "")
	var params = event_data.get("params", {})
	var external_path = OS.get_executable_path().get_base_dir() + "/patterns/" + pattern_name + ".gd"
	var pattern_script: GDScript = null

	if params.has("pos"):
		params["pos"] = resolve_param(params["pos"], arena)

	for key in params.keys():
		params[key] = _maybe_color(params[key])

	if FileAccess.file_exists(external_path):
		pattern_script = load(external_path)
	else:
		var internal_path = "res://entites/attacks/" + pattern_name + ".gd"
		if ResourceLoader.exists(internal_path):
			pattern_script = load(internal_path)

	if pattern_script:
		var pattern_instance = pattern_script.new()
		pattern_instance.execute(arena, params)
	else:
		push_error("not found: " + pattern_name)

func _maybe_color(val):
	if val is Array:
		if val.size() == 3 or val.size() == 4:
			var all_num: bool = true
			for v in val:
				if not (v is float or v is int):
					all_num = false
					break
			if all_num:
				if val.size() == 3:
					return Color(float(val[0]), float(val[1]), float(val[2]), 1.0)
				return Color(float(val[0]), float(val[1]), float(val[2]), float(val[3]))
	return val

func _process(delta: float) -> void:
	if not is_playing:
		return
	current_time += delta
	while next_event_index < timeline.size() and current_time >= timeline[next_event_index]["time"]:
		var event_data = timeline[next_event_index]
		_trigger_event(event_data)
		next_event_index += 1
	if next_event_index >= timeline.size():
		is_playing = false
		print("end")

func resolve_param(val, arena_node: Node2D, default_val = null):
	if val is String:
		match val.to_lower():
			"center":
				var vp_size = arena_node.get_viewport_rect().size
				return vp_size / 2.0
			"random":
				var vp_size = arena_node.get_viewport_rect().size
				return Vector2(randf_range(50, vp_size.x - 50), randf_range(50, vp_size.y - 50))
			"player", "aimed":
				var player = arena_node.get_node_or_null("player")
				if player:
					return player.global_position
				return arena_node.get_viewport_rect().size / 2.0
	elif val is Array:
		if val.size() == 2:
			if (val[0] is float or val[0] is int) and (val[1] is float or val[1] is int):
				return Vector2(val[0], val[1])
	elif val != null:
		return val
	return default_val

func get_aim_direction(from_pos: Vector2, arena_node: Node2D) -> Vector2:
	var player = arena_node.get_node_or_null("player")
	if player:
		return (player.global_position - from_pos).normalized()
	return Vector2.DOWN
