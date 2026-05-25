extends Node

const SAVE_DIR: String = "user://saves/"


func get_world_path(world_name: String) -> String:
	return SAVE_DIR + world_name + "/world.json"


func generate_new_world(world_name: String, world_seed: int = -1) -> void:
	LocationRegistry.clear()
	GameState.world_name = world_name
	var seed: int = world_seed if world_seed >= 0 else randi()
	GameState.world_seed = seed

	# ── Generate procedural dungeon (all floors) before registering overworld,
	#    so we know where floor 1's entrance is (needed for overworld transition target).
	var dungeon_id: String = "dungeon_01"
	var player_level: int = GameState.level
	var meta_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	meta_rng.seed = seed ^ 0x9E3779B9  # separate seed so floor-count roll doesn't consume floor seeds
	var floor_count: int      = GameBalance.roll_floor_count(meta_rng, player_level)
	var enemy_balance: Dictionary = GameBalance.roll_enemy_balance(meta_rng, player_level)

	# ── DungeonPressureProfile: pre-compute per-floor budgets ─────────────────
	var danger_rating: int  = int(enemy_balance.get("danger_rating", 1))
	var budget_curve: String = str(enemy_balance.get("budget_curve", "rising"))
	GameState.danger_rating = danger_rating
	GameState.budget_curve  = budget_curve

	var total: int      = GameBalance.total_pressure_budget(danger_rating, floor_count)
	var boss_res: int   = roundi(float(total) * GameBalance.BOSS_RESERVE_RATIO)
	var elite_res: int  = roundi(float(total) * GameBalance.ELITE_RESERVE_RATIO)
	var available: int  = total - boss_res - elite_res
	var budgets: Array[int] = GameBalance.floor_pressure_budgets(available, floor_count, budget_curve, meta_rng)

	enemy_balance["floor_budgets"]           = budgets
	enemy_balance["total_pressure_budget"]   = total
	enemy_balance["boss_pressure_reserved"]  = boss_res
	enemy_balance["elite_pressure_reserved"] = elite_res

	# Position on the overworld that leads into the dungeon
	var overworld_dungeon_tile: Vector2i = Vector2i(18, 14)
	# Position on the overworld where the player lands after exiting the dungeon
	var overworld_return_pos: Vector2i   = Vector2i(17, 14)

	var floors: Array = _generate_dungeon_floors(seed, dungeon_id, floor_count, player_level, enemy_balance)
	_link_floor_transitions(floors, dungeon_id, floor_count, overworld_return_pos)

	# Register overworld with the correct dungeon floor-1 entrance position
	var floor1_entrance: Vector2i = floors[0]["entrance_pos"] as Vector2i
	LocationRegistry.register("overworld", "overworld", {
		"transition_village":    "village_01",
		"transition_dungeon":    dungeon_id + "_floor_1",
		"dungeon_target_pos_x":  floor1_entrance.x,
		"dungeon_target_pos_y":  floor1_entrance.y,
		"overworld_dungeon_tile_x": overworld_dungeon_tile.x,
		"overworld_dungeon_tile_y": overworld_dungeon_tile.y,
	})
	LocationRegistry.register("village_01", "village", {
		"transition_overworld": "overworld"
	})

	# Register all generated floor MapData as prebuilt entries
	for i: int in range(floor_count):
		var floor_id: String = dungeon_id + "_floor_" + str(i + 1)
		var floor_data: MapData = floors[i]["data"] as MapData
		LocationRegistry.register_prebuilt(floor_id, floor_data)

	print("World '%s' generated (seed: %d, floors: %d)" % [world_name, seed, floor_count])


func _generate_dungeon_floors(seed: int, dungeon_id: String, floor_count: int, player_level: int, enemy_balance: Dictionary) -> Array:
	var floors: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in range(floor_count):
		rng.seed = seed + i * GameBalance.FLOOR_SEED_STRIDE
		var result: Dictionary = FloorGenerator.generate(rng, i + 1, floor_count, player_level, enemy_balance)
		result["data"].id = dungeon_id + "_floor_" + str(i + 1)
		floors.append(result)
	return floors


func _link_floor_transitions(floors: Array, dungeon_id: String, floor_count: int, overworld_return_pos: Vector2i) -> void:
	for i: int in range(floor_count):
		var floor_data: MapData = floors[i]["data"] as MapData

		# transitions[0] = stair UP
		if i == 0:
			floor_data.transitions[0]["target_id"]       = "overworld"
			floor_data.transitions[0]["target_type"]     = "overworld"
			floor_data.transitions[0]["target_position"] = overworld_return_pos
		else:
			var prev_id: String         = dungeon_id + "_floor_" + str(i)
			var prev_exit: Vector2i     = floors[i - 1]["exit_pos"] as Vector2i
			floor_data.transitions[0]["target_id"]       = prev_id
			floor_data.transitions[0]["target_type"]     = "dungeon"
			floor_data.transitions[0]["target_position"] = prev_exit

		# transitions[1] = stair DOWN
		if i == floor_count - 1:
			floor_data.transitions[1]["target_id"]       = "overworld"
			floor_data.transitions[1]["target_type"]     = "overworld"
			floor_data.transitions[1]["target_position"] = overworld_return_pos
		else:
			var next_id: String          = dungeon_id + "_floor_" + str(i + 2)
			var next_entrance: Vector2i  = floors[i + 1]["entrance_pos"] as Vector2i
			floor_data.transitions[1]["target_id"]       = next_id
			floor_data.transitions[1]["target_type"]     = "dungeon"
			floor_data.transitions[1]["target_position"] = next_entrance



func save_world(world_name: String) -> void:
	var dir: String = SAVE_DIR + world_name + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = get_world_path(world_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var world_data: Dictionary = {
			"meta": {
				"world_seed":    GameState.world_seed,
				"danger_rating": GameState.danger_rating,
				"budget_curve":  GameState.budget_curve,
			},
			"locations":   LocationRegistry.serialize_definitions(),
			"world_state": WorldState.serialize(),
		}
		file.store_string(JSON.stringify(world_data, "\t"))
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
	var world_data: Dictionary = parsed as Dictionary

	# Support both old format (flat locations dict) and new format (meta + locations)
	var locations: Variant = world_data.get("locations", null)
	if locations == null:
		locations = world_data
	else:
		var meta: Dictionary = world_data.get("meta", {}) as Dictionary
		GameState.world_seed    = int(meta.get("world_seed", 0))
		GameState.danger_rating = int(meta.get("danger_rating", 1))
		GameState.budget_curve  = str(meta.get("budget_curve", "rising"))

	GameState.world_name = world_name
	LocationRegistry.deserialize_definitions(locations as Dictionary)

	var raw_ws: Variant = world_data.get("world_state", {})
	if raw_ws is Dictionary:
		WorldState.deserialize(raw_ws as Dictionary)
	else:
		WorldState.reset()

	print("World loaded from ", path)
	return true


func has_world(world_name: String) -> bool:
	return FileAccess.file_exists(get_world_path(world_name))


func delete_world(world_name: String) -> void:
	var dir_path: String = SAVE_DIR + world_name + "/"
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(dir_path + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path.trim_suffix("/"))
	print("World deleted: ", world_name)


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
