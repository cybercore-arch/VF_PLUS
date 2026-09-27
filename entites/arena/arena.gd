extends Node2D

@onready var bullet_container: Node2D = $bullet_container
@onready var pause_menu: VBoxContainer = $UI/pause_menu
@onready var restart_menu: VBoxContainer = $UI/restart_menu
@onready var timer_label: Label = $UI/timer_label

var survival_time: float = 0.0
var is_game_over: bool = false

func _ready() -> void:
	pause_menu.visible = false
	restart_menu.visible = false
	get_tree().paused = false
	survival_time = 0.0
	
	$UI/pause_menu/btn_resume.pressed.connect(toggle_pause)
	$UI/pause_menu/btn_pause_restart.pressed.connect(restart_level)
	$UI/pause_menu/btn_pause_menu.pressed.connect(go_to_menu)
	# $UI/restart_menu/btn_death_menu.pressed.connect(go_to_menu)
	$UI/restart_menu/btn_death_restart.pressed.connect(restart_level)
	
	if $UI/restart_menu.has_node("btn_death_menu"):
		$UI/restart_menu/btn_death_menu.pressed.connect(go_to_menu) 
	
	if has_node("player"):
		$player.died.connect(_on_player_died)
	
	if GameManager.current_level_path != "":
		$pattern_manager.load_level(GameManager.current_level_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not is_game_over:
			toggle_pause()

func toggle_pause() -> void:
	var new_state = not get_tree().paused
	get_tree().paused = new_state
	pause_menu.visible = new_state

func _on_player_died() -> void:
	is_game_over = true
	get_tree().paused = true
	restart_menu.visible = true

func restart_level() -> void:
	get_tree().paused = false
	GameManager.start_level(GameManager.current_level_path)

func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _process(delta: float) -> void:
	if not is_game_over and not get_tree().paused:
		survival_time += delta
		
		var total_secs: int = int(survival_time)
		var minutes: int = total_secs / 60
		var seconds: int = total_secs % 60
		var centiseconds: int = int(fmod(survival_time, 1.0) * 100)
		
		timer_label.text = "%02d:%02d:%02d" % [minutes, seconds, centiseconds]
