extends Node

const CLASS_DATA_ROOT := "res://data/classes/"
const TIER_DIRS       := ["tier1", "tier2", "tier3", "tier4", "tier5", "tier6"]

var _classes: Dictionary = {}  # id → data Dictionary


func _ready() -> void:
	_load_all()
	ClassValidator.validate(_classes)


func _load_all() -> void:
	for tier_dir: String in TIER_DIRS:
		var path: String = CLASS_DATA_ROOT + tier_dir + "/"
		var dir: DirAccess = DirAccess.open(path)
		if dir == null:
			push_error("ClassRegistry: directory non trovata: " + path)
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".json"):
				_load_file(path + entry)
			entry = dir.get_next()
		dir.list_dir_end()
	print("ClassRegistry: caricate %d classi" % _classes.size())


func _load_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ClassRegistry: impossibile aprire " + path)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("ClassRegistry: JSON non valido in " + path)
		return
	var data: Dictionary = parsed as Dictionary
	var id: String = str(data.get("id", ""))
	if id == "":
		push_error("ClassRegistry: id mancante in " + path)
		return
	_classes[id] = data


# ── API pubblica ──────────────────────────────────────────────────────────────

func get_class_data(id: String) -> Dictionary:
	return _classes.get(id, {})


func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tier: int in range(1, 7):
		for data: Dictionary in _classes.values():
			if int(data.get("tier", 0)) == tier:
				result.append(data)
	return result


func get_by_tier(tier: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for data: Dictionary in _classes.values():
		if int(data.get("tier", 0)) == tier:
			result.append(data)
	return result


func get_implemented() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for data: Dictionary in _classes.values():
		var impl: Variant = data.get("implementation", {})
		if impl is Dictionary and (impl as Dictionary).get("status", "") == "implemented":
			result.append(data)
	return result


func has_class_id(id: String) -> bool:
	return _classes.has(id)
