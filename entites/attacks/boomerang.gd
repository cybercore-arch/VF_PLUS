extends RefCounted

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var spawn_pos: Vector2 = PatternUtil.get_pos(arena, params)

	var delay: float = params.get("delay", 0.6)
	var speed_out: float = params.get("speed_out", 340.0)
	var speed_in: float = params.get("speed_in", 420.0)
	var distance: float = params.get("distance", 320.0)
	var count: int = maxi(int(params.get("count", 1)), 1)
	var spread_deg: float = params.get("spread", 0.0)
	var return_threshold: float = params.get("return_threshold", 8.0)
	var max_lifetime: float = params.get("max_lifetime", 8.0)
	var dot_color: Color = PatternUtil.to_color(params.get("dot_color"), Color(0.4, 0.9, 1.0, 0.7))

	var dot: Sprite2D = PatternUtil.spawn_dot(arena, spawn_pos, dot_color)
	await PatternUtil.wait(arena, delay)
	PatternUtil.free_node(dot)

	if not PatternUtil.arena_alive(arena):
		return

	var target_pos: Vector2 = PatternUtil.resolve_point(params.get("target", "player"), arena, spawn_pos + Vector2.DOWN * 200.0)
	if params.has("target_x") or params.has("target_y"):
		target_pos = Vector2(params.get("target_x", target_pos.x), params.get("target_y", target_pos.y))

	var base_dir: Vector2 = (target_pos - spawn_pos).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.DOWN

	var spread_rad: float = deg_to_rad(spread_deg)
	var bullets: Array = []

	for i in range(count):
		var dir: Vector2 = base_dir
		if count > 1 and spread_rad > 0.0:
			var t: float = float(i) / float(count - 1) - 0.5
			dir = base_dir.rotated(t * spread_rad)

		var bullet = PatternUtil.spawn_bullet(arena, spawn_pos, dir, speed_out)
		bullet.set_meta("boomerang_state", "out")
		bullets.append(bullet)

	# На обратном пути пуля за кадр проходит speed_in * dt пикселей. Если порог меньше шага,
	# она может перелететь точку возврата, поэтому порог не меньше длины шага.
	var step_len: float = speed_in * arena.get_physics_process_delta_time()
	var catch_radius: float = maxf(return_threshold, step_len)

	var elapsed: float = 0.0
	while elapsed < max_lifetime:
		var alive_count: int = 0
		for bullet in bullets:
			if not is_instance_valid(bullet):
				continue
			alive_count += 1

			var dist: float = bullet.global_position.distance_to(spawn_pos)
			var state: String = bullet.get_meta("boomerang_state", "out")

			if state == "out":
				if dist >= distance:
					bullet.set_meta("boomerang_state", "back")
					bullet.direction = (spawn_pos - bullet.global_position).normalized()
					bullet.speed = speed_in
			elif dist <= catch_radius:
				bullet.queue_free()

		if alive_count == 0:
			break

		elapsed += await PatternUtil.next_frame(arena)
		if not PatternUtil.arena_alive(arena):
			return
