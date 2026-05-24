@tool
extends RefCounted

const VALID_TYPES := ["prefix", "suffix"]
const VALID_TIERS := ["magico", "raro", "epico", "leggendario"]
const VALID_ITEM_TYPES := [
	"spada", "ascia", "mazza", "pugnale", "bacchetta", "sfera", "simbolo_sacro",
	"totem", "libro_arcano", "spadone", "ascia_bipenne", "martello_guerra",
	"bastone", "arco", "balestra", "lancia",
	"armatura_leggera", "armatura_media", "armatura_pesante", "veste",
	"elmo", "stivali", "bracciali", "scudo", "anello", "amuleto", "accessorio"
]


func run() -> Dictionary:
	var errors:   Array[String] = []
	var warnings: Array[String] = []
	var ids: Dictionary = {}

	var files: Array[String] = _collect_json_files("res://data/item_affixes/")
	for path in files:
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
		_check_affix(id, d, errors, warnings)

	return { "title": "Affissi", "checked": ids.size(), "unit": "affisso",
			 "errors": errors, "warnings": warnings }


func _check_affix(id: String, d: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	var type: String = d.get("type", "")
	if not VALID_TYPES.has(type):
		errors.append("[%s] type non valido: '%s'" % [id, type])

	var ait: Variant = d.get("allowed_item_types", null)
	if ait == null or not (ait is Array):
		errors.append("[%s] missing 'allowed_item_types'" % id)
	elif (ait as Array).is_empty():
		errors.append("[%s] 'allowed_item_types' vuoto" % id)
	else:
		for it in ait:
			if not VALID_ITEM_TYPES.has(str(it)):
				errors.append("[%s] item_type sconosciuto in allowed_item_types: '%s'" % [id, str(it)])

	var at: Variant = d.get("allowed_tiers", null)
	if at == null or not (at is Array):
		errors.append("[%s] missing 'allowed_tiers'" % id)
	elif (at as Array).is_empty():
		errors.append("[%s] 'allowed_tiers' vuoto" % id)
	else:
		for tier in at:
			if not VALID_TIERS.has(str(tier)):
				errors.append("[%s] tier sconosciuto in allowed_tiers: '%s'" % [id, str(tier)])

	var bonuses: Variant = d.get("bonuses", null)
	if bonuses == null or not (bonuses is Dictionary) or (bonuses as Dictionary).is_empty():
		errors.append("[%s] 'bonuses' mancante o vuoto" % id)

	if int(d.get("weight", 0)) <= 0:
		warnings.append("[%s] weight ≤ 0 — affisso mai droppato" % id)
	if not d.has("min_level"):
		warnings.append("[%s] missing 'min_level'" % id)


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
