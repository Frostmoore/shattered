extends Node

const AFFIX_DATA_ROOT := "res://data/affixes/"

var _affixes: Dictionary = {}  # id → data Dictionary


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir: DirAccess = DirAccess.open(AFFIX_DATA_ROOT)
	if dir == null:
		push_error("AffixRegistry: directory non trovata: " + AFFIX_DATA_ROOT)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			_load_file(AFFIX_DATA_ROOT + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	print("AffixRegistry: caricati %d affissi" % _affixes.size())


func _load_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("AffixRegistry: impossibile aprire " + path)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("AffixRegistry: JSON non valido in " + path)
		return
	var data: Dictionary = parsed as Dictionary
	var id: String = str(data.get("id", ""))
	if id == "":
		push_error("AffixRegistry: campo 'id' mancante in " + path)
		return
	_affixes[id] = data


# ── API pubblica ──────────────────────────────────────────────────────────────

func get_affix(id: String) -> Dictionary:
	return _affixes.get(id, {})


func get_display_prefix(id: String) -> String:
	var raw: String = str(_affixes.get(id, {}).get("prefix", ""))
	return LocaleManager.t_or("ENEMY_AFFIX_" + id.to_upper() + "_PREFIX", raw)


func get_all() -> Array:
	return _affixes.values()


## Returns affixes eligible for a given floor and enemy family.
## compatible_families: [] means compatible with all families.
func get_eligible(floor_num: int, family: String) -> Array:
	var result: Array = []
	for entry: Variant in _affixes.values():
		var a: Dictionary = entry as Dictionary
		if int(a.get("min_floor", 1)) > floor_num:
			continue
		var cf: Array = a.get("compatible_families", []) as Array
		if cf.size() > 0 and not cf.has(family):
			continue
		result.append(a)
	return result
