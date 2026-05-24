@tool
extends RefCounted

const CHEST_VARIANTS    := ["comune", "ricca", "abbondante", "boss", "segreto"]
const MAX_NOTHING_CHEST := 10


func run() -> Dictionary:
	var errors:   Array[String] = []
	var warnings: Array[String] = []

	var known_ids: Dictionary = _collect_all_item_ids()
	var loot_files: Array[String] = _collect_json_files("res://data/loot/")
	var chest_count: int = 0

	for path in loot_files:
		var data: Variant = _load_json(path)
		if data == null or not (data is Dictionary):
			errors.append("Cannot parse: %s" % path)
			continue
		var d := data as Dictionary
		var is_chest: bool = path.get_file() == "chest.json"
		if is_chest:
			chest_count += 1
			_check_chest(d, path, known_ids, errors, warnings)
		elif d.has("level_bands"):
			_check_level_bands(d["level_bands"] as Array, path, known_ids, false, errors, warnings)

	return { "title": "Loot Tables", "checked": loot_files.size(),
			 "unit": "file (%d chest)" % chest_count,
			 "errors": errors, "warnings": warnings }


func _check_chest(d: Dictionary, path: String, known_ids: Dictionary,
		errors: Array[String], warnings: Array[String]) -> void:
	for v in CHEST_VARIANTS:
		if not d.has(v):
			errors.append("[%s] variante mancante: '%s'" % [path.get_file(), v])
		else:
			var variant := d[v] as Dictionary
			if not variant.has("rolls_min") or not variant.has("rolls_max"):
				errors.append("[%s][%s] manca rolls_min/rolls_max" % [path.get_file(), v])
			if not variant.has("guaranteed") or not (variant["guaranteed"] is Array):
				errors.append("[%s][%s] manca array 'guaranteed'" % [path.get_file(), v])
	if not d.has("level_bands"):
		errors.append("[%s] manca 'level_bands'" % path.get_file())
		return
	_check_level_bands(d["level_bands"] as Array, path, known_ids, true, errors, warnings)


func _check_level_bands(bands: Array, path: String, known_ids: Dictionary,
		is_chest: bool, errors: Array[String], warnings: Array[String]) -> void:
	if bands.is_empty():
		errors.append("[%s] 'level_bands' vuoto" % path.get_file())
		return
	var prev_max: int = 0
	for i in bands.size():
		var band := bands[i] as Dictionary
		var lmin: int = int(band.get("level_min", -1))
		var lmax: int = int(band.get("level_max", -1))
		if lmin != prev_max + 1:
			errors.append("[%s] banda %d: gap — atteso level_min=%d, trovato %d" % [
				path.get_file(), i, prev_max + 1, lmin])
		prev_max = lmax
		var pool: Array = band.get("pool", []) as Array
		if pool.is_empty():
			warnings.append("[%s] banda %d: pool vuoto" % [path.get_file(), i])
			continue
		var nothing_w: int = 0
		for entry in pool:
			if not (entry is Dictionary):
				continue
			var e := entry as Dictionary
			if e.has("item_id"):
				var item_id: String = str(e["item_id"])
				if not known_ids.has(item_id):
					errors.append("[%s] banda %d: item_id sconosciuto '%s'" % [path.get_file(), i, item_id])
			if e.get("nothing", false):
				nothing_w += int(e.get("weight", 0))
		if is_chest and nothing_w > MAX_NOTHING_CHEST:
			warnings.append("[%s] banda %d: nothing weight=%d > %d (chest)" % [
				path.get_file(), i, nothing_w, MAX_NOTHING_CHEST])
	if prev_max != 999:
		errors.append("[%s] ultima banda deve finire a 999, trovato %d" % [path.get_file(), prev_max])


func _collect_all_item_ids() -> Dictionary:
	var ids: Dictionary = {}
	for path in _collect_json_files("res://data/items/"):
		var data: Variant = _load_json(path)
		if data == null:
			continue
		if data is Dictionary:
			var id: String = (data as Dictionary).get("id", "")
			if not id.is_empty():
				ids[id] = true
		elif data is Array:
			for entry in data:
				if entry is Dictionary:
					var id: String = (entry as Dictionary).get("id", "")
					if not id.is_empty():
						ids[id] = true
	return ids


func _collect_json_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir() and not fname.begins_with("."):
			files.append_array(_collect_json_files(path + fname + "/"))
		elif fname.ends_with(".json"):
			files.append(path + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return files


func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)
