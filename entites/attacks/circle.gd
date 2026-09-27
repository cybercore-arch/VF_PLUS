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

	var delay: float = params.get("delay", 0.6)
	var dot_scale_min: float = params.get("dot_scale_min", 0.3)
	var dot_scale_max: float = params.get("dot_scale_max", 0.6)
	var dot_color: Color = params.get("dot_color", Color(1, 1, 1, 0.7))

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

	var count: int = params.get("count", 12)
	var speed: float = params.get("speed", 250.0)
	var angle_step: float = TAU / float(count)

	for i in range(count):
		if not _arena_alive(arena):
			return
		var angle: float = float(i) * angle_step
		var dir: Vector2 = Vector2.from_angle(angle)
		var bullet = BULLET_SCENE.instantiate()
		bullet.global_position = spawn_pos
		bullet.direction = dir
		bullet.speed = speed
		arena.bullet_container.add_child(bullet)
