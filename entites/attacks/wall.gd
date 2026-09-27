extends Node

const BULLET_SCENE = preload("res://entites/bullet/bullet.tscn")

func _arena_alive(a) -> bool:
	return is_instance_valid(a) and a is Node2D and a.is_inside_tree()

func _get_side_geometry(side: String, viewport_size: Vector2) -> Dictionary:
	match side:
		"bottom":
			return { "length": viewport_size.x, "fixed": viewport_size.y, "dir": Vector2.UP, "horizontal": true }
		"left":
			return { "length": viewport_size.y, "fixed": 0.0, "dir": Vector2.RIGHT, "horizontal": false }
		"right":
			return { "length": viewport_size.y, "fixed": viewport_size.x, "dir": Vector2.LEFT, "horizontal": false }
	return { "length": viewport_size.x, "fixed": 0.0, "dir": Vector2.DOWN, "horizontal": true }

func _wall_spawn_position(t: float, geo: Dictionary, inset: float) -> Vector2:
	if geo["horizontal"]:
		var y: float
		if geo["dir"] == Vector2.DOWN:
			y = geo["fixed"] + inset
		else:
			y = geo["fixed"] - inset
		return Vector2(t, y)
	var x: float
	if geo["dir"] == Vector2.RIGHT:
		x = geo["fixed"] + inset
	else:
		x = geo["fixed"] - inset
	return Vector2(x, t)

func _make_telegraph_line(arena: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.add_point(a)
	line.add_point(b)
	line.width = width
	line.default_color = color
	arena.add_child(line)
	return line

func execute(arena: Node2D, params: Dictionary) -> void:
	if not _arena_alive(arena):
		return

	var tree: SceneTree = arena.get_tree()

	var viewport_size: Vector2 = arena.get_viewport_rect().size
	var side: String = params.get("side", "top")
	var geo: Dictionary = _get_side_geometry(side, viewport_size)
	var wall_length: float = geo["length"]
	var wall_dir: Vector2 = geo["dir"]
	var horizontal: bool = geo["horizontal"]
	var fixed_coord: float = geo["fixed"]

	var delay: float = params.get("delay", 0.7)
	var spacing: float = params.get("spacing", 40.0)
	var gap_size: float = minf(params.get("gap_size", 140.0), wall_length * 0.9)
	var gap_pos_param = params.get("gap_pos", 0.5)
	var gap_random: bool = params.get("gap_random", false)
	var gap_slide: float = params.get("gap_slide", 0.0)
	var speed: float = params.get("speed", 200.0)
	var waves: int = params.get("waves", 1)
	var wave_interval: float = params.get("wave_interval", 1.0)
	var spawn_inset: float = params.get("spawn_offset", 1.0)
	var telegraph_color: Color = params.get("telegraph_color", Color(1.0, 0.3, 0.3, 0.6))
	var telegraph_width: float = params.get("telegraph_width", 6.0)

	var gap_half: float = gap_size * 0.5
	var current_gap_center: float = wall_length * 0.5
	if gap_pos_param is String and gap_pos_param.to_lower() == "random":
		current_gap_center = randf_range(gap_half, wall_length - gap_half)
	elif gap_pos_param is float or gap_pos_param is int:
		current_gap_center = float(gap_pos_param) * wall_length

	for wave in range(waves):
		if not _arena_alive(arena):
			return

		if wave > 0:
			if gap_random:
				current_gap_center = randf_range(gap_half, wall_length - gap_half)
			else:
				current_gap_center += gap_slide
			current_gap_center = clampf(current_gap_center, gap_half, wall_length - gap_half)

		var gap_start: float = current_gap_center - gap_half
		var gap_end: float = current_gap_center + gap_half

		var edge_a: Vector2
		var edge_b: Vector2
		var gap_a: Vector2
		var gap_b: Vector2
		if horizontal:
			edge_a = Vector2(0.0, fixed_coord)
			edge_b = Vector2(wall_length, fixed_coord)
			gap_a = Vector2(gap_start, fixed_coord)
			gap_b = Vector2(gap_end, fixed_coord)
		else:
			edge_a = Vector2(fixed_coord, 0.0)
			edge_b = Vector2(fixed_coord, wall_length)
			gap_a = Vector2(fixed_coord, gap_start)
			gap_b = Vector2(fixed_coord, gap_end)

		var lines: Array[Line2D] = []
		if gap_start > 0.0:
			lines.append(_make_telegraph_line(arena, edge_a, gap_a, telegraph_color, telegraph_width))
		if gap_end < wall_length:
			lines.append(_make_telegraph_line(arena, gap_b, edge_b, telegraph_color, telegraph_width))

		await tree.create_timer(delay).timeout

		for line in lines:
			if is_instance_valid(line):
				line.queue_free()

		if not _arena_alive(arena):
			return

		var t: float = 0.0
		while t <= wall_length:
			if not _arena_alive(arena):
				return
			if t < gap_start or t > gap_end:
				var pos: Vector2 = _wall_spawn_position(t, geo, spawn_inset)
				var bullet = BULLET_SCENE.instantiate()
				bullet.global_position = pos
				bullet.direction = wall_dir
				bullet.speed = speed
				arena.bullet_container.add_child(bullet)
			t += spacing

		if wave < waves - 1:
			await tree.create_timer(wave_interval).timeout
