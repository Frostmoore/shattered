extends Node

const ENEMY_DATA_ROOT := "res://data/enemies/"

var _enemies: Dictionary = {}  # id → data Dictionary


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	_scan_directory(ENEMY_DATA_ROOT)
	print("EnemyRegistry: caricati %d nemici" % _enemies.size())


func _scan_directory(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_error("EnemyRegistry: directory non trovata: " + path)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			_scan_directory(path + entry + "/")
		elif entry.ends_with(".json"):
			_load_file(path + entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EnemyRegistry: impossibile aprire " + path)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("EnemyRegistry: JSON non valido in " + path)
		return
	var data: Dictionary = parsed as Dictionary
	var id: String = str(data.get("id", ""))
	if id == "":
		push_error("EnemyRegistry: campo 'id' mancante in " + path)
		return
	_enemies[id] = data


# ── API pubblica ──────────────────────────────────────────────────────────────

func get_enemy_data(id: String) -> Dictionary:
	return _enemies.get(id, {})


func get_display_name(id: String) -> String:
	var raw: String = str(_enemies.get(id, {}).get("name", id))
	return LocaleManager.t_or("ENEMY_" + id.to_upper() + "_NAME", raw)


func get_all() -> Array:
	return _enemies.values()


func get_by_tier(tier: int) -> Array:
	var result: Array = []
	for data: Dictionary in _enemies.values():
		if int(data.get("tier", 0)) == tier:
			result.append(data)
	return result


func get_by_role(role: String) -> Array:
	var result: Array = []
	for data: Dictionary in _enemies.values():
		if str(data.get("role", "")) == role:
			result.append(data)
	return result


func get_by_family(family: String) -> Array:
	var result: Array = []
	for data: Dictionary in _enemies.values():
		if str(data.get("family", "")) == family:
			result.append(data)
	return result
