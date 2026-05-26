extends Node

const SAVE_DIR: String = "user://saves/"


func get_char_path(world_name: String, char_name: String) -> String:
	return SAVE_DIR + world_name + "/" + char_name + ".json"


func save_game() -> void:
	var world_name: String = GameState.world_name
	var char_name: String  = GameState.character_name
	if world_name == "" or char_name == "":
		push_error("SaveManager: world_name or character_name not set")
		return

	WorldSaveManager.save_world(world_name)
	_save_character(world_name, char_name)


func load_game(world_name: String, char_name: String) -> bool:
	if not WorldSaveManager.load_world(world_name):
		return false
	return _load_character(world_name, char_name)


func _save_character(world_name: String, char_name: String) -> void:
	# Flush the live state of the current map into the registry before serializing,
	# because save_location_state() normally only runs when leaving a map.
	var current_map: BaseMap = WorldManager.get_current_map()
	if current_map != null and is_instance_valid(current_map):
		current_map.save_location_state()

	var dir: String = SAVE_DIR + world_name + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	var data: Dictionary = {
		"character_name":    char_name,
		"level":             GameState.level,
		"xp":                GameState.xp,
		"current_class":     GameState.current_class,
		"base_attributes":   GameState.base_attributes.duplicate(),
		"class_bonus":       GameState.class_bonus.duplicate(),
		"current_map_id":    GameState.current_map_id,
		"player_position":  {"x": GameState.player_position.x, "y": GameState.player_position.y},
		"player_stats":     GameState.player_stats.duplicate(),
		"inventory":        GameState.inventory.duplicate(true),
		"active_quests":    GameState.active_quests.duplicate(true),
		"ready_quests":     GameState.ready_quests.duplicate(true),
		"completed_quests": GameState.completed_quests.duplicate(true),
		"world_flags":      GameState.world_flags.duplicate(),
		"equipped":         GameState.equipped.duplicate(),
		"quick_slots":      GameState.quick_slots.duplicate(true),
		"permadeath":         GameState.permadeath,
		"permanent_allies":   GameState.permanent_allies.duplicate(true),
		"location_states":    LocationRegistry.serialize_states(),
		"faction_rep":            GameState.character_faction_rep.duplicate(),
		"faction_membership":     GameState.character_faction_membership.duplicate(true),
		"criminal_record":        GameState.criminal_record.duplicate(true),
		"known_faction_members":  GameState.known_faction_members.duplicate(true),
		"total_minutes":          GameState.total_minutes,
		"food":                   GameState.food,
		"water":                  GameState.water,
		"exhaustion":             GameState.exhaustion,
		"temperature":            GameState.temperature,
		"active_diseases":        GameState.active_diseases.duplicate(true),
	}
	var path: String = get_char_path(world_name, char_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("Character saved to ", path)
	else:
		push_error("SaveManager: cannot write: " + path)


func _load_character(world_name: String, char_name: String) -> bool:
	var path: String = get_char_path(world_name, char_name)
	if not FileAccess.file_exists(path):
		push_error("SaveManager: character file not found: " + path)
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SaveManager: cannot read: " + path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveManager: invalid JSON in character file")
		return false
	_apply_save_data(parsed as Dictionary, world_name, char_name)
	print("Character loaded from ", path)
	return true


func list_characters(world_name: String) -> Array[String]:
	var chars: Array[String] = []
	var dir_path: String = SAVE_DIR + world_name + "/"
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return chars
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json") and entry != "world.json":
			chars.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	dir.list_dir_end()
	chars.sort()
	return chars


func can_save_here() -> bool:
	var current_map: BaseMap = WorldManager.get_current_map()
	if current_map == null:
		return false
	return current_map.has_save_point_at(GameState.player_position)


