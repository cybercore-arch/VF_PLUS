extends Node

var current_level_path: String = ""

func start_level(path: String) -> void:
	current_level_path = path
	get_tree().change_scene_to_file("res://entites/arena/arena.tscn")

func scan_folder(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	if folder_path.is_empty():
		return result
	var dir = DirAccess.open(folder_path)
	if not dir:
		return result
	
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			result.append(folder_path.path_join(file_name))
	
	return result

func get_levels(category: String) -> Array[String]:
	var official_path = "res://levels/"
	# В редакторе внешняя папка — корень проекта, в экспорте — папка рядом с игрой.
	var custom_path = PatternUtil.external_base_dir().path_join("levels")
	# В редакторе custom_path указывает на ту же папку, что и res://levels/: второй раз её не сканируем.
	if custom_path.simplify_path().trim_suffix("/") == ProjectSettings.globalize_path(official_path).simplify_path().trim_suffix("/"):
		custom_path = ""
	
	var list: Array[String] = []
	
	match category:
		"official":
			for path in scan_folder(official_path):
				var file = path.get_file()
				var is_test = file.to_lower().contains("test")
				var is_endless = file.contains("ENDLS")
				if not is_test and not is_endless:
					list.append(path)
					
		"custom":
			for path in scan_folder(official_path):
				var file = path.get_file()
				if file.to_lower().contains("test") and not file.contains("ENDLS"):
					list.append(path)
			for path in scan_folder(custom_path):
				var file = path.get_file()
				if not file.contains("ENDLS"):
					list.append(path)
					
		"endless":
			var all_files = scan_folder(official_path) + scan_folder(custom_path)
			for path in all_files:
				var file = path.get_file()
				if file.contains("ENDLS"):
					list.append(path)
					
	return list
