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

	var pool: Array[String] = []

	var internal_dir = DirAccess.open("res://entites/attacks/")
	if internal_dir:
		internal_dir.list_dir_begin()
		var file_name = internal_dir.get_next()
		while file_name != "":
			if not internal_dir.current_is_dir() and file_name.ends_with(".gd"):
				var base = file_name.get_basename()
				if base != "random" and base != "loop":
					pool.append(base)
			file_name = internal_dir.get_next()

	var external_folder = OS.get_executable_path().get_base_dir().path_join("patterns")
	var ext_dir = DirAccess.open(external_folder)
	if ext_dir:
		ext_dir.list_dir_begin()
		var ext_file = ext_dir.get_next()
		while ext_file != "":
			if not ext_dir.current_is_dir() and ext_file.ends_with(".gd"):
				var base = ext_file.get_basename()
				if base != "random" and base != "loop" and not pool.has(base):
					pool.append(base)
			ext_file = ext_dir.get_next()

	if pool.is_empty():
		return

	var chosen_pattern: String = ""
	if params.has("pool") and params["pool"] is Array and not params["pool"].is_empty():
		chosen_pattern = params["pool"].pick_random()
	else:
		chosen_pattern = pool.pick_random()

	var auto_params: Dictionary = {}
	var pos_types = ["center", "random", "player"]
	auto_params["pos"] = pos_types.pick_random()
	auto_params["delay"] = randf_range(0.3, 0.6)
	auto_params["speed"] = randf_range(180.0, 350.0)
	auto_params["count"] = randi_range(8, 18)

	match chosen_pattern:
		"shot", "boomerang":
			auto_params["target"] = "player"
		"wall":
			var sides = ["top", "bottom", "left", "right"]
			auto_params["side"] = sides.pick_random()
			auto_params["gap_random"] = true
			auto_params["waves"] = randi_range(1, 2)
		"spiral":
			auto_params["arms"] = randi_range(2, 4)
			auto_params["duration"] = randf_range(1.5, 2.5)
		"sakura":
			auto_params["side"] = ["top", "left", "right"].pick_random()
			auto_params["count"] = randi_range(15, 25)

	for k in params.keys():
		if k != "pool":
			auto_params[k] = params[k]

	if auto_params.has("pos"):
		auto_params["pos"] = _resolve_point(auto_params["pos"], arena)
	if auto_params.has("target"):
		auto_params["target"] = _resolve_point(auto_params["target"], arena)

	var external_path = external_folder.path_join(chosen_pattern + ".gd")
	var pattern_script: GDScript = null
	if FileAccess.file_exists(external_path):
		pattern_script = load(external_path)
	else:
		var internal_path = "res://entites/attacks/" + chosen_pattern + ".gd"
		if ResourceLoader.exists(internal_path):
			pattern_script = load(internal_path)

	if pattern_script:
		var inst = pattern_script.new()
		inst.execute(arena, auto_params)
