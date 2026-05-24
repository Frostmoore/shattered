@tool
extends RefCounted

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

	var valid_archetypes: Dictionary = {}
	var archetype_dir := DirAccess.open("res://data/loot/archetypes/")
	if archetype_dir != null:
		archetype_dir.list_dir_begin()
		var dname := archetype_dir.get_next()
		while dname != "":
			if archetype_dir.current_is_dir() and not dname.begins_with("."):
				valid_archetypes[dname] = true
			dname = archetype_dir.get_next()
		archetype_dir.list_dir_end()
	else:
		warnings.append("Impossibile aprire data/loot/archetypes/ — check archetipo saltato")

	var files: Array[String] = _collect_json_files("res://data/classes/")
	var class_count: int = 0

	for path in files:
		var data: Variant = _load_json(path)
		if data == null or not (data is Dictionary):
			errors.append("Cannot parse: %s" % path)
			continue
		var d := data as Dictionary
		class_count += 1
		_check_class(d, path, valid_archetypes, errors, warnings)

	return { "title": "Classi", "checked": class_count, "unit": "classe",
			 "errors": errors, "warnings": warnings }


func _check_class(d: Dictionary, path: String, valid_archetypes: Dictionary,
		errors: Array[String], warnings: Array[String]) -> void:
	var id: String = d.get("id", "")
	if id.is_empty():
		errors.append("Missing 'id' in %s" % path)
		return
	var label: String = "[%s]" % id

	if id == "noob":
		var special: String = d.get("special_id", "")
		if special != "noob_adaptability":
			errors.append("%s deve avere special_id='noob_adaptability', trovato '%s'" % [label, special])
		return

	var ait: Variant = d.get("allowed_item_types", null)
	if ait == null or not (ait is Array):
		errors.append("%s manca 'allowed_item_types'" % label)
	elif (ait as Array).is_empty():
		errors.append("%s 'allowed_item_types' vuoto" % label)
	else:
		for it in ait:
			if not VALID_ITEM_TYPES.has(str(it)):
				errors.append("%s item_type sconosciuto: '%s'" % [label, str(it)])

	var archetype: String = d.get("loot_archetype", "")
	if archetype.is_empty():
		errors.append("%s manca 'loot_archetype'" % label)
	elif not valid_archetypes.is_empty() and not valid_archetypes.has(archetype):
		errors.append("%s loot_archetype '%s' non ha cartella in data/loot/archetypes/" % [label, archetype])

	if not d.has("tier"):
		warnings.append("%s manca 'tier'" % label)
	if not d.has("growth"):
		warnings.append("%s manca 'growth'" % label)
	if not d.has("special_id"):
		warnings.append("%s manca 'special_id'" % label)
	if not d.has("unlock"):
		warnings.append("%s manca 'unlock' — classe non sbloccabile" % label)


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
