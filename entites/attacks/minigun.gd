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

	var delay: float = params.get("delay", 0.5)
	var follow_time: float = params.get("follow_time", 1.0)
	var lock_time: float = params.get("lock_time", 0.7)
	var shots: int = params.get("shots", 12)
	var shot_interval: float = params.get("shot_interval", 0.06)
	var speed: float = params.get("speed", 420.0)
	var spread_deg: float = params.get("spread", 2.0)
	var follow_player: bool = params.get("follow_player", true)
	var crosshair_size: float = params.get("crosshair_size", 26.0)
	var crosshair_color: Color = _to_color(params.get("crosshair_color"), Color(1.0, 0.9, 0.3, 1.0))
	var lock_color: Color = _to_color(params.get("lock_color"), Color(1.0, 0.2, 0.2, 1.0))
	var show_target_line: bool = params.get("show_target_line", true)
	var dot_color: Color = _to_color(params.get("dot_color"), Color(1.0, 0.9, 0.3, 0.7))

	var player: Node = arena.get_node_or_null("player")

	var dot: Sprite2D = Sprite2D.new()
	dot.texture = DOT_TEXTURE
	dot.global_position = spawn_pos
	dot.scale = Vector2(0.3, 0.3)
	dot.modulate = dot_color
	arena.add_child(dot)

	var tween: Tween = arena.create_tween()
	tween.tween_property(dot, "scale", Vector2(0.6, 0.6), 0.2)
	tween.tween_property(dot, "scale", Vector2(0.3, 0.3), 0.2)
	tween.set_loops()

	await tree.create_timer(delay).timeout

	if is_instance_valid(tween):
		tween.kill()
	if is_instance_valid(dot):
		dot.queue_free()

	if not _arena_alive(arena):
		return

	var initial_target: Vector2 = spawn_pos + Vector2.RIGHT * 200.0
	if player and is_instance_valid(player):
		initial_target = player.global_position

	var ch_h: Line2D = Line2D.new()
	ch_h.add_point(Vector2(-crosshair_size, 0.0))
	ch_h.add_point(Vector2(crosshair_size, 0.0))
	ch_h.width = 3.0
	ch_h.default_color = crosshair_color
	ch_h.z_index = 10
	ch_h.global_position = initial_target
	arena.add_child(ch_h)

	var ch_v: Line2D = Line2D.new()
	ch_v.add_point(Vector2(0.0, -crosshair_size))
	ch_v.add_point(Vector2(0.0, crosshair_size))
	ch_v.width = 3.0
	ch_v.default_color = crosshair_color
	ch_v.z_index = 10
	ch_v.global_position = initial_target
	arena.add_child(ch_v)

	var target_line: Line2D = null
	if show_target_line:
		target_line = Line2D.new()
		target_line.add_point(spawn_pos)
		target_line.add_point(initial_target)
		target_line.width = 1.5
		target_line.default_color = Color(crosshair_color.r, crosshair_color.g, crosshair_color.b, 0.35)
		target_line.z_index = 9
		arena.add_child(target_line)

	var follow_elapsed: float = 0.0
	while follow_elapsed < follow_time:
		if not _arena_alive(arena):
			return
		if follow_player and player and is_instance_valid(player):
			var pos: Vector2 = player.global_position
			ch_h.global_position = pos
			ch_v.global_position = pos
			if target_line:
				target_line.set_point_position(1, pos)
		await tree.physics_frame
		follow_elapsed += arena.get_physics_process_delta_time()

	var lock_pos: Vector2 = ch_h.global_position
	if player and is_instance_valid(player):
		lock_pos = player.global_position
		ch_h.global_position = lock_pos
		ch_v.global_position = lock_pos
		if target_line:
			target_line.set_point_position(1, lock_pos)

	ch_h.default_color = lock_color
	ch_v.default_color = lock_color
	if target_line:
		target_line.default_color = Color(lock_color.r, lock_color.g, lock_color.b, 0.5)

	var pulse: Tween = arena.create_tween()
	pulse.set_loops()
	pulse.tween_property(ch_h, "modulate:a", 0.4, 0.1)
	pulse.parallel().tween_property(ch_v, "modulate:a", 0.4, 0.1)
	pulse.tween_property(ch_h, "modulate:a", 1.0, 0.1)
	pulse.parallel().tween_property(ch_v, "modulate:a", 1.0, 0.1)

	await tree.create_timer(lock_time).timeout

	if is_instance_valid(pulse):
		pulse.kill()

	if not _arena_alive(arena):
		if is_instance_valid(ch_h):
			ch_h.queue_free()
		if is_instance_valid(ch_v):
			ch_v.queue_free()
		if is_instance_valid(target_line):
			target_line.queue_free()
		return

	var base_dir: Vector2 = (lock_pos - spawn_pos).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.DOWN

	var spread_rad: float = deg_to_rad(spread_deg)

	for i in range(shots):
		if not _arena_alive(arena):
			break

		var dir: Vector2 = base_dir
		if spread_rad > 0.0:
			dir = base_dir.rotated(randf_range(-spread_rad, spread_rad))

		var bullet = BULLET_SCENE.instantiate()
		bullet.global_position = spawn_pos
		bullet.direction = dir
		bullet.speed = speed
		arena.bullet_container.add_child(bullet)

		await tree.create_timer(shot_interval).timeout

	if is_instance_valid(ch_h):
		ch_h.queue_free()
	if is_instance_valid(ch_v):
		ch_v.queue_free()
	if is_instance_valid(target_line):
		target_line.queue_free()
