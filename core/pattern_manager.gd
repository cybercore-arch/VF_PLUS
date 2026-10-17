extends Node

class_name PatternManager

@export var arena: Node2D

var current_time: float = 0.0
var is_playing: bool = false
var timeline: Array = []
var next_event_index: int = 0

func load_level(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Файл не найден: " + path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть уровень: " + path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not (data.get("events") is Array):
		push_error("Некорректный уровень (нужен объект с массивом events): " + path)
		return

	timeline = _sorted_events(data["events"])
	current_time = 0.0
	next_event_index = 0
	is_playing = true
	print("level loaded:", timeline.size())

## События идут по возрастанию time. Если в JSON одно «опоздало» в записи, оно не блокирует остальные.
## При равном time сохраняется порядок из файла.
func _sorted_events(raw_events: Array) -> Array:
	var indexed: Array = []
	for i in raw_events.size():
		var e = raw_events[i]
		if e is Dictionary:
			indexed.append({"i": i, "time": float(e.get("time", 0.0)), "event": e})
		else:
			push_warning("Событие #%d пропущено: это не объект" % i)
	indexed.sort_custom(func(a, b):
		if a["time"] == b["time"]:
			return a["i"] < b["i"]
		return a["time"] < b["time"])
	var result: Array = []
	for item in indexed:
		result.append(item["event"])
	return result

func _trigger_event(event_data: Dictionary) -> void:
	var pattern_name: String = str(event_data.get("pattern", ""))
	var params = event_data.get("params", {})
	if not (params is Dictionary):
		params = {}
	PatternUtil.run_pattern(pattern_name, arena, params)

func _process(delta: float) -> void:
	if not is_playing:
		return
	current_time += delta
	while next_event_index < timeline.size() and current_time >= float(timeline[next_event_index].get("time", 0.0)):
		_trigger_event(timeline[next_event_index])
		next_event_index += 1
	if next_event_index >= timeline.size():
		is_playing = false
		print("end")
