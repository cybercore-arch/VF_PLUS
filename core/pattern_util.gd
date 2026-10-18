class_name PatternUtil
extends RefCounted
## Общие функции для паттернов атак и менеджера уровней.
## Паттерн должен быть `extends RefCounted` и иметь `func execute(arena, params)`.

const DOT_TEXTURE: Texture2D = preload("res://assets/sprites/circleWhite.png")
const BULLET_SCENE: PackedScene = preload("res://entities/bullet/bullet.tscn")
const INTERNAL_DIR := "res://entities/attacks/"
const DEFAULT_POS := Vector2(640.0, 360.0)

## Список встроенных паттернов. Нужен как запасной вариант: в экспортной сборке
## DirAccess может показывать скрипты как *.gd.remap или *.gdc.
const BUILTIN_PATTERNS: Array[String] = [
	"boomerang", "circle", "minigun", "puppet", "sakura", "shot", "spiral", "wall",
]
## Мета-паттерны не попадают в пул `random`.
const META_PATTERNS: Array[String] = ["random", "loop"]

static var _pool: Array[String] = []
static var _pool_ready: bool = false


# ---------------------------------------------------------------- арена / время

static func arena_alive(a) -> bool:
	return is_instance_valid(a) and a is Node2D and a.is_inside_tree()


## Пауза уважается: таймер создаётся с process_always = false.
static func wait(arena, seconds: float) -> void:
	if not arena_alive(arena):
		return
	await arena.get_tree().create_timer(maxf(seconds, 0.0), false).timeout


## Ждёт один физический кадр (и не возвращается, пока игра на паузе).
## Возвращает delta, либо 0.0, если арена уже уничтожена.
static func next_frame(arena) -> float:
	if not arena_alive(arena):
		return 0.0
	var tree: SceneTree = arena.get_tree()
	await tree.physics_frame
	while is_instance_valid(arena) and tree.paused:
		await tree.physics_frame
	if not is_instance_valid(arena):
		return 0.0
	return arena.get_physics_process_delta_time()


static func get_player(arena) -> Node2D:
	if not is_instance_valid(arena):
		return null
	var p = arena.get_node_or_null("player")
	if p != null and is_instance_valid(p):
		return p
	return null


static func free_node(n) -> void:
	if is_instance_valid(n):
		n.queue_free()


# ---------------------------------------------------------------- параметры

## [r, g, b] или [r, g, b, a] -> Color. Всё остальное возвращается как есть.
static func maybe_color(val):
	if val is Array and (val.size() == 3 or val.size() == 4):
		for v in val:
			if not (v is float or v is int):
				return val
		if val.size() == 3:
			return Color(float(val[0]), float(val[1]), float(val[2]), 1.0)
		return Color(float(val[0]), float(val[1]), float(val[2]), float(val[3]))
	return val


static func to_color(val, default_color: Color) -> Color:
	if val is Color:
		return val
	var c = maybe_color(val)
	if c is Color:
		return c
	return default_color


## "center" / "random" / "player" / "aimed" / [x, y] / Vector2 -> Vector2.
static func resolve_point(val, arena, fallback: Vector2) -> Vector2:
	if val is Vector2:
		return val
	if val is Array and val.size() == 2:
		if (val[0] is float or val[0] is int) and (val[1] is float or val[1] is int):
			return Vector2(float(val[0]), float(val[1]))
		return fallback
	if val is String and is_instance_valid(arena):
		var vp: Vector2 = arena.get_viewport_rect().size
		match val.to_lower():
			"center":
				return vp / 2.0
			"random":
				return Vector2(randf_range(50.0, vp.x - 50.0), randf_range(50.0, vp.y - 50.0))
			"player", "aimed":
				var p: Node2D = get_player(arena)
				if p != null:
					return p.global_position
				return vp / 2.0
	return fallback


## Позиция спавна: `pos` (любой формат resolve_point), иначе `x`/`y`, иначе fallback.
static func get_pos(arena, params: Dictionary, fallback: Vector2 = DEFAULT_POS) -> Vector2:
	if params.has("pos"):
		return resolve_point(params["pos"], arena, fallback)
	if params.has("x") or params.has("y"):
		return Vector2(float(params.get("x", fallback.x)), float(params.get("y", fallback.y)))
	return fallback


## Глубокая копия параметров: массивы-цвета -> Color (рекурсивно),
## верхнеуровневый `pos` -> Vector2. Исходный словарь не меняется.
static func prepare_params(raw: Dictionary, arena) -> Dictionary:
	var params: Dictionary = _convert_value(raw)
	if params.has("pos"):
		var center: Vector2 = DEFAULT_POS
		if is_instance_valid(arena):
			center = arena.get_viewport_rect().size / 2.0
		params["pos"] = resolve_point(params["pos"], arena, center)
	return params


static func _convert_value(val):
	if val is Dictionary:
		var out: Dictionary = {}
		for k in val.keys():
			out[k] = _convert_value(val[k])
		return out
	if val is Array:
		var c = maybe_color(val)
		if c is Color:
			return c
		var arr: Array = []
		for v in val:
			arr.append(_convert_value(v))
		return arr
	return val


