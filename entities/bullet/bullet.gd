extends Area2D

const OFF_SCREEN_MARGIN: float = 300.0

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	global_position += direction * speed * delta
	# Пуля, созданная за экраном, не вызовет screen_exited: убираем ушедшие далеко от экрана.
	if not get_viewport_rect().grow(OFF_SCREEN_MARGIN).has_point(global_position):
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("die"):
		area.die()
	queue_free()
