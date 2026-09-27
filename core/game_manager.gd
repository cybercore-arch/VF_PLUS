extends Node

var current_level_path: String = ""

func start_level(path: String) -> void:
	current_level_path = path
	get_tree().change_scene_to_file("res://entites/arena/arena.tscn")

func scan_folder(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(folder_path)
	if not dir:
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			result.append(folder_path.path_join(file_name))
		file_name = dir.get_next()
	
	return result

func get_levels(category: String) -> Array[String]:
	var official_path = "res://levels/"
	var custom_path = OS.get_executable_path().get_base_dir().path_join("levels")
	
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
