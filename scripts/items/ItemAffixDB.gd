extends Node

var _affixes: Dictionary = {}
var _by_category: Dictionary = {}  # affix_category -> Array[Dictionary]
var _by_item_type: Dictionary = {} # item_type -> Array[Dictionary]


func _ready() -> void:
	_scan_dir("res://data/item_affixes")


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			if fname != "." and fname != "..":
				_scan_dir(path + "/" + fname)
		elif fname.ends_with(".json"):
			_load_file(path + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ItemAffixDB: cannot open " + path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_index(parsed as Dictionary)
	else:
		push_error("ItemAffixDB: expected dict in " + path)


func _index(d: Dictionary) -> void:
	if not d.has("id"):
		return
	var id: String = str(d["id"])
	_affixes[id] = d

	var cat: String = str(d.get("affix_category", ""))
	if cat != "":
		if not _by_category.has(cat):
			_by_category[cat] = []
		(_by_category[cat] as Array).append(d)

	var types: Array = d.get("allowed_item_types", [])
	for itype: Variant in types:
		var key: String = str(itype)
		if not _by_item_type.has(key):
			_by_item_type[key] = []
		(_by_item_type[key] as Array).append(d)


# ── API pubblica ──────────────────────────────────────────────────────────────

func get_affix(affix_id: String) -> Dictionary:
	return _affixes.get(affix_id, {})


func get_display_name(affix_id: String, gender: String) -> String:
	var d: Dictionary = _affixes.get(affix_id, {})
	var field: String = "name_" + gender
	var raw: String = str(d.get(field, d.get("name_m", affix_id)))
	var suffix: String = "_M" if gender == "m" else "_F"
	return LocaleManager.t_or("ITEM_AFFIX_" + affix_id.to_upper() + suffix, raw)


# Returns all affixes applicable to item_type at the given level and quality tier.
func get_eligible(item_type: String, level: int, quality: String) -> Array:
	var candidates: Array = _by_item_type.get(item_type, [])
	var result: Array = []
	for affix: Variant in candidates:
		var d := affix as Dictionary
		if level < int(d.get("min_level", 0)):
			continue
		var allowed_tiers: Array = d.get("allowed_tiers", [])
		if allowed_tiers.is_empty() or quality in allowed_tiers:
			result.append(d)
	return result
