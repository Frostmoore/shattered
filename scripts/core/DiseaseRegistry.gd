extends Node

var _defs: Dictionary = {}


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir := DirAccess.open("res://data/diseases/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var f := FileAccess.open("res://data/diseases/" + fname, FileAccess.READ)
			if f:
				var result: Variant = JSON.parse_string(f.get_as_text())
				if result is Dictionary:
					var def: Dictionary = result as Dictionary
					var did: String = str(def.get("id", ""))
					if did != "":
						_defs[did] = def
		fname = dir.get_next()
	dir.list_dir_end()


func get_def(disease_id: String) -> Dictionary:
	return _defs.get(disease_id, {}) as Dictionary


func get_all_defs() -> Array:
	return _defs.values()
