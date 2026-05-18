extends Node

const SAVE_DIR: String = "user://saves/"


func get_world_path(world_name: String) -> String:
	return SAVE_DIR + world_name + "/world.json"


func generate_new_world(world_name: String, world_seed: int = -1) -> void:
	LocationRegistry.clear()
	GameState.world_name = world_name
	var seed: int = world_seed if world_seed >= 0 else randi()

	LocationRegistry.register("overworld", "overworld", {
		"transition_village": "village_01",
		"transition_dungeon": "dungeon_01"
	})
	LocationRegistry.register("village_01", "village", {
		"transition_overworld": "overworld"
	})
	LocationRegistry.register("dungeon_01", "dungeon", {
		"seed":                 seed,
		"transition_overworld": "overworld"
	})

	print("World '%s' generated (seed: %d)" % [world_name, seed])


func save_world(world_name: String) -> void:
	var dir: String = SAVE_DIR + world_name + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = get_world_path(world_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(LocationRegistry.serialize_definitions(), "\t"))
		file.close()
		print("World saved to ", path)
	else:
		push_error("WorldSaveManager: cannot write: " + path)


func load_world(world_name: String) -> bool:
	var path: String = get_world_path(world_name)
	if not FileAccess.file_exists(path):
		push_error("WorldSaveManager: world file not found: " + path)
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("WorldSaveManager: cannot read: " + path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("WorldSaveManager: invalid JSON in world file")
		return false
	GameState.world_name = world_name
	LocationRegistry.deserialize_definitions(parsed as Dictionary)
	print("World loaded from ", path)
	return true


func has_world(world_name: String) -> bool:
	return FileAccess.file_exists(get_world_path(world_name))


func list_worlds() -> Array[String]:
	var worlds: Array[String] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return worlds
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			if FileAccess.file_exists(SAVE_DIR + entry + "/world.json"):
				worlds.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	worlds.sort()
	return worlds
