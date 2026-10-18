extends RefCounted
## Кольцо лазеров: count лучей расходятся от центра по кругу, как спицы колеса.
## Лучи можно раскрутить, и они будут заметать экран.
##
## pos (или x/y)  — центр
## count          — число лучей
## start_angle    — угол первого луча, градусы (0 — вправо); random_start: true — случайный
## inner_radius   — безопасный круг вокруг центра: лучи начинаются на этом расстоянии, пиксели
## spin           — скорость вращения во время работы луча, градусы в секунду (минус — против часовой)
## warn_spin      — скорость вращения предупреждающих линий, градусы в секунду (по умолчанию 0)
## show_origin    — мигающая точка в центре
## Настройки лазера: width, warn_width, warn_time, grow_time, active_time, fade_time,
## color, warn_alpha, length, hit_scale.

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var center: Vector2 = PatternUtil.get_pos(arena, params)
	var count: int = maxi(int(params.get("count", 8)), 1)
	var start_angle: float = deg_to_rad(params.get("start_angle", 0.0))
	if params.get("random_start", false):
		start_angle = randf() * TAU
	var inner_radius: float = maxf(params.get("inner_radius", 60.0), 0.0)
	var spin: float = deg_to_rad(params.get("spin", 0.0))
	var warn_spin: float = deg_to_rad(params.get("warn_spin", 0.0))
	var show_origin: bool = params.get("show_origin", true)
	var opts: Dictionary = PatternUtil.laser_options(params)

	var dot: Sprite2D = null
	if show_origin:
		var base_color: Color = PatternUtil.to_color(params.get("color"), Color(1.0, 0.2, 0.3))
		dot = PatternUtil.spawn_dot(arena, center, Color(base_color.r, base_color.g, base_color.b, 0.7))

	var lasers: Array = []
	for i in range(count):
		var a: float = start_angle + TAU * float(i) / float(count)
		lasers.append(PatternUtil.spawn_laser(arena, center + Vector2.from_angle(a) * inner_radius, a, opts))

	var total: float = lasers[0].total_time()
	var warn_phase: float = lasers[0].warn_time + lasers[0].grow_time

	if spin == 0.0 and warn_spin == 0.0:
		await PatternUtil.wait(arena, total)
	else:
		var t: float = 0.0
		while t < total:
			t += await PatternUtil.next_frame(arena)
			if not PatternUtil.arena_alive(arena):
				return
			# до конца предупреждения крутимся со warn_spin, потом со spin
			var rot: float = warn_spin * minf(t, warn_phase) + spin * maxf(t - warn_phase, 0.0)
			for i in range(count):
				var laser = lasers[i]
				if not is_instance_valid(laser):
					continue
				var a2: float = start_angle + TAU * float(i) / float(count) + rot
				laser.global_position = center + Vector2.from_angle(a2) * inner_radius
				laser.global_rotation = a2

	PatternUtil.free_node(dot)
