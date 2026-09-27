extends Control

@onready var main_view: VBoxContainer = $main_view
@onready var levels_view: VBoxContainer = $levels_view
@onready var level_list: VBoxContainer = $levels_view/scroll/level_list
@onready var title_label: Label = $levels_view/title_label

func _ready() -> void:
	show_main_menu()
	
	$main_view/btn_official.pressed.connect(_on_official_pressed)
	$main_view/btn_custom.pressed.connect(_on_custom_pressed)
	$main_view/btn_endless.pressed.connect(_on_endless_pressed)
	$main_view/btn_exit.pressed.connect(_on_exit_pressed)
	$levels_view/btn_back.pressed.connect(show_main_menu)

func show_main_menu() -> void:
	main_view.visible = true
	levels_view.visible = false

func open_level_selection(category: String, title_text: String) -> void:
	main_view.visible = false
	levels_view.visible = true
	title_label.text = title_text
	
	for child in level_list.get_children():
		child.queue_free()
		
	var levels = GameManager.get_levels(category)
	
	if levels.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No levels found!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_list.add_child(empty_label)
		return
		
	for path in levels:
		var btn = Button.new()
		btn.text = path.get_file().get_basename()
		btn.pressed.connect(func(): GameManager.start_level(path))
		level_list.add_child(btn)

func _on_official_pressed() -> void:
	open_level_selection("official", "Official Levels")

func _on_custom_pressed() -> void:
	open_level_selection("custom", "Custom Levels")

func _on_endless_pressed() -> void:
	open_level_selection("endless", "Endless Modes")

func _on_exit_pressed() -> void:
	get_tree().quit()
