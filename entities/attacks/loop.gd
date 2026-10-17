extends RefCounted
## Мета-паттерн: запускает другой паттерн несколько раз подряд.
##
## Параметры:
##   target_pattern — имя паттерна (обязательно)
##   repeat         — сколько раз; 0 или меньше = бесконечно
##   interval       — пауза между запусками, сек
##   params         — параметры для вложенного паттерна
##   step_angle     — на сколько градусов сдвигать start_angle с каждым запуском
##   step_speed     — на сколько менять speed с каждым запуском
##   reroll_pos     — true: "pos"/"target" вроде "random" или "player" вычисляются
##                    заново на КАЖДОМ запуске. false (по умолчанию): один раз в начале.

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var target_pattern_name: String = params.get("target_pattern", "")
	if target_pattern_name.is_empty():
		return
	if PatternUtil.load_pattern(target_pattern_name) == null:
		push_error("loop: pattern not found: " + target_pattern_name)
		return

	var repeat_count: int = int(params.get("repeat", 3))
	var is_infinite: bool = repeat_count <= 0
	var interval: float = params.get("interval", 0.2)
	if is_infinite:
		# Бесконечный цикл без ожидания навсегда повесил бы игру.
		interval = maxf(interval, 0.05)
	var angle_step: float = params.get("step_angle", 0.0)
	var speed_step: float = params.get("step_speed", 0.0)
	var reroll_pos: bool = params.get("reroll_pos", false)

	var inner: Dictionary = params.get("params", {})
	var base_params: Dictionary = inner.duplicate(true)
	if not reroll_pos:
		var center: Vector2 = arena.get_viewport_rect().size / 2.0
		if base_params.has("pos"):
			base_params["pos"] = PatternUtil.resolve_point(base_params["pos"], arena, center)
		if base_params.has("target"):
			base_params["target"] = PatternUtil.resolve_point(base_params["target"], arena, center)

	var step: int = 0
	while is_infinite or step < repeat_count:
		var current_params: Dictionary = base_params.duplicate(true)

		if angle_step != 0.0:
			var base_angle: float = current_params.get("start_angle", 0.0)
			current_params["start_angle"] = base_angle + angle_step * float(step)

		if speed_step != 0.0:
			var base_speed: float = current_params.get("speed", 250.0)
			current_params["speed"] = base_speed + speed_step * float(step)

		PatternUtil.run_pattern(target_pattern_name, arena, current_params)

		step += 1
		if interval > 0.0:
			await PatternUtil.wait(arena, interval)
			if not PatternUtil.arena_alive(arena):
				return
