extends RefCounted

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var spawn_pos: Vector2 = PatternUtil.get_pos(arena, params)

	var delay: float = params.get("delay", 0.5)
	var speed: float = params.get("speed", 300.0)
	var dot_scale_min: float = params.get("dot_scale_min", 0.3)
	var dot_scale_max: float = params.get("dot_scale_max", 0.6)
	var dot_color: Color = PatternUtil.to_color(params.get("dot_color"), Color(1, 1, 1, 0.7))

	var dot: Sprite2D = PatternUtil.spawn_dot(arena, spawn_pos, dot_color, dot_scale_min, dot_scale_max)
	await PatternUtil.wait(arena, delay)
	PatternUtil.free_node(dot)

	if not PatternUtil.arena_alive(arena):
		return

	var target_pos: Vector2 = PatternUtil.resolve_point(params.get("target", "player"), arena, spawn_pos + Vector2.DOWN * 100.0)
	if params.has("target_x") or params.has("target_y"):
		target_pos = Vector2(params.get("target_x", target_pos.x), params.get("target_y", target_pos.y))

	var dir: Vector2 = (target_pos - spawn_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	PatternUtil.spawn_bullet(arena, spawn_pos, dir, speed)
