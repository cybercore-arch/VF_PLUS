extends RefCounted
## Сетка из лазеров: rows горизонтальных и cols вертикальных линий, равномерно по экрану.
## Между линиями остаются безопасные клетки. Все линии сначала показывают тусклое предупреждение.
##
## rows, cols    — сколько горизонтальных / вертикальных лазеров (0 — не создавать)
## margin        — отступ сетки от краёв экрана, пиксели
## skip          — сколько случайных линий выбросить (получаются широкие безопасные коридоры)
## order         — "sequential" (по порядку: сверху вниз, слева направо) или "shuffle"
## stagger       — задержка между линиями, сек (0 — все стреляют одновременно)
## warn_all      — true (по умолчанию): все предупреждения видны сразу, а стреляют по очереди;
##                 false: каждая линия сама показывает предупреждение и стреляет после предыдущей
## Настройки лазера: width, warn_width, warn_time, grow_time, active_time, fade_time,
## color, warn_alpha, length, hit_scale.

const START_OUTSIDE: float = 50.0

func execute(arena: Node2D, params: Dictionary) -> void:
	if not PatternUtil.arena_alive(arena):
		return

	var vp: Vector2 = arena.get_viewport_rect().size
	var rows: int = maxi(int(params.get("rows", 4)), 0)
	var cols: int = maxi(int(params.get("cols", 6)), 0)
	var margin: float = params.get("margin", 0.0)
	var skip: int = maxi(int(params.get("skip", 0)), 0)
	var order: String = str(params.get("order", "sequential")).to_lower()
	var stagger: float = maxf(params.get("stagger", 0.0), 0.0)
	var warn_all: bool = params.get("warn_all", true)
	var opts: Dictionary = PatternUtil.laser_options(params)

	# Линия: [точка старта, угол в радианах].
	var lines: Array = []
	for i in range(rows):
		var y: float = margin + (float(i) + 0.5) * (vp.y - 2.0 * margin) / float(rows)
		lines.append([Vector2(-START_OUTSIDE, y), 0.0])
	for i in range(cols):
		var x: float = margin + (float(i) + 0.5) * (vp.x - 2.0 * margin) / float(cols)
		lines.append([Vector2(x, -START_OUTSIDE), PI * 0.5])

	if lines.is_empty():
		return

	# Выбрасываем случайные линии, но хотя бы одна остаётся.
	for n in range(mini(skip, lines.size() - 1)):
		lines.remove_at(randi() % lines.size())

	if order == "shuffle":
		lines.shuffle()

	var base_warn: float = float(opts.get("warn_time", 1.0))

	for i in range(lines.size()):
		var line_opts: Dictionary = opts.duplicate()
		if warn_all:
			# все видны сразу, i-я стреляет через i * stagger после общего предупреждения
			line_opts["warn_time"] = base_warn + float(i) * stagger
		PatternUtil.spawn_laser(arena, lines[i][0], lines[i][1], line_opts)

		if not warn_all and stagger > 0.0 and i < lines.size() - 1:
			await PatternUtil.wait(arena, stagger)
			if not PatternUtil.arena_alive(arena):
				return
