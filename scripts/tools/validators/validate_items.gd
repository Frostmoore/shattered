@tool
extends RefCounted

const VALID_CATEGORIES := [
	"weapon", "armor", "accessory", "consumable", "key_item", "class_license"
]
const VALID_ITEM_TYPES := [
	"spada", "ascia", "mazza", "pugnale", "bacchetta", "sfera", "simbolo_sacro",
	"totem", "libro_arcano", "spadone", "ascia_bipenne", "martello_guerra",
	"bastone", "arco", "balestra", "lancia",
	"armatura_leggera", "armatura_media", "armatura_pesante", "veste",
	"elmo", "stivali", "bracciali", "scudo", "anello", "amuleto", "accessorio"
]
const VALID_QUALITIES  := ["normale", "magico", "raro", "epico", "leggendario", "unico"]
const LEGACY_TYPES     := ["equipment", "consumable", "class_license"]


func run() -> Dictionary:
	var errors:   Array[String] = []
	var warnings: Array[String] = []
	var ids: Dictionary = {}

	var new_files: Array[String] = _collect_json_files("res://data/items/")
	for path in new_files:
		if path.ends_with("items.json"):
			continue
		var data: Variant = _load_json(path)
		if data == null or not (data is Dictionary):
			errors.append("Cannot parse: %s" % path)
			continue
		var d := data as Dictionary
		var id: String = d.get("id", "")
		if id.is_empty():
			errors.append("Missing 'id' in %s" % path)
			continue
		if ids.has(id):
			errors.append("Duplicate id '%s' (also in %s)" % [id, ids[id]])
		else:
			ids[id] = path
		_check_new_item(id, d, errors, warnings)

	var legacy: Variant = _load_json("res://data/items/items.json")
	if legacy is Array:
		for entry in legacy:
			if not (entry is Dictionary):
				continue
			var d := entry as Dictionary
			var id: String = d.get("id", "")
			if id.is_empty():
				errors.append("Legacy item missing 'id'")
				continue
			if ids.has(id):
				errors.append("Duplicate id '%s' in items.json (first: %s)" % [id, ids[id]])
			else:
				ids[id] = "items.json"
			_check_legacy_item(id, d, errors)

	return { "title": "Items", "checked": ids.size(), "unit": "item",
			 "errors": errors, "warnings": warnings }


func _check_new_item(id: String, d: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	var cat: String = d.get("item_category", "")
	if not VALID_CATEGORIES.has(cat):
		errors.append("[%s] invalid item_category: '%s'" % [id, cat])
		return
	if cat in ["weapon", "armor", "accessory"]:
		var itype: String = d.get("item_type", "")
		if not VALID_ITEM_TYPES.has(itype):
			errors.append("[%s] invalid item_type: '%s'" % [id, itype])
		if not d.has("slot") and not d.has("allowed_slots") and not d.get("both_hands", false):
			errors.append("[%s] equippable missing 'slot' o 'allowed_slots'" % id)
		if not d.has("base_stats"):
			warnings.append("[%s] missing 'base_stats'" % id)
	if d.get("scalable", false):
		if not d.has("scale"):
			errors.append("[%s] scalable=true but missing 'scale'" % id)
		if not d.has("scaling_mode"):
			errors.append("[%s] scalable=true but missing 'scaling_mode'" % id)
	var qo: String = d.get("quality_override", "")
	if qo != "" and not VALID_QUALITIES.has(qo):
		errors.append("[%s] invalid quality_override: '%s'" % [id, qo])
	if cat == "consumable" and not d.has("effect"):
		errors.append("[%s] consumable missing 'effect'" % id)
	if cat == "key_item":
		if d.get("droppable", true):
			warnings.append("[%s] key_item should have droppable: false" % id)
		if d.get("sellable", true):
			warnings.append("[%s] key_item should have sellable: false" % id)


func _check_legacy_item(id: String, d: Dictionary, errors: Array[String]) -> void:
	var type: String = d.get("type", "")
	if not LEGACY_TYPES.has(type):
		errors.append("[legacy:%s] unknown type: '%s'" % [id, type])
	if type == "equipment" and not d.has("slot"):
		errors.append("[legacy:%s] equipment missing 'slot'" % id)
	if type == "consumable" and not d.has("effect"):
		errors.append("[legacy:%s] consumable missing 'effect'" % id)


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
