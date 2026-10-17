extends RefCounted

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var viewport_size: Vector2 = arena.get_viewport_rect().size
	var side: String = params.get("side", "top")
	var geo: Dictionary = PatternUtil.side_geometry(side, viewport_size)
	var wall_length: float = geo["length"]
	var base_dir: Vector2 = geo["dir"]

	var delay: float = params.get("delay", 1.0)
	var count: int = int(params.get("count", 40))
	var spawn_interval: float = maxf(params.get("spawn_interval", 0.08), 0.001)
	var speed: float = params.get("speed", 180.0)
	var speed_variation: float = params.get("speed_variation", 40.0)
	var sway_amplitude_deg: float = params.get("sway_amplitude", 35.0)
	var sway_frequency: float = params.get("sway_frequency", 1.5)
	var sway_phase_random: bool = params.get("sway_phase_random", true)
	var sway_freq_variation: float = params.get("sway_freq_variation", 0.0)
	var spawn_margin: float = params.get("spawn_margin", 30.0)
	var spawn_range: float = params.get("spawn_range", 0.0)
	var spawn_center: float = params.get("spawn_center", 0.5)
	var angle_spread_deg: float = params.get("angle_spread", 0.0)
	var bullet_color = params.get("bullet_color", null)
	var telegraph_color: Color = PatternUtil.to_color(params.get("telegraph_color"), Color(1.0, 0.6, 0.8, 0.6))
	var telegraph_width: float = params.get("telegraph_width", 4.0)
	var show_telegraph: bool = params.get("show_telegraph", true)

	if show_telegraph:
		var line: Line2D = PatternUtil.make_line(
			arena,
			PatternUtil.side_pos(0.0, geo, spawn_margin),
			PatternUtil.side_pos(wall_length, geo, spawn_margin),
			telegraph_color, telegraph_width)

		var tween: Tween = line.create_tween()
		tween.set_loops()
		tween.tween_property(line, "modulate:a", 0.3, 0.25)
		tween.tween_property(line, "modulate:a", 1.0, 0.25)

		await PatternUtil.wait(arena, delay)

		PatternUtil.free_node(line)
	else:
		await PatternUtil.wait(arena, delay)

	if not PatternUtil.arena_alive(arena):
		return

	var spread_rad: float = deg_to_rad(angle_spread_deg)
	var entries: Array = []
	var spawned: int = 0
	var elapsed: float = 0.0
	var grace_time: float = 8.0
	var total_duration: float = float(count) * spawn_interval
	var delta: float = arena.get_physics_process_delta_time()

	while true:
		while spawned < count and elapsed >= float(spawned) * spawn_interval:
			var t: float
			if spawn_range > 0.0:
				var range_half: float = spawn_range * 0.5
				var center_pos: float = wall_length * spawn_center
				t = randf_range(center_pos - range_half, center_pos + range_half)
			else:
				t = randf_range(0.0, wall_length)
			t = clampf(t, 0.0, wall_length)

			var dir: Vector2 = base_dir
			if spread_rad > 0.0:
				dir = base_dir.rotated(randf_range(-spread_rad, spread_rad))

			var bspeed: float = speed
			if speed_variation > 0.0:
				bspeed += randf_range(-speed_variation, speed_variation)
			bspeed = maxf(bspeed, 1.0)

			var bullet = PatternUtil.spawn_bullet(arena, PatternUtil.side_pos(t, geo, spawn_margin), dir, bspeed)
			if bullet_color != null:
				bullet.modulate = PatternUtil.to_color(bullet_color, Color(1, 1, 1, 1))

			var phase: float = randf_range(0.0, TAU) if sway_phase_random else 0.0
			var freq: float = sway_frequency
			if sway_freq_variation > 0.0:
				freq += randf_range(-sway_freq_variation, sway_freq_variation)
			freq = maxf(freq, 0.05)

			entries.append({
				"bullet": bullet,
				"base_dir": dir,
				"phase": phase,
				"freq": freq,
				"amplitude": sway_amplitude_deg,
				"elapsed": 0.0
			})
			spawned += 1

		var alive: int = 0
		for entry in entries:
			var b = entry["bullet"]
			if not is_instance_valid(b):
				continue
			alive += 1
			entry["elapsed"] += delta
			var offset_deg: float = sin(entry["phase"] + entry["elapsed"] * entry["freq"]) * entry["amplitude"]
			b.direction = entry["base_dir"].rotated(deg_to_rad(offset_deg))

		if spawned >= count and alive == 0:
			break
		if elapsed > total_duration + grace_time:
			break

		delta = await PatternUtil.next_frame(arena)
		if not PatternUtil.arena_alive(arena):
			return
		elapsed += delta
