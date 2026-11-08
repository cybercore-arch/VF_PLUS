extends RefCounted
## Одиночный выстрел лазером (или веер лазеров).
## Сначала тусклая безопасная линия показывает траекторию (warn_time), потом линия
## разгорается в яркий луч, который убивает при касании.
##
## Куда целиться: angle (градусы, 0 = вправо, 90 = вниз) либо target
## ("player" по умолчанию, "center", "random", [x, y]) / target_x / target_y.
## Откуда: pos или x/y.
## track_time — сколько секунд предупреждающая линия следует за целью, потом замирает.
## count и spread — веер из count лазеров на spread градусов.
## show_origin — мигающая точка-излучатель в начале луча.
## Настройки самого лазера: width, warn_width, warn_time, grow_time, active_time,
## fade_time, color, warn_alpha, length, hit_scale.

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var origin: Vector2 = PatternUtil.get_pos(arena, params)
	var count: int = maxi(int(params.get("count", 1)), 1)
	var spread_rad: float = deg_to_rad(params.get("spread", 0.0))
	var track_time: float = params.get("track_time", 0.0)
	var show_origin: bool = params.get("show_origin", true)
	var opts: Dictionary = PatternUtil.laser_options(params)

	var base_angle: float = _aim(arena, origin, params)

	var dot: Sprite2D = null
	if show_origin:
		var base_color: Color = PatternUtil.to_color(params.get("color"), Color(1.0, 0.2, 0.3))
		dot = PatternUtil.spawn_dot(arena, origin, Color(base_color.r, base_color.g, base_color.b, 0.7))

	var lasers: Array = []
	for i in range(count):
		lasers.append(PatternUtil.spawn_laser(arena, origin, base_angle + _fan_offset(i, count, spread_rad), opts))

	var total: float = lasers[0].total_time()
	var tracked: float = 0.0
	var track_limit: float = minf(track_time, lasers[0].warn_time)

	# Пока идёт слежение, поворачиваем предупреждающие линии за целью.
	while tracked < track_limit:
		var d: float = await PatternUtil.next_frame(arena)
		if not PatternUtil.arena_alive(arena):
			return
		tracked += d
		var angle: float = _aim(arena, origin, params)
		for i in range(count):
			if is_instance_valid(lasers[i]):
				lasers[i].global_rotation = angle + _fan_offset(i, count, spread_rad)

	await PatternUtil.wait(arena, maxf(total - tracked, 0.0))
	PatternUtil.free_node(dot)


func _fan_offset(i: int, count: int, spread_rad: float) -> float:
	if count <= 1:
		return 0.0
	return (float(i) / float(count - 1) - 0.5) * spread_rad


## Угол выстрела в радианах.
func _aim(arena: Node2D, origin: Vector2, params: Dictionary) -> float:
	if params.has("angle"):
		return deg_to_rad(float(params["angle"]))
	var target: Vector2 = PatternUtil.resolve_point(params.get("target", "player"), arena, origin + Vector2.DOWN * 100.0)
	if params.has("target_x") or params.has("target_y"):
		target = Vector2(params.get("target_x", target.x), params.get("target_y", target.y))
	if target.is_equal_approx(origin):
		return PI * 0.5
	return (target - origin).angle()
