extends RefCounted
## Мета-паттерн: выбирает случайный паттерн со случайными параметрами и запускает его.
## `params.pool` — необязательный список имён, из которых выбирать.
## Остальные params перекрывают случайные значения.

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var candidates: Array[String] = []
	var custom_pool = params.get("pool", null)
	if custom_pool is Array:
		for entry in custom_pool:
			var n: String = str(entry)
			if not PatternUtil.META_PATTERNS.has(n):
				candidates.append(n)
	if candidates.is_empty():
		candidates = PatternUtil.pattern_pool()
	if candidates.is_empty():
		return

	var chosen_pattern: String = candidates.pick_random()

	var auto_params: Dictionary = {}
	auto_params["pos"] = ["center", "random", "player"].pick_random()
	auto_params["delay"] = randf_range(0.3, 0.6)
	auto_params["speed"] = randf_range(180.0, 350.0)
	auto_params["count"] = randi_range(8, 18)

	match chosen_pattern:
		"shot", "boomerang":
			auto_params["target"] = "player"
		"wall":
			auto_params["side"] = ["top", "bottom", "left", "right"].pick_random()
			auto_params["gap_random"] = true
			auto_params["waves"] = randi_range(1, 2)
		"spiral":
			auto_params["arms"] = randi_range(2, 4)
			auto_params["duration"] = randf_range(1.5, 2.5)
		"laser_shot":
			# лазер стартует не из игрока и не веером из 8–18 штук
			auto_params["pos"] = ["center", "random"].pick_random()
			auto_params["count"] = 1
			auto_params["target"] = "player"
			auto_params["warn_time"] = randf_range(0.8, 1.2)
		"laser_grid":
			auto_params["rows"] = randi_range(2, 5)
			auto_params["cols"] = randi_range(3, 7)
			auto_params["skip"] = randi_range(0, 2)
			auto_params["warn_time"] = randf_range(1.2, 1.8)
		"laser_ring":
			auto_params["pos"] = ["center", "random"].pick_random()
			auto_params["count"] = randi_range(4, 10)
			auto_params["spin"] = [0.0, 40.0, -40.0].pick_random()
			auto_params["warn_time"] = randf_range(1.2, 1.8)
		"rain":
			auto_params["side"] = ["top", "bottom", "left", "right"].pick_random()
			auto_params["mode"] = ["gaps", "random"].pick_random()
			auto_params["duration"] = randf_range(3.0, 5.0)
			auto_params["gap_size"] = randf_range(170.0, 240.0)
		"sakura":
			auto_params["side"] = ["top", "left", "right"].pick_random()
			auto_params["count"] = randi_range(15, 25)

	for k in params.keys():
		if k != "pool":
			auto_params[k] = params[k]

	PatternUtil.run_pattern(chosen_pattern, arena, auto_params)
