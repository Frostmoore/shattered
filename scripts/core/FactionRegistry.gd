extends Node

const DATA_ROOT := "res://data/factions/"

var _factions: Dictionary = {}  # id → Dictionary
var _relations: Dictionary = {} # faction_id → {faction_id → int}


func _ready() -> void:
	_scan_directory(DATA_ROOT)
	_load_relations()
	print("FactionRegistry: caricate %d fazioni" % _factions.size())


func _scan_directory(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_error("FactionRegistry: directory non trovata: " + path)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			_scan_directory(path + entry + "/")
		elif entry.ends_with(".json") and entry != "relations.json":
			_load_file(path + entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("FactionRegistry: impossibile aprire " + path)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("FactionRegistry: JSON non valido in " + path)
		return
	var data: Dictionary = parsed as Dictionary
	var id: String = str(data.get("id", ""))
	if id == "":
		push_error("FactionRegistry: campo 'id' mancante in " + path)
		return
	_factions[id] = data


func _load_relations() -> void:
	var path: String = DATA_ROOT + "relations.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_relations = parsed as Dictionary


# ── API pubblica ──────────────────────────────────────────────────────────────

func get_faction(id: String) -> Dictionary:
	return _factions.get(id, {})


func get_all_factions() -> Array:
	return _factions.values()


func get_factions_by_type(type: String) -> Array:
	var result: Array = []
	for data: Dictionary in _factions.values():
		if str(data.get("type", "")) == type:
			result.append(data)
	return result


func get_factions_by_tier(tier: String) -> Array:
	var result: Array = []
	for data: Dictionary in _factions.values():
		if str(data.get("tier", "")) == tier:
			result.append(data)
	return result


func get_factions_by_tree(tree_id: String) -> Array:
	var result: Array = []
	for data: Dictionary in _factions.values():
		if str(data.get("tree", "")) == tree_id:
			result.append(data)
	return result


func get_relations() -> Dictionary:
	return _relations


func get_relation(from_id: String, to_id: String) -> int:
	var from_rel: Variant = _relations.get(from_id, {})
	if from_rel is Dictionary:
		return int((from_rel as Dictionary).get(to_id, 0))
	return 0


func are_enemies(fac_a: String, fac_b: String) -> bool:
	return get_relation(fac_a, fac_b) <= -50 or get_relation(fac_b, fac_a) <= -50


func get_faction_children(parent_id: String) -> Array:
	var result: Array = []
	for data: Dictionary in _factions.values():
		if str(data.get("parent", "")) == parent_id:
			result.append(data)
	return result


func get_siblings(faction_id: String) -> Array:
	var data: Dictionary = get_faction(faction_id)
	var parent_id: String = str(data.get("parent", ""))
	if parent_id == "":
		return []
	var result: Array = []
	for other: Dictionary in _factions.values():
		if str(other.get("parent", "")) == parent_id and str(other.get("id", "")) != faction_id:
			result.append(other)
	return result