func delete_character_save(world_name: String, char_name: String) -> void:
	var path: String = get_char_path(world_name, char_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Permadeath: deleted character save ", path)


func has_current_save() -> bool:
	if GameState.world_name == "" or GameState.character_name == "":
		return false
	return FileAccess.file_exists(get_char_path(GameState.world_name, GameState.character_name))


func has_any_save() -> bool:
	return WorldSaveManager.list_worlds().size() > 0


func has_save() -> bool:
	return has_any_save()


func _apply_save_data(data: Dictionary, world_name: String, char_name: String) -> void:
	GameState.world_name      = world_name
	GameState.character_name  = char_name
	GameState.permadeath      = bool(data.get("permadeath", false))
	GameState.level           = int(data.get("level", 1))
	GameState.xp              = int(data.get("xp", 0))
	GameState.current_map_id  = str(data.get("current_map_id", "overworld"))

	var raw_pos: Variant = data.get("player_position", {"x": 5, "y": 5})
	if raw_pos is Dictionary:
		var pos: Dictionary = raw_pos as Dictionary
		GameState.player_position = Vector2i(int(pos.get("x", 5)), int(pos.get("y", 5)))

	GameState.current_class = str(data.get("current_class", "noob"))

	var raw_base: Variant = data.get("base_attributes", data.get("attributes", {}))
	if raw_base is Dictionary:
		for key: String in (raw_base as Dictionary):
			if GameState.base_attributes.has(key):
				GameState.base_attributes[key] = int((raw_base as Dictionary)[key])

	var raw_bonus: Variant = data.get("class_bonus", {})
	if raw_bonus is Dictionary:
		for key: String in (raw_bonus as Dictionary):
			if GameState.class_bonus.has(key):
				GameState.class_bonus[key] = int((raw_bonus as Dictionary)[key])

	var raw_stats: Variant = data.get("player_stats", {})
	if raw_stats is Dictionary:
		for key: String in (raw_stats as Dictionary):
			GameState.player_stats[key] = (raw_stats as Dictionary)[key]
	# Ensure derived stats are consistent with loaded attributes
	GameState.recalculate_derived_stats()

	var raw_inv: Variant = data.get("inventory", [])
	if raw_inv is Array:
		GameState.inventory = []
		for item: Variant in (raw_inv as Array):
			if item is String:
				GameState.inventory.append({"id": str(item), "qty": 1})
			elif item is Dictionary:
				GameState.inventory.append(item)

	var raw_aq: Variant = data.get("active_quests", [])
	if raw_aq is Array:
		GameState.active_quests = raw_aq as Array

	var raw_rq: Variant = data.get("ready_quests", [])
	if raw_rq is Array:
		GameState.ready_quests = raw_rq as Array

	var raw_cq: Variant = data.get("completed_quests", [])
	if raw_cq is Array:
		GameState.completed_quests = raw_cq as Array

	var raw_flags: Variant = data.get("world_flags", {})
	if raw_flags is Dictionary:
		for key: String in (raw_flags as Dictionary):
			GameState.world_flags[key] = (raw_flags as Dictionary)[key]

	var raw_eq: Variant = data.get("equipped", {})
	if raw_eq is Dictionary:
		for key: String in (raw_eq as Dictionary):
			if GameState.equipped.has(key):
				GameState.equipped[key] = str((raw_eq as Dictionary)[key])

	var raw_qs: Variant = data.get("quick_slots", [])
	if raw_qs is Array:
		var qs: Array = raw_qs as Array
		for i: int in mini(qs.size(), GameState.quick_slots.size()):
			GameState.quick_slots[i] = str(qs[i])

	var raw_states: Variant = data.get("location_states", {})
	if raw_states is Dictionary:
		LocationRegistry.deserialize_states(raw_states as Dictionary)

	var raw_rep: Variant = data.get("faction_rep", {})
	if raw_rep is Dictionary:
		for key: String in (raw_rep as Dictionary):
			GameState.character_faction_rep[key] = int((raw_rep as Dictionary)[key])

	var raw_membership: Variant = data.get("faction_membership", {})
	if raw_membership is Dictionary:
		GameState.character_faction_membership = (raw_membership as Dictionary).duplicate(true)
	FactionMembership.reapply_all_passives()

	var raw_record: Variant = data.get("criminal_record", [])
	if raw_record is Array:
		GameState.criminal_record = (raw_record as Array).duplicate(true)

	var raw_known: Variant = data.get("known_faction_members", {})
	if raw_known is Dictionary:
		GameState.known_faction_members = (raw_known as Dictionary).duplicate(true)

	EventBus.equipment_changed.emit()
	EventBus.quick_slots_changed.emit()

	GameState.total_minutes = int(data.get("total_minutes", 480))

	GameState.food        = float(data.get("food",        100.0))
	GameState.water       = float(data.get("water",       100.0))
	GameState.exhaustion  = float(data.get("exhaustion",  0.0))
	GameState.temperature = float(data.get("temperature", 0.0))
	var raw_diseases: Variant = data.get("active_diseases", [])
	if raw_diseases is Array:
		GameState.active_diseases = (raw_diseases as Array).duplicate(true)
	# needs_modifiers non serializzato — ricalcolato dopo il load
	NeedsManager.rebuild_modifiers()

	var raw_pa: Variant = data.get("permanent_allies", [])
	if raw_pa is Array:
		GameState.permanent_allies = (raw_pa as Array).duplicate(true)

	# Ripristina la special della classe caricata in ClassRuntime
	var runtime: Node = get_node_or_null("/root/ClassRuntime")
	if runtime:
		runtime.call("set_active_class", GameState.current_class)

	# Rispristina alleati permanenti in AllyManager
	var ally_mgr: Node = get_node_or_null("/root/AllyManager")
	if ally_mgr and not GameState.permanent_allies.is_empty():
		ally_mgr.call("restore_permanent", GameState.permanent_allies)
