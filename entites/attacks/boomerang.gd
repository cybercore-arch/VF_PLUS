extends Node

const DOT_TEXTURE = preload("res://assets/sprites/circleWhite.png")
const BULLET_SCENE = preload("res://entites/bullet/bullet.tscn")

func _arena_alive(a) -> bool:
	return is_instance_valid(a) and a is Node2D and a.is_inside_tree()

func _resolve_point(val, arena: Node2D, fallback: Vector2) -> Vector2:
	if val == null:
		return fallback
	if val is Vector2:
		return val
	if val is Array and val.size() == 2:
		return Vector2(float(val[0]), float(val[1]))
	if val is String:
		var vp_size: Vector2 = arena.get_viewport_rect().size
		match val.to_lower():
			"center":
				return vp_size / 2.0
			"random":
				return Vector2(randf_range(50.0, vp_size.x - 50.0), randf_range(50.0, vp_size.y - 50.0))
			"player", "aimed":
				var player: Node = arena.get_node_or_null("player")
				if player:
					return player.global_position
				return vp_size / 2.0
	if val is int or val is float:
		return Vector2(float(val), float(val))
	return fallback

func execute(arena: Node2D, params: Dictionary) -> void:
	if not _arena_alive(arena):
		return

	var tree: SceneTree = arena.get_tree()

	var spawn_pos: Vector2 = _resolve_point(params.get("pos", null), arena, Vector2(640.0, 360.0))
	if params.has("x") or params.has("y"):
		spawn_pos = Vector2(params.get("x", 640.0), params.get("y", 360.0))

	var delay: float = params.get("delay", 0.6)
	var speed_out: float = params.get("speed_out", 340.0)
	var speed_in: float = params.get("speed_in", 420.0)
	var distance: float = params.get("distance", 320.0)
	var count: int = params.get("count", 1)
	var spread_deg: float = params.get("spread", 0.0)
	var return_threshold: float = params.get("return_threshold", 8.0)
	var max_lifetime: float = params.get("max_lifetime", 8.0)
	var dot_color: Color = params.get("dot_color", Color(0.4, 0.9, 1.0, 0.7))

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

	var target_pos: Vector2 = _resolve_point(params.get("target", "player"), arena, spawn_pos + Vector2.DOWN * 200.0)
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

		var bullet = BULLET_SCENE.instantiate()
		bullet.global_position = spawn_pos
		bullet.direction = dir
		bullet.speed = speed_out
		bullet.set_meta("boomerang_state", "out")
		arena.bullet_container.add_child(bullet)
		bullets.append(bullet)

	var elapsed: float = 0.0
	while elapsed < max_lifetime:
		if not _arena_alive(arena):
			return

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
			else:
				if dist <= return_threshold:
					bullet.queue_free()

		if alive_count == 0:
			break

		await tree.physics_frame
		elapsed += arena.get_physics_process_delta_time()
