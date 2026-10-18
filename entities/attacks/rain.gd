extends RefCounted
## «Пулевой дождь» в стиле Touhou / Асгора: плотный поток пуль с одной стороны экрана,
## в котором нужно искать проход.
##
## Режимы (mode):
##   "gaps"   — ряды пуль через весь экран с проходом, который двигается от ряда к ряду (по умолчанию)
##   "random" — пули в случайных местах; при gap_size > 0 в них вырезается движущийся безопасный коридор
##
## Движение прохода (gap_motion):
##   "wander" — случайное блуждание, до gap_step пикселей за ряд (по умолчанию)
##   "sine"   — плавно ходит туда-обратно: размах gap_amplitude (доля длины стороны), период gap_period сек
##   "random" — каждый ряд прыгает в новое место
##   "fixed"  — стоит на месте
##
## Остальные параметры (значения по умолчанию в коде ниже): side, delay, duration, tick_interval,
## spacing, per_tick, speed, speed_variation, gap_size, gap_start, stagger, jitter, tilt,
## sway, sway_period, spawn_offset, bullet_color, show_telegraph, telegraph_color, telegraph_width.

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var viewport_size: Vector2 = arena.get_viewport_rect().size
	var side: String = str(params.get("side", "top")).to_lower()
	var geo: Dictionary = PatternUtil.side_geometry(side, viewport_size)
	var length: float = geo["length"]
	var base_dir: Vector2 = geo["dir"]

	var mode: String = str(params.get("mode", "gaps")).to_lower()
	var delay: float = params.get("delay", 1.0)
	var duration: float = params.get("duration", 6.0)
	var tick_interval: float = maxf(params.get("tick_interval", 0.14), 0.01)
	var spacing: float = maxf(params.get("spacing", 48.0), 4.0)
	var per_tick: int = maxi(int(params.get("per_tick", 6)), 1)
	var speed: float = params.get("speed", 200.0)
	var speed_variation: float = params.get("speed_variation", 0.0)
	var stagger: bool = params.get("stagger", false)
	var jitter: float = params.get("jitter", 0.0)
	var tilt_deg: float = params.get("tilt", 0.0)
	var sway_deg: float = params.get("sway", 0.0)
	var sway_period: float = maxf(params.get("sway_period", 3.0), 0.1)
	var spawn_offset: float = params.get("spawn_offset", 1.0)
	var bullet_color = params.get("bullet_color", null)
	var show_telegraph: bool = params.get("show_telegraph", true)
	var telegraph_color: Color = PatternUtil.to_color(params.get("telegraph_color"), Color(0.5, 0.8, 1.0, 0.6))
	var telegraph_width: float = params.get("telegraph_width", 4.0)

	var gap_size: float = params.get("gap_size", 180.0 if mode == "gaps" else 0.0)
	gap_size = minf(gap_size, length * 0.9)
	var gap_half: float = gap_size * 0.5
	var gap_motion: String = str(params.get("gap_motion", "wander")).to_lower()
	var gap_step: float = params.get("gap_step", 60.0)
	var gap_amplitude: float = params.get("gap_amplitude", 0.35)
	var gap_period: float = maxf(params.get("gap_period", 4.0), 0.1)
	var gap_start = params.get("gap_start", "random")
	var gap_min: float = gap_half
	var gap_max: float = length - gap_half
	var gap_center: float = length * 0.5
	if gap_start is String:
		gap_center = randf_range(gap_min, gap_max)
	elif gap_start is float or gap_start is int:
		gap_center = clampf(float(gap_start) * length, gap_min, gap_max)

	# Телеграф: мигающая линия вдоль стороны, откуда пойдёт дождь.
	if show_telegraph:
		var line: Line2D = PatternUtil.make_line(
			arena,
			PatternUtil.side_pos(0.0, geo, spawn_offset),
			PatternUtil.side_pos(length, geo, spawn_offset),
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

	var ticks: int = maxi(int(duration / tick_interval), 1)
	var elapsed: float = 0.0

	for tick in range(ticks):
		# Положение прохода в этом ряду.
		if gap_size > 0.0:
			match gap_motion:
				"sine":
					var mid: float = length * 0.5
					gap_center = mid + sin(elapsed / gap_period * TAU) * gap_amplitude * length
				"random":
					gap_center = randf_range(gap_min, gap_max)
				"fixed":
					pass
				_:
					gap_center += randf_range(-gap_step, gap_step)
			gap_center = clampf(gap_center, gap_min, gap_max)

		# Наклон потока: постоянный (tilt) плюс покачивание (sway).
		var angle: float = deg_to_rad(tilt_deg + sin(elapsed / sway_period * TAU) * sway_deg)
		var dir: Vector2 = base_dir.rotated(angle)

		var positions: Array[float] = []
		if mode == "random":
			for i in range(per_tick):
				positions.append(randf_range(0.0, length))
		else:
			var start: float = spacing * 0.5
			if stagger and tick % 2 == 1:
				start = 0.0
			var t: float = start
			while t <= length:
				positions.append(t)
				t += spacing

		for base_t in positions:
			var pos_t: float = base_t
			if jitter > 0.0:
				pos_t += randf_range(-jitter, jitter)
			pos_t = clampf(pos_t, 0.0, length)
			if gap_size > 0.0 and absf(pos_t - gap_center) < gap_half:
				continue

			var bullet_speed: float = speed
			if speed_variation > 0.0:
				bullet_speed += randf_range(-speed_variation, speed_variation)
			bullet_speed = maxf(bullet_speed, 1.0)

			var bullet = PatternUtil.spawn_bullet(arena, PatternUtil.side_pos(pos_t, geo, spawn_offset), dir, bullet_speed)
			if bullet_color != null:
				bullet.modulate = PatternUtil.to_color(bullet_color, Color.WHITE)

		await PatternUtil.wait(arena, tick_interval)
		if not PatternUtil.arena_alive(arena):
			return
		elapsed += tick_interval