# ---------------------------------------------------------------- загрузка паттернов

## Папка рядом с игрой. В редакторе это корень проекта.
static func external_base_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()


static func patterns_dir() -> String:
	return external_base_dir().path_join("patterns")


static func pattern_pool() -> Array[String]:
	if _pool_ready:
		return _pool
	var names: Array[String] = []
	for n in BUILTIN_PATTERNS:
		names.append(n)
	_collect_scripts(INTERNAL_DIR, names)
	_collect_scripts(patterns_dir(), names)
	_pool = names
	_pool_ready = true
	return _pool


static func _collect_scripts(dir_path: String, names: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		var fn: String = f.trim_suffix(".remap")
		if fn.ends_with(".gdc"):
			fn = fn.trim_suffix("c")
		if not fn.ends_with(".gd"):
			continue
		var base: String = fn.get_basename()
		if META_PATTERNS.has(base) or names.has(base):
			continue
		names.append(base)


## Внешний паттерн приоритетнее встроенного.
static func load_pattern(pattern_name: String) -> GDScript:
	if pattern_name.is_empty() or not pattern_name.is_valid_filename():
		return null
	var external_path: String = patterns_dir().path_join(pattern_name + ".gd")
	if FileAccess.file_exists(external_path):
		var s = load(external_path)
		if s is GDScript:
			return s
	var internal_path: String = INTERNAL_DIR + pattern_name + ".gd"
	if ResourceLoader.exists(internal_path):
		var s2 = load(internal_path)
		if s2 is GDScript:
			return s2
	return null


## Единая точка запуска паттерна (менеджер, loop, random).
static func run_pattern(pattern_name: String, arena, raw_params: Dictionary) -> bool:
	if not arena_alive(arena):
		return false
	var script: GDScript = load_pattern(pattern_name)
	if script == null:
		push_error("pattern not found: " + pattern_name)
		return false
	var inst = script.new()
	if inst == null or not inst.has_method("execute"):
		push_error("pattern has no execute(): " + pattern_name)
		return false
	# Старые моды могли быть `extends Node`: вешаем их на арену, чтобы не текли.
	if inst is Node:
		arena.add_child(inst)
	_run_instance(inst, arena, prepare_params(raw_params, arena))
	return true


## Держит экземпляр паттерна в памяти, пока работает его execute().
## Без этого RefCounted-объект освобождается сразу после запуска, и паттерн, ждущий в await, никогда не продолжится.
static func _run_instance(inst, arena, params: Dictionary) -> void:
	await inst.execute(arena, params)


# ---------------------------------------------------------------- спавн

## Мигающая точка-телеграф. Твин привязан к самой точке и умирает вместе с ней.
static func spawn_dot(arena, pos: Vector2, color: Color, scale_min: float = 0.3, scale_max: float = 0.6) -> Sprite2D:
	var dot := Sprite2D.new()
	dot.texture = DOT_TEXTURE
	dot.scale = Vector2(scale_min, scale_min)
	dot.modulate = color
	arena.add_child(dot)
	dot.global_position = pos
	var tween := dot.create_tween()
	tween.set_loops()
	tween.tween_property(dot, "scale", Vector2(scale_max, scale_max), 0.2)
	tween.tween_property(dot, "scale", Vector2(scale_min, scale_min), 0.2)
	return dot


static func spawn_bullet(arena, pos: Vector2, dir: Vector2, speed: float):
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = dir
	bullet.speed = speed
	arena.bullet_container.add_child(bullet)
	bullet.global_position = pos
	return bullet


static func make_line(arena, a: Vector2, b: Vector2, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.add_point(a)
	line.add_point(b)
	line.width = width
	line.default_color = color
	arena.add_child(line)
	return line


# ---------------------------------------------------------------- стороны экрана (wall, sakura)

static func side_geometry(side: String, viewport_size: Vector2) -> Dictionary:
	match side:
		"bottom":
			return {"length": viewport_size.x, "fixed": viewport_size.y, "dir": Vector2.UP, "horizontal": true}
		"left":
			return {"length": viewport_size.y, "fixed": 0.0, "dir": Vector2.RIGHT, "horizontal": false}
		"right":
			return {"length": viewport_size.y, "fixed": viewport_size.x, "dir": Vector2.LEFT, "horizontal": false}
	return {"length": viewport_size.x, "fixed": 0.0, "dir": Vector2.DOWN, "horizontal": true}


## Точка на стороне экрана: t — координата вдоль стороны, inset — отступ внутрь.
static func side_pos(t: float, geo: Dictionary, inset: float) -> Vector2:
	if geo["horizontal"]:
		var y: float
		if geo["dir"] == Vector2.DOWN:
			y = geo["fixed"] + inset
		else:
			y = geo["fixed"] - inset
		return Vector2(t, y)
	var x: float
	if geo["dir"] == Vector2.RIGHT:
		x = geo["fixed"] + inset
	else:
		x = geo["fixed"] - inset
	return Vector2(x, t)
