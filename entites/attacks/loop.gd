extends Node

func _arena_alive(a) -> bool:
	return is_instance_valid(a) and a is Node2D and a.is_inside_tree()

func _resolve_point(val, arena_node: Node2D) -> Vector2:
	if val is Vector2:
		return val
	if val is String:
		match val.to_lower():
			"center":
				return arena_node.get_viewport_rect().size / 2.0
			"random":
				var vp = arena_node.get_viewport_rect().size
				return Vector2(randf_range(50, vp.x - 50), randf_range(50, vp.y - 50))
			"player", "aimed":
				var p = arena_node.get_node_or_null("player")
				if p and is_instance_valid(p):
					return p.global_position
				return arena_node.get_viewport_rect().size / 2.0
	elif val is Array and val.size() == 2:
		if (val[0] is float or val[0] is int) and (val[1] is float or val[1] is int):
			return Vector2(float(val[0]), float(val[1]))
	return arena_node.get_viewport_rect().size / 2.0

func execute(arena: Node2D, params: Dictionary) -> void:
	if not _arena_alive(arena): return
	var tree: SceneTree = arena.get_tree()

	var target_pattern_name: String = params.get("target_pattern", "")
	if target_pattern_name.is_empty():
		return

	var repeat_count: int = params.get("repeat", 3)
	var is_infinite: bool = (repeat_count <= 0)
	var interval: float = params.get("interval", 0.2)
	var target_params: Dictionary = params.get("params", {}).duplicate(true)
	var angle_step: float = params.get("step_angle", 0.0)
	var speed_step: float = params.get("step_speed", 0.0)

	if target_params.has("pos"):
		target_params["pos"] = _resolve_point(target_params["pos"], arena)
	if target_params.has("target"):
		target_params["target"] = _resolve_point(target_params["target"], arena)

	var external_path = OS.get_executable_path().get_base_dir() + "/patterns/" + target_pattern_name + ".gd"
	var pattern_script: GDScript = null
	if FileAccess.file_exists(external_path):
		pattern_script = load(external_path)
	else:
		var internal_path = "res://entites/attacks/" + target_pattern_name + ".gd"
		if ResourceLoader.exists(internal_path):
			pattern_script = load(internal_path)

	if not pattern_script:
		return

	var step: int = 0
	while is_infinite or step < repeat_count:
		if not _arena_alive(arena): return

		var current_params = target_params.duplicate(true)

		if angle_step != 0.0:
			var base_angle = current_params.get("start_angle", 0.0)
			current_params["start_angle"] = base_angle + (angle_step * step)

		if speed_step != 0.0:
			var base_speed = current_params.get("speed", 250.0)
			current_params["speed"] = base_speed + (speed_step * step)

		var inst = pattern_script.new()
		inst.execute(arena, current_params)

		step += 1
		if interval > 0.0:
			await tree.create_timer(interval).timeout
