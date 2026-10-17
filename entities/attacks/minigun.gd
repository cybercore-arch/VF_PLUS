extends RefCounted

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var spawn_pos: Vector2 = PatternUtil.get_pos(arena, params)

	var delay: float = params.get("delay", 0.5)
	var follow_time: float = params.get("follow_time", 1.0)
	var lock_time: float = params.get("lock_time", 0.7)
	var shots: int = int(params.get("shots", 12))
	var shot_interval: float = params.get("shot_interval", 0.06)
	var speed: float = params.get("speed", 420.0)
	var spread_deg: float = params.get("spread", 2.0)
	var follow_player: bool = params.get("follow_player", true)
	var crosshair_size: float = params.get("crosshair_size", 26.0)
	var crosshair_color: Color = PatternUtil.to_color(params.get("crosshair_color"), Color(1.0, 0.9, 0.3, 1.0))
	var lock_color: Color = PatternUtil.to_color(params.get("lock_color"), Color(1.0, 0.2, 0.2, 1.0))
	var show_target_line: bool = params.get("show_target_line", true)
	var dot_color: Color = PatternUtil.to_color(params.get("dot_color"), Color(1.0, 0.9, 0.3, 0.7))

	var dot: Sprite2D = PatternUtil.spawn_dot(arena, spawn_pos, dot_color)
	await PatternUtil.wait(arena, delay)
	PatternUtil.free_node(dot)

	if not PatternUtil.arena_alive(arena):
		return

	var initial_target: Vector2 = spawn_pos + Vector2.RIGHT * 200.0
	var player: Node2D = PatternUtil.get_player(arena)
	if player != null:
		initial_target = player.global_position

	var ch_h: Line2D = PatternUtil.make_line(arena, Vector2(-crosshair_size, 0.0), Vector2(crosshair_size, 0.0), crosshair_color, 3.0)
	ch_h.z_index = 10
	ch_h.global_position = initial_target

	var ch_v: Line2D = PatternUtil.make_line(arena, Vector2(0.0, -crosshair_size), Vector2(0.0, crosshair_size), crosshair_color, 3.0)
	ch_v.z_index = 10
	ch_v.global_position = initial_target

	var target_line: Line2D = null
	if show_target_line:
		target_line = PatternUtil.make_line(arena, spawn_pos, initial_target, Color(crosshair_color.r, crosshair_color.g, crosshair_color.b, 0.35), 1.5)
		target_line.z_index = 9

	var follow_elapsed: float = 0.0
	while follow_elapsed < follow_time:
		if follow_player:
			player = PatternUtil.get_player(arena)
			if player != null:
				var pos: Vector2 = player.global_position
				ch_h.global_position = pos
				ch_v.global_position = pos
				if target_line:
					target_line.set_point_position(1, pos)
		follow_elapsed += await PatternUtil.next_frame(arena)
		if not PatternUtil.arena_alive(arena):
			return

	var lock_pos: Vector2 = ch_h.global_position
	player = PatternUtil.get_player(arena)
	if player != null:
		lock_pos = player.global_position
		ch_h.global_position = lock_pos
		ch_v.global_position = lock_pos
		if target_line:
			target_line.set_point_position(1, lock_pos)

	ch_h.default_color = lock_color
	ch_v.default_color = lock_color
	if target_line:
		target_line.default_color = Color(lock_color.r, lock_color.g, lock_color.b, 0.5)

	var pulse: Tween = ch_h.create_tween()
	pulse.set_loops()
	pulse.tween_property(ch_h, "modulate:a", 0.4, 0.1)
	pulse.parallel().tween_property(ch_v, "modulate:a", 0.4, 0.1)
	pulse.tween_property(ch_h, "modulate:a", 1.0, 0.1)
	pulse.parallel().tween_property(ch_v, "modulate:a", 1.0, 0.1)

	await PatternUtil.wait(arena, lock_time)

	pulse.kill()

	if not PatternUtil.arena_alive(arena):
		return

	var base_dir: Vector2 = (lock_pos - spawn_pos).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.DOWN

	var spread_rad: float = deg_to_rad(spread_deg)

	for i in range(shots):
		var dir: Vector2 = base_dir
		if spread_rad > 0.0:
			dir = base_dir.rotated(randf_range(-spread_rad, spread_rad))

		PatternUtil.spawn_bullet(arena, spawn_pos, dir, speed)

		await PatternUtil.wait(arena, shot_interval)
		if not PatternUtil.arena_alive(arena):
			return

	PatternUtil.free_node(ch_h)
	PatternUtil.free_node(ch_v)
	PatternUtil.free_node(target_line)
