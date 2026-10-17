extends RefCounted

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var spawn_pos: Vector2 = PatternUtil.get_pos(arena, params)

	var delay: float = params.get("delay", 0.8)
	var count: int = maxi(int(params.get("count", 12)), 1)
	var rings: int = maxi(int(params.get("rings", 1)), 1)
	var radius: float = params.get("radius", 60.0)
	var radius_step: float = params.get("radius_step", 30.0)
	var angle_offset_deg: float = params.get("angle_offset", 0.0)
	var ring_angle_offset_deg: float = params.get("ring_angle_offset", 15.0)
	var speed: float = params.get("speed", 340.0)
	var trigger_distance: float = params.get("trigger_distance", 10.0)
	var max_wait: float = params.get("max_wait", 3.0)
	var hold_color: Color = PatternUtil.to_color(params.get("hold_color"), Color(1.0, 0.3, 0.9, 1.0))
	var release_color: Color = PatternUtil.to_color(params.get("release_color"), Color(1.0, 1.0, 1.0, 1.0))
	var bullet_scale: float = params.get("bullet_scale", 1.0)
	var spread_deg: float = params.get("spread", 20.0)
	var pulse_period: float = params.get("pulse_period", 0.5)
	var fade_in_time: float = params.get("fade_in_time", 0.35)
	var fade_out_time: float = params.get("fade_out_time", 0.4)
	var spawn_on_player: bool = params.get("spawn_on_player", false)
	var homing_duration: float = params.get("homing_duration", 1.5)
	var turn_rate_deg: float = params.get("turn_rate", 180.0)

	var viewport_size: Vector2 = arena.get_viewport_rect().size

	var center: Vector2 = spawn_pos
	var player: Node2D = PatternUtil.get_player(arena)
	if spawn_on_player and player != null:
		center = player.global_position

	var dot: Sprite2D = PatternUtil.spawn_dot(arena, center, hold_color)
	await PatternUtil.wait(arena, delay)
	PatternUtil.free_node(dot)

	if not PatternUtil.arena_alive(arena):
		return

	var bullets: Array = []
	var pulse_tweens: Array = []
	var fade_in_tweens: Array = []

	for ring in range(rings):
		var ring_radius: float = radius + float(ring) * radius_step
		var ring_offset: float = deg_to_rad(angle_offset_deg + float(ring) * ring_angle_offset_deg)
		var angle_step: float = TAU / float(count)

		for i in range(count):
			var angle: float = float(i) * angle_step + ring_offset
			var pos: Vector2 = center + Vector2.from_angle(angle) * ring_radius
			pos.x = clampf(pos.x, 12.0, viewport_size.x - 12.0)
			pos.y = clampf(pos.y, 12.0, viewport_size.y - 12.0)

			# Пока ждём игрока, пуля неподвижна (direction = ZERO, speed = 0).
			var bullet = PatternUtil.spawn_bullet(arena, pos, Vector2.ZERO, 0.0)
			bullets.append(bullet)

			bullet.modulate = hold_color
			bullet.modulate.a = 0.0
			bullet.scale = Vector2(bullet_scale * 0.4, bullet_scale * 0.4)

			# Твины привязаны к самой пуле: умирает пуля — умирают и они.
			var ft: Tween = bullet.create_tween()
			ft.tween_property(bullet, "modulate:a", 1.0, fade_in_time)
			ft.parallel().tween_property(bullet, "scale", Vector2(bullet_scale, bullet_scale), fade_in_time)
			fade_in_tweens.append(ft)

			var bt: Tween = bullet.create_tween()
			bt.set_loops()
			bt.tween_property(bullet, "modulate:r", release_color.r, pulse_period * 0.5)
			bt.parallel().tween_property(bullet, "modulate:g", release_color.g, pulse_period * 0.5)
			bt.parallel().tween_property(bullet, "modulate:b", release_color.b, pulse_period * 0.5)
			bt.tween_property(bullet, "modulate:r", hold_color.r, pulse_period * 0.5)
			bt.parallel().tween_property(bullet, "modulate:g", hold_color.g, pulse_period * 0.5)
			bt.parallel().tween_property(bullet, "modulate:b", hold_color.b, pulse_period * 0.5)
			pulse_tweens.append(bt)

	var player_start: Vector2 = Vector2.ZERO
	if player != null:
		player_start = player.global_position

	# Время копим из delta, а не берём из Time.get_ticks_msec(): так пауза не «съедает» ожидание.
	var waited: float = 0.0
	var triggered: bool = false

	while waited < max_wait:
		player = PatternUtil.get_player(arena)
		if player != null and player.global_position.distance_to(player_start) >= trigger_distance:
			triggered = true
			break
		waited += await PatternUtil.next_frame(arena)
		if not PatternUtil.arena_alive(arena):
			return

	for bt in pulse_tweens:
		if is_instance_valid(bt):
			bt.kill()
	# Недоигранное появление не должно перебивать цвет и размер после выстрела.
	for ft in fade_in_tweens:
		if is_instance_valid(ft):
			ft.kill()

	if not triggered:
		for bullet in bullets:
			if not is_instance_valid(bullet):
				continue
			var fo: Tween = bullet.create_tween()
			fo.tween_property(bullet, "modulate:a", 0.0, fade_out_time)
			fo.tween_callback(bullet.queue_free)
		await PatternUtil.wait(arena, fade_out_time)
		return

	var aim_base: Vector2 = center
	player = PatternUtil.get_player(arena)
	if player != null:
		aim_base = player.global_position

	var spread_rad: float = deg_to_rad(spread_deg)

	for i in range(bullets.size()):
		var bullet = bullets[i]
		if not is_instance_valid(bullet):
			continue

		var dir: Vector2 = (aim_base - bullet.global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN

		if bullets.size() > 1:
			var t: float = float(i) / float(bullets.size() - 1) - 0.5
			dir = dir.rotated(t * spread_rad)

		bullet.direction = dir
		bullet.speed = speed

		bullet.modulate = Color(release_color.r, release_color.g, release_color.b, 1.0)
		bullet.scale = Vector2(bullet_scale, bullet_scale)

	var homing_elapsed: float = 0.0
	var max_turn_rad: float = deg_to_rad(turn_rate_deg)
	var delta: float = arena.get_physics_process_delta_time()

	while homing_elapsed < homing_duration:
		player = PatternUtil.get_player(arena)
		var has_alive: bool = false
		for bullet in bullets:
			if not is_instance_valid(bullet):
				continue
			has_alive = true

			if player == null:
				break

			var to_player: Vector2 = player.global_position - bullet.global_position
			if to_player == Vector2.ZERO:
				continue

			var diff: float = wrapf(to_player.angle() - bullet.direction.angle(), -PI, PI)
			var turn: float = clampf(diff, -max_turn_rad * delta, max_turn_rad * delta)
			bullet.direction = Vector2.from_angle(bullet.direction.angle() + turn)

		if not has_alive:
			break

		delta = await PatternUtil.next_frame(arena)
		if not PatternUtil.arena_alive(arena):
			return
		homing_elapsed += delta
