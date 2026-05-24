extends Node

var _items: Dictionary = {}
var _by_type: Dictionary = {}     # item_type -> Array[Dictionary]
var _by_category: Dictionary = {} # item_category -> Array[Dictionary]
var _by_slot: Dictionary = {}     # slot -> Array[Dictionary]


func _ready() -> void:
	_scan_dir("res://data/items")


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
		push_error("ItemDB: cannot open " + path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for item: Variant in (parsed as Array):
			if item is Dictionary:
				_index(item as Dictionary)
	elif parsed is Dictionary:
		_index(parsed as Dictionary)
	else:
		push_error("ItemDB: unexpected format in " + path)


func _index(d: Dictionary) -> void:
	if not d.has("id"):
		return
	var id: String = str(d["id"])
	_items[id] = d

	var itype: String = str(d.get("item_type", ""))
	if itype != "":
		if not _by_type.has(itype):
			_by_type[itype] = []
		(_by_type[itype] as Array).append(d)

	# Support both new "item_category" and legacy "type" field
	var cat: String = str(d.get("item_category", d.get("type", "")))
	if cat != "":
		if not _by_category.has(cat):
			_by_category[cat] = []
		(_by_category[cat] as Array).append(d)

	var slot: String = str(d.get("slot", ""))
	if slot != "":
		if not _by_slot.has(slot):
			_by_slot[slot] = []
		(_by_slot[slot] as Array).append(d)


# ── API pubblica ──────────────────────────────────────────────────────────────

func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {})


func get_display_name(item_id: String) -> String:
	var raw: String = str(_items.get(item_id, {}).get("name", item_id))
	return LocaleManager.t_or("ITEM_" + item_id.to_upper() + "_NAME", raw)


func get_display_description(item_id: String) -> String:
	var raw: String = str(_items.get(item_id, {}).get("description", ""))
	return LocaleManager.t_or("ITEM_" + item_id.to_upper() + "_DESC", raw)


func get_by_type(item_type: String) -> Array:
	return _by_type.get(item_type, [])


func get_by_slot(slot: String) -> Array:
	return _by_slot.get(slot, [])


# Picks a random item template from a category, valid at the given level.
# Uses loot_weight for weighted selection.
# min_quality is stored in the result as "_min_quality" for callers (e.g. ItemGenerator).
func pick_random(category: String, level: int, min_quality: String = "") -> Dictionary:
	var pool: Array = _by_category.get(category, [])
	var eligible: Array = []
	var total_weight: int = 0
	for item: Variant in pool:
		var d := item as Dictionary
		var min_lv: int = int(d.get("min_level", 0))
		var max_lv: int = int(d.get("max_level", 9999))
		if level >= min_lv and level <= max_lv:
			eligible.append(d)
			total_weight += int(d.get("loot_weight", 1))
	if eligible.is_empty():
		return {}
	var roll: int = randi() % max(total_weight, 1)
	var acc: int = 0
	for item: Variant in eligible:
		var d := item as Dictionary
		acc += int(d.get("loot_weight", 1))
		if roll < acc:
			if min_quality != "":
				var result := d.duplicate()
				result["_min_quality"] = min_quality
				return result
			return d
	# Fallback (floating-point rounding edge case)
	var last := eligible[-1] as Dictionary
	if min_quality != "":
		var result := last.duplicate()
		result["_min_quality"] = min_quality
		return result
	return last
