extends RefCounted

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var spawn_pos: Vector2 = PatternUtil.get_pos(arena, params)

	var delay: float = params.get("delay", 1.0)
	var arms: int = maxi(int(params.get("arms", 1)), 1)
	var bullets_per_tick: int = maxi(int(params.get("bullets_per_tick", 1)), 1)
	var tick_interval: float = maxf(params.get("tick_interval", 0.05), 0.001)
	var duration: float = params.get("duration", 2.0)
	var angle_step_deg: float = params.get("angle_step", 10.0)
	var angle_accel_deg: float = params.get("angle_accel", 0.0)
	var start_angle_deg: float = params.get("start_angle", 0.0)
	var aimed_start: bool = params.get("aimed_start", false)
	var reverse: bool = params.get("reverse", false)
	var speed: float = params.get("speed", 220.0)
	var speed_variation: float = params.get("speed_variation", 0.0)
	var speed_grow: float = params.get("speed_grow", 0.0)
	var spread_within_arm_deg: float = params.get("spread_within_arm", 0.0)
	var dot_scale_min: float = params.get("dot_scale_min", 0.3)
	var dot_scale_max: float = params.get("dot_scale_max", 0.6)
	var dot_color: Color = PatternUtil.to_color(params.get("dot_color"), Color(1, 1, 1, 0.7))

	var dir_sign: float = -1.0 if reverse else 1.0
	var current_angle_rad: float = deg_to_rad(start_angle_deg)

	if aimed_start:
		var player: Node2D = PatternUtil.get_player(arena)
		if player != null:
			current_angle_rad = (player.global_position - spawn_pos).normalized().angle()

	var arm_offsets: Array[float] = []
	for a in range(arms):
		arm_offsets.append(TAU * float(a) / float(arms))

	var dot: Sprite2D = PatternUtil.spawn_dot(arena, spawn_pos, dot_color, dot_scale_min, dot_scale_max)
	await PatternUtil.wait(arena, delay)
	PatternUtil.free_node(dot)

	if not PatternUtil.arena_alive(arena):
		return

	var angle_step_rad: float = deg_to_rad(angle_step_deg)
	var angle_accel_rad: float = deg_to_rad(angle_accel_deg)
	var spread_rad: float = deg_to_rad(spread_within_arm_deg)
	var ticks: int = maxi(int(duration / tick_interval), 1)

	for t in range(ticks):
		if not PatternUtil.arena_alive(arena):
			return

		var current_speed: float = maxf(speed + speed_grow * float(t), 1.0)

		for a in range(arms):
			for b in range(bullets_per_tick):
				var extra_offset: float = 0.0
				if bullets_per_tick > 1 and spread_rad != 0.0:
					extra_offset = -spread_rad * 0.5 + spread_rad * float(b) / float(bullets_per_tick - 1)

				var angle: float = current_angle_rad + arm_offsets[a] + extra_offset
				var bullet_speed: float = current_speed
				if speed_variation != 0.0:
					bullet_speed += randf_range(-speed_variation, speed_variation)
				bullet_speed = maxf(bullet_speed, 1.0)

				PatternUtil.spawn_bullet(arena, spawn_pos, Vector2.from_angle(angle), bullet_speed)

		current_angle_rad += dir_sign * (angle_step_rad + angle_accel_rad * float(t))

		await PatternUtil.wait(arena, tick_interval)
