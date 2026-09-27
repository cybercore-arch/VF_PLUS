extends Area2D

signal died


var screen_size: Vector2
var is_alive: bool = true
var target_position = global_position
var smoothness: float = 25.0

func _ready() -> void:
	screen_size = get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if not is_alive:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		target_position += event.relative
		target_position = target_position.clamp(Vector2(20, 20), screen_size - Vector2(20, 20))

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	var distance_to_target = global_position.distance_to(target_position)
	
	var speed = clamp(distance_to_target * smoothness, 0.0, 3500.0)
	
	global_position = global_position.move_toward(target_position, speed * delta)

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	modulate.a = 0.5  
	died.emit()       
