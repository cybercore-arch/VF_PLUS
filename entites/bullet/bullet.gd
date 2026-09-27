extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0

func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("die"):
		area.die()
	queue_free()
