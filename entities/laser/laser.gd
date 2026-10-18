extends Area2D
## Лазер. Живёт по фазам:
##   WARN   — тусклая безопасная линия «здесь будет лазер»
##   GROW   — линия быстро утолщается и разгорается
##   ACTIVE — яркий луч, убивает при касании
##   FADE   — луч сужается и исчезает, после чего лазер удаляется
##
## Лазер идёт от своей позиции вдоль своей оси X (поворачивай через rotation).
## Создавать удобнее через PatternUtil.spawn_laser(arena, pos, angle, opts).
## Время считается из delta физического кадра, поэтому пауза его останавливает.

enum Phase { WARN, GROW, ACTIVE, FADE }

var length: float = 2500.0       # длина луча, пиксели (с запасом, чтобы выходил за экран)
var width: float = 28.0          # толщина яркого луча
var warn_width: float = 4.0      # толщина тусклой линии
var warn_time: float = 1.0
var grow_time: float = 0.1
var active_time: float = 0.4
var fade_time: float = 0.15
var color: Color = Color(1.0, 0.2, 0.3)
var core_color: Color = Color(1.0, 1.0, 1.0)  # светлая сердцевина яркого луча
var warn_alpha: float = 0.3      # прозрачность тусклой линии
var hit_scale: float = 0.8       # хитбокс = width * hit_scale (чуть мягче, чем выглядит)

var phase: Phase = Phase.WARN
var _t: float = 0.0

@onready var _glow: Line2D = $Glow
@onready var _core: Line2D = $Core
@onready var _hitbox: CollisionShape2D = $CollisionShape2D


## Применяет параметры из словаря (вызывать до add_child). Неизвестные ключи игнорируются.
func configure(opts: Dictionary) -> void:
	length = float(opts.get("length", length))
	width = float(opts.get("width", width))
	warn_width = float(opts.get("warn_width", warn_width))
	warn_time = float(opts.get("warn_time", warn_time))
	grow_time = float(opts.get("grow_time", grow_time))
	active_time = float(opts.get("active_time", active_time))
	fade_time = float(opts.get("fade_time", fade_time))
	warn_alpha = float(opts.get("warn_alpha", warn_alpha))
	hit_scale = float(opts.get("hit_scale", hit_scale))
	color = PatternUtil.to_color(opts.get("color"), color)
	core_color = PatternUtil.to_color(opts.get("core_color"), core_color)


## Сколько всего живёт лазер от появления до удаления.
func total_time() -> float:
	return warn_time + grow_time + active_time + fade_time


func _ready() -> void:
	_glow.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
	_core.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, maxf(width * hit_scale, 1.0))
	_hitbox.shape = rect
	_hitbox.position = Vector2(length * 0.5, 0.0)
	_hitbox.disabled = true
	_update_visuals()


func _physics_process(delta: float) -> void:
	_t += delta
	while _t >= _duration(phase):
		_t -= _duration(phase)
		if phase == Phase.FADE:
			queue_free()
			return
		phase = (phase + 1) as Phase
		_hitbox.set_deferred("disabled", phase != Phase.ACTIVE)
	_update_visuals()
	if phase == Phase.ACTIVE:
		for a in get_overlapping_areas():
			if a.has_method("die"):
				a.die()


func _duration(p: Phase) -> float:
	match p:
		Phase.WARN:
			return warn_time
		Phase.GROW:
			return grow_time
		Phase.ACTIVE:
			return active_time
	return fade_time


func _update_visuals() -> void:
	var w: float = warn_width
	var a: float = warn_alpha
	match phase:
		Phase.WARN:
			# лёгкое мерцание, чтобы линия читалась как предупреждение
			a = warn_alpha * (0.8 + 0.2 * sin(_t * 18.0))
		Phase.GROW:
			var k: float = clampf(_t / maxf(grow_time, 0.0001), 0.0, 1.0)
			w = lerpf(warn_width, width, k)
			a = lerpf(warn_alpha, 1.0, k)
		Phase.ACTIVE:
			w = width
			a = 1.0
		Phase.FADE:
			var k2: float = clampf(_t / maxf(fade_time, 0.0001), 0.0, 1.0)
			w = width * (1.0 - k2)
			a = 1.0 - k2
	_glow.width = w
	_glow.default_color = Color(color.r, color.g, color.b, a * color.a)
	_core.visible = phase != Phase.WARN
	_core.width = w * 0.45
	_core.default_color = Color(core_color.r, core_color.g, core_color.b, a * core_color.a)
