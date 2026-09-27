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

	var delay: float = params.get("delay", 0.8)
	var count: int = params.get("count", 12)
	var rings: int = params.get("rings", 1)
	var radius: float = params.get("radius", 60.0)
	var radius_step: float = params.get("radius_step", 30.0)
	var angle_offset_deg: float = params.get("angle_offset", 0.0)
	var ring_angle_offset_deg: float = params.get("ring_angle_offset", 15.0)
	var speed: float = params.get("speed", 340.0)
	var trigger_distance: float = params.get("trigger_distance", 10.0)
	var max_wait: float = params.get("max_wait", 3.0)
	var hold_color: Color = params.get("hold_color", Color(1.0, 0.3, 0.9, 1.0))
	var release_color: Color = params.get("release_color", Color(1.0, 1.0, 1.0, 1.0))
	var bullet_scale: float = params.get("bullet_scale", 1.0)
	var spread_deg: float = params.get("spread", 20.0)
	var pulse_period: float = params.get("pulse_period", 0.5)
	var fade_in_time: float = params.get("fade_in_time", 0.35)
	var fade_out_time: float = params.get("fade_out_time", 0.4)
	var spawn_on_player: bool = params.get("spawn_on_player", false)
	var homing_duration: float = params.get("homing_duration", 1.5)
	var turn_rate_deg: float = params.get("turn_rate", 180.0)

	var viewport_size: Vector2 = arena.get_viewport_rect().size
	var player: Node = arena.get_node_or_null("player")

	var center: Vector2 = spawn_pos
	if spawn_on_player and player and is_instance_valid(player):
		center = player.global_position

	var dot: Sprite2D = Sprite2D.new()
	dot.texture = DOT_TEXTURE
	dot.global_position = center
	dot.scale = Vector2(0.3, 0.3)
	dot.modulate = hold_color
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

	var bullets: Array = []
	var pulse_tweens: Array = []

	for ring in range(rings):
		var ring_radius: float = radius + float(ring) * radius_step
		var ring_offset: float = deg_to_rad(angle_offset_deg + float(ring) * ring_angle_offset_deg)
		var angle_step: float = TAU / float(count)

		for i in range(count):
			if not _arena_alive(arena):
				for bt in pulse_tweens:
					if is_instance_valid(bt):
						bt.kill()
				return

			var angle: float = float(i) * angle_step + ring_offset
			var offset: Vector2 = Vector2.from_angle(angle) * ring_radius
			var pos: Vector2 = center + offset
			pos.x = clampf(pos.x, 12.0, viewport_size.x - 12.0)
			pos.y = clampf(pos.y, 12.0, viewport_size.y - 12.0)

			var bullet = BULLET_SCENE.instantiate()
			bullet.global_position = pos
			bullet.direction = Vector2.ZERO
			bullet.speed = 0.0
			arena.bullet_container.add_child(bullet)
			bullets.append(bullet)

			if bullet is CanvasItem:
				bullet.modulate = hold_color
				bullet.modulate.a = 0.0
				bullet.scale = Vector2(bullet_scale * 0.4, bullet_scale * 0.4)

				var ft: Tween = arena.create_tween()
				ft.tween_property(bullet, "modulate:a", 1.0, fade_in_time)
				ft.parallel().tween_property(bullet, "scale", Vector2(bullet_scale, bullet_scale), fade_in_time)

				var bt: Tween = arena.create_tween()
				bt.set_loops()
				bt.tween_property(bullet, "modulate:r", release_color.r, pulse_period * 0.5)
				bt.parallel().tween_property(bullet, "modulate:g", release_color.g, pulse_period * 0.5)
				bt.parallel().tween_property(bullet, "modulate:b", release_color.b, pulse_period * 0.5)
				bt.tween_property(bullet, "modulate:r", hold_color.r, pulse_period * 0.5)
				bt.parallel().tween_property(bullet, "modulate:g", hold_color.g, pulse_period * 0.5)
				bt.parallel().tween_property(bullet, "modulate:b", hold_color.b, pulse_period * 0.5)
				pulse_tweens.append(bt)

	var player_start: Vector2 = Vector2.ZERO
	if player and is_instance_valid(player):
		player_start = player.global_position

	var start_ms: int = Time.get_ticks_msec()
	var max_wait_ms: int = int(max_wait * 1000.0)
	var triggered: bool = false

	while Time.get_ticks_msec() - start_ms < max_wait_ms:
		if not _arena_alive(arena):
			for bt in pulse_tweens:
				if is_instance_valid(bt):
					bt.kill()
			return
		if player and is_instance_valid(player):
			if player.global_position.distance_to(player_start) >= trigger_distance:
				triggered = true
				break
		await tree.physics_frame

	for bt in pulse_tweens:
		if is_instance_valid(bt):
			bt.kill()

	if not triggered:
		for bullet in bullets:
			if not is_instance_valid(bullet):
				continue
			if bullet is CanvasItem:
				var fo: Tween = arena.create_tween()
				fo.tween_property(bullet, "modulate:a", 0.0, fade_out_time)
				fo.tween_callback(bullet.queue_free)
			else:
				bullet.queue_free()
		await tree.create_timer(fade_out_time).timeout
		return

	if not _arena_alive(arena):
		return

	var aim_base: Vector2 = center
	if player and is_instance_valid(player):
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

		if bullet is CanvasItem:
			bullet.modulate.a = 1.0
			bullet.modulate.r = release_color.r
			bullet.modulate.g = release_color.g
			bullet.modulate.b = release_color.b
			bullet.scale = Vector2.ONE

	var homing_elapsed: float = 0.0
	var max_turn_rad: float = deg_to_rad(turn_rate_deg)

	while homing_elapsed < homing_duration:
		if not _arena_alive(arena):
			return

		var delta: float = arena.get_physics_process_delta_time()
		homing_elapsed += delta

		var has_alive: bool = false
		for bullet in bullets:
			if not is_instance_valid(bullet):
				continue
			has_alive = true

			if not player or not is_instance_valid(player):
				break

			var to_player: Vector2 = player.global_position - bullet.global_position
			if to_player == Vector2.ZERO:
				continue

			var desired_angle: float = to_player.angle()
			var current_angle: float = bullet.direction.angle()
			var diff: float = wrapf(desired_angle - current_angle, -PI, PI)
			var step: float = clampf(diff, -max_turn_rad * delta, max_turn_rad * delta)
			var new_angle: float = current_angle + step
			bullet.direction = Vector2.from_angle(new_angle)

		if not has_alive:
			break

		await tree.physics_frame
