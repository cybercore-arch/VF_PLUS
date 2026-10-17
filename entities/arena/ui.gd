extends CanvasLayer
## Скрипт на узле UI. У UI process_mode = ALWAYS, поэтому он получает ввод и на паузе —
## в отличие от арены, которая на паузе ввод не получает.

signal pause_toggle_requested

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		pause_toggle_requested.emit()
		get_viewport().set_input_as_handled()
