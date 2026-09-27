extends Node

const DOT_TEXTURE = preload("res://assets/sprites/circleWhite.png")
const BULLET_SCENE = preload("res://entites/bullet/bullet.tscn")

func _arena_alive(a) -> bool:
	return is_instance_valid(a) and a is Node2D and a.is_inside_tree()

func execute(arena: Node2D, params: Dictionary) -> void:
	if not _arena_alive(arena):
		return

	var tree: SceneTree = arena.get_tree()

	var spawn_pos: Vector2 = Vector2(640.0, 360.0)
	if params.has("pos") and params["pos"] is Vector2:
		spawn_pos = params["pos"]
	elif params.has("x") or params.has("y"):
		spawn_pos = Vector2(params.get("x", 640.0), params.get("y", 360.0))
	else:
		spawn_pos = params.get("pos", Vector2(640.0, 360.0))

	var delay: float = params.get("delay", 1.0)
	var arms: int = params.get("arms", 1)
	var bullets_per_tick: int = params.get("bullets_per_tick", 1)
	var tick_interval: float = params.get("tick_interval", 0.05)
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
	var dot_color: Color = params.get("dot_color", Color(1, 1, 1, 0.7))

	var dir_sign: float = -1.0 if reverse else 1.0
	var current_angle_rad: float = deg_to_rad(start_angle_deg)

	if aimed_start:
		var player: Node = arena.get_node_or_null("player")
		if player:
			var aim_dir: Vector2 = (player.global_position - spawn_pos).normalized()
			current_angle_rad = aim_dir.angle()

	var arm_offsets: Array[float] = []
	for a in range(arms):
		arm_offsets.append(TAU * float(a) / float(arms))

	var dot: Sprite2D = Sprite2D.new()
	dot.texture = DOT_TEXTURE
	dot.global_position = spawn_pos
	dot.scale = Vector2(dot_scale_min, dot_scale_min)
	dot.modulate = dot_color
	arena.add_child(dot)

	var tween: Tween = arena.create_tween()
	tween.tween_property(dot, "scale", Vector2(dot_scale_max, dot_scale_max), 0.2)
	tween.tween_property(dot, "scale", Vector2(dot_scale_min, dot_scale_min), 0.2)
	tween.set_loops()

	await tree.create_timer(delay).timeout

	if is_instance_valid(tween):
		tween.kill()
	if is_instance_valid(dot):
		dot.queue_free()

	if not _arena_alive(arena):
		return

	var angle_step_rad: float = deg_to_rad(angle_step_deg)
	var angle_accel_rad: float = deg_to_rad(angle_accel_deg)
	var spread_rad: float = deg_to_rad(spread_within_arm_deg)
	var ticks: int = int(duration / tick_interval)
	if ticks < 1:
		ticks = 1

	for t in range(ticks):
		if not _arena_alive(arena):
			return

		var current_speed: float = speed + speed_grow * float(t)
		if current_speed < 1.0:
			current_speed = 1.0

		for a in range(arms):
			for b in range(bullets_per_tick):
				var extra_offset: float = 0.0
				if bullets_per_tick > 1 and spread_rad != 0.0:
					extra_offset = -spread_rad * 0.5 + spread_rad * float(b) / float(bullets_per_tick - 1)

				var angle: float = current_angle_rad + arm_offsets[a] + extra_offset
				var dir: Vector2 = Vector2.from_angle(angle)

				var bullet_speed: float = current_speed
				if speed_variation != 0.0:
					bullet_speed += randf_range(-speed_variation, speed_variation)
				if bullet_speed < 1.0:
					bullet_speed = 1.0

				var bullet = BULLET_SCENE.instantiate()
				bullet.global_position = spawn_pos
				bullet.direction = dir
				bullet.speed = bullet_speed
				arena.bullet_container.add_child(bullet)

		current_angle_rad += dir_sign * (angle_step_rad + angle_accel_rad * float(t))

		await tree.create_timer(tick_interval).timeout
