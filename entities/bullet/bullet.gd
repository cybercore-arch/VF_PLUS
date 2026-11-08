extends Area2D

# Пуля, созданная за экраном, не вызовет screen_exited, поэтому убираем ушедшие далеко от экрана.
const OFF_SCREEN_MARGIN: float = 300.0

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0

var _bounds: Rect2

func _ready() -> void:
	# Размер берём из настроек проекта, а не из вьюпорта: так он не зависит от окна и от момента вызова.
	var w: float = ProjectSettings.get_setting("display/window/size/viewport_width", 1280)
	var h: float = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
	_bounds = Rect2(Vector2.ZERO, Vector2(w, h)).grow(OFF_SCREEN_MARGIN)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	global_position += direction * speed * delta
	if not _bounds.has_point(global_position):
		queue_free()

## Вызывается, когда пулю уничтожает что-то другое (например, лазер).
func destroy() -> void:
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("die"):
		area.die()
	queue_free()
