extends RefCounted

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var spawn_pos: Vector2 = PatternUtil.get_pos(arena, params)

	var delay: float = params.get("delay", 0.6)
	var dot_scale_min: float = params.get("dot_scale_min", 0.3)
	var dot_scale_max: float = params.get("dot_scale_max", 0.6)
	var dot_color: Color = PatternUtil.to_color(params.get("dot_color"), Color(1, 1, 1, 0.7))
	var count: int = maxi(int(params.get("count", 12)), 1)
	var speed: float = params.get("speed", 250.0)

	var dot: Sprite2D = PatternUtil.spawn_dot(arena, spawn_pos, dot_color, dot_scale_min, dot_scale_max)
	await PatternUtil.wait(arena, delay)
	PatternUtil.free_node(dot)

	if not PatternUtil.arena_alive(arena):
		return

	var angle_step: float = TAU / float(count)
	for i in range(count):
		var dir: Vector2 = Vector2.from_angle(float(i) * angle_step)
		PatternUtil.spawn_bullet(arena, spawn_pos, dir, speed)
