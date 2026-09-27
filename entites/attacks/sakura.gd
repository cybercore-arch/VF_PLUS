extends Node

const DOT_TEXTURE = preload("res://assets/sprites/circleWhite.png")
const BULLET_SCENE = preload("res://entites/bullet/bullet.tscn")

func _arena_alive(a) -> bool:
	return is_instance_valid(a) and a is Node2D and a.is_inside_tree()

func _to_color(val, default_color: Color) -> Color:
	if val == null:
		return default_color
	if val is Color:
		return val
	if val is Array:
		if val.size() == 3:
			return Color(float(val[0]), float(val[1]), float(val[2]), 1.0)
		if val.size() == 4:
			return Color(float(val[0]), float(val[1]), float(val[2]), float(val[3]))
	return default_color

func _get_side_geometry(side: String, viewport_size: Vector2) -> Dictionary:
	match side:
		"bottom":
			return {"length": viewport_size.x, "fixed": viewport_size.y, "dir": Vector2.UP, "horizontal": true}
		"left":
			return {"length": viewport_size.y, "fixed": 0.0, "dir": Vector2.RIGHT, "horizontal": false}
		"right":
			return {"length": viewport_size.y, "fixed": viewport_size.x, "dir": Vector2.LEFT, "horizontal": false}
	return {"length": viewport_size.x, "fixed": 0.0, "dir": Vector2.DOWN, "horizontal": true}

func _side_pos(t: float, geo: Dictionary, inset: float) -> Vector2:
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

func execute(arena: Node2D, params: Dictionary) -> void:
	if not _arena_alive(arena):
		return

	var tree: SceneTree = arena.get_tree()
	var viewport_size: Vector2 = arena.get_viewport_rect().size
	var side: String = params.get("side", "top")
	var geo: Dictionary = _get_side_geometry(side, viewport_size)
	var wall_length: float = geo["length"]
	var base_dir: Vector2 = geo["dir"]

	var delay: float = params.get("delay", 1.0)
	var count: int = params.get("count", 40)
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
	var telegraph_color: Color = _to_color(params.get("telegraph_color"), Color(1.0, 0.6, 0.8, 0.6))
	var telegraph_width: float = params.get("telegraph_width", 4.0)
	var show_telegraph: bool = params.get("show_telegraph", true)

	if show_telegraph:
		var line: Line2D = Line2D.new()
		if geo["horizontal"]:
			var y: float = geo["fixed"] + spawn_margin if geo["dir"] == Vector2.DOWN else geo["fixed"] - spawn_margin
			line.add_point(Vector2(0.0, y))
			line.add_point(Vector2(wall_length, y))
		else:
			var x: float = geo["fixed"] + spawn_margin if geo["dir"] == Vector2.RIGHT else geo["fixed"] - spawn_margin
			line.add_point(Vector2(x, 0.0))
			line.add_point(Vector2(x, wall_length))
		line.width = telegraph_width
		line.default_color = telegraph_color
		arena.add_child(line)

		var tween: Tween = arena.create_tween()
		tween.set_loops()
		tween.tween_property(line, "modulate:a", 0.3, 0.25)
		tween.tween_property(line, "modulate:a", 1.0, 0.25)

		await tree.create_timer(delay).timeout

		if is_instance_valid(tween):
			tween.kill()
		if is_instance_valid(line):
			line.queue_free()
	else:
		await tree.create_timer(delay).timeout

	if not _arena_alive(arena):
		return

	var spread_rad: float = deg_to_rad(angle_spread_deg)
	var entries: Array = []
	var spawned: int = 0
	var elapsed: float = 0.0
	var grace_time: float = 8.0
	var total_duration: float = float(count) * spawn_interval

	while true:
		if not _arena_alive(arena):
			return

		while spawned < count and elapsed >= float(spawned) * spawn_interval:
			var t: float
			if spawn_range > 0.0:
				var range_half: float = spawn_range * 0.5
				var center_pos: float = wall_length * spawn_center
				t = randf_range(center_pos - range_half, center_pos + range_half)
			else:
				t = randf_range(0.0, wall_length)
			t = clampf(t, 0.0, wall_length)

			var pos: Vector2 = _side_pos(t, geo, spawn_margin)

			var dir: Vector2 = base_dir
			if spread_rad > 0.0:
				dir = base_dir.rotated(randf_range(-spread_rad, spread_rad))

			var bspeed: float = speed
			if speed_variation > 0.0:
				bspeed += randf_range(-speed_variation, speed_variation)
			if bspeed < 1.0:
				bspeed = 1.0

			var bullet = BULLET_SCENE.instantiate()
			bullet.global_position = pos
			bullet.direction = dir
			bullet.speed = bspeed

			if bullet_color != null and bullet is CanvasItem:
				bullet.modulate = _to_color(bullet_color, Color(1, 1, 1, 1))

			arena.bullet_container.add_child(bullet)

			var phase: float = randf_range(0.0, TAU) if sway_phase_random else 0.0
			var freq: float = sway_frequency
			if sway_freq_variation > 0.0:
				freq += randf_range(-sway_freq_variation, sway_freq_variation)
			if freq < 0.05:
				freq = 0.05

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
		var delta: float = arena.get_physics_process_delta_time()
		for entry in entries:
			var b = entry["bullet"]
			if not is_instance_valid(b):
				continue
			alive += 1
			entry["elapsed"] += delta
			var e: float = entry["elapsed"]
			var offset_deg: float = sin(entry["phase"] + e * entry["freq"]) * entry["amplitude"]
			b.direction = entry["base_dir"].rotated(deg_to_rad(offset_deg))

		if spawned >= count and alive == 0:
			break
		if elapsed > total_duration + grace_time:
			break

		await tree.physics_frame
		elapsed += delta
