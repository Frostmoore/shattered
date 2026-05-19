class_name EnemyPlacer

## Places enemies using a pressure-budget system.
## Entrance and exit rooms are kept clear; boss room receives normal budget (allows minions).

static func place(
	rng: RandomNumberGenerator,
	data: MapData,
	rooms: Array[Rect2i],
	entrance_idx: int,
	boss_idx: int,
	exit_idx: int,
	floor_num: int,
	total_floors: int,
	enemy_balance: Dictionary = {}
) -> void:
	var pressure_base:      int   = int(enemy_balance.get("pressure_base",      30))
	var pressure_per_floor: int   = int(enemy_balance.get("pressure_per_floor", 12))
	var max_per_room:       int   = int(enemy_balance.get("max_per_room",         3))
	var boss_hp_mult:       float = float(enemy_balance.get("boss_hp_mult",     1.8))
	var boss_atk_mult:      float = float(enemy_balance.get("boss_atk_mult",    1.2))
	var boss_def_mult:      float = float(enemy_balance.get("boss_def_mult",    1.3))
	var boss_xp_mult:       float = float(enemy_balance.get("boss_xp_mult",     5.0))
	var boss_detection:     int   = int(enemy_balance.get("boss_detection",      10))
	var budget: int = pressure_base + (floor_num - 1) * pressure_per_floor

	var enemy_table: Array = GameBalance.get_enemy_table()
	var available: Array = []
	for entry: Variant in enemy_table:
		var e: Dictionary = entry as Dictionary
		if floor_num >= int(e["min_floor"]):
			available.append(e)

	if available.is_empty():
		return

	# Entrance and exit rooms are safe; boss room is included so minions can spawn there
	var eligible_rooms: Array[int] = []
	for i: int in range(rooms.size()):
		if i == entrance_idx or i == exit_idx:
			continue
		eligible_rooms.append(i)

	if eligible_rooms.is_empty():
		return

	var per_room: int = budget / eligible_rooms.size()
	var room_budgets: Array[int] = []
	for _r: int in eligible_rooms:
		room_budgets.append(per_room)

	var occupied: Dictionary = {}
	for ent: Dictionary in data.entity_defs:
		var raw_p: Dictionary = ent.get("pos", {}) as Dictionary
		occupied[Vector2i(int(raw_p.get("x", -1)), int(raw_p.get("y", -1)))] = true
	for trans: Dictionary in data.transitions:
		var tp: Variant = trans.get("position")
		if tp is Vector2i:
			occupied[tp as Vector2i] = true

	var uid_counter: int = 0
	for ri: int in range(eligible_rooms.size()):
		var room_idx: int = eligible_rooms[ri]
		var room: Rect2i = rooms[room_idx]
		var remaining: int = room_budgets[ri]
		var placed: int = 0

		while remaining > 0 and placed < max_per_room:
			var choices: Array = []
			for entry: Variant in available:
				var e: Dictionary = entry as Dictionary
				if int(e["pressure_cost"]) <= remaining:
					choices.append(e)
			if choices.is_empty():
				break

			var pick: Dictionary = choices[rng.randi_range(0, choices.size() - 1)] as Dictionary
			remaining -= int(pick["pressure_cost"])
			placed += 1

			var pos: Vector2i = _random_room_pos(rng, room)
			var tries: int = 0
			while occupied.has(pos) and tries < 10:
				pos = _random_room_pos(rng, room)
				tries += 1
			occupied[pos] = true

			var uid: String = "enemy_f%d_%d" % [floor_num, uid_counter]
			uid_counter += 1

			data.add_entity("enemy", uid, pos, {
				"id":            pick["id"],
				"name":          pick["name"],
				"hp":            int(pick["hp_base"]) + (floor_num - 1) * int(pick["hp_per_floor"]),
				"attack":        int(pick["atk_base"]) + (floor_num - 1) * int(pick["atk_per_floor"]),
				"defense":       int(pick["def_base"]) + (floor_num - 1) * int(pick["def_per_floor"]),
				"xp_reward":     int(pick["xp_reward"]),
				"detection_range": int(pick["detection"]),
			})

	# Place boss in boss room (last floor only) — strongest available enemy, scaled up
	if floor_num == total_floors:
		var boss_base: Dictionary = available[0] as Dictionary
		for entry: Variant in available:
			var e: Dictionary = entry as Dictionary
			if int(e["pressure_cost"]) > int(boss_base["pressure_cost"]):
				boss_base = e

		var boss_room: Rect2i = rooms[boss_idx]
		# Place boss at the interior corner farthest from the entrance (procedural)
		var entrance_center: Vector2i = rooms[entrance_idx].position + Vector2i(rooms[entrance_idx].size.x / 2, rooms[entrance_idx].size.y / 2)
		var corners: Array[Vector2i] = [
			boss_room.position + Vector2i(1, 1),
			boss_room.position + Vector2i(boss_room.size.x - 2, 1),
			boss_room.position + Vector2i(1, boss_room.size.y - 2),
			boss_room.position + Vector2i(boss_room.size.x - 2, boss_room.size.y - 2),
		]
		var boss_pos: Vector2i = corners[0]
		var best_corner_dist: float = 0.0
		for corner: Vector2i in corners:
			var d: float = float(entrance_center.distance_to(corner))
			if d > best_corner_dist:
				best_corner_dist = d
				boss_pos = corner
		occupied[boss_pos] = true

		var base_hp: int  = int(boss_base["hp_base"])  + (floor_num - 1) * int(boss_base["hp_per_floor"])
		var base_atk: int = int(boss_base["atk_base"]) + (floor_num - 1) * int(boss_base["atk_per_floor"])
		var base_def: int = int(boss_base["def_base"]) + (floor_num - 1) * int(boss_base["def_per_floor"])

		data.add_entity("enemy", "boss_f%d" % floor_num, boss_pos, {
			"id":              boss_base["id"],
			"name":            "Gran " + str(boss_base["name"]),
			"hp":              roundi(float(base_hp)  * boss_hp_mult),
			"attack":          roundi(float(base_atk) * boss_atk_mult),
			"defense":         roundi(float(base_def) * boss_def_mult),
			"xp_reward":       roundi(float(int(boss_base["xp_reward"])) * boss_xp_mult),
			"detection_range": boss_detection,
			"boss":            true,
		})


static func _random_room_pos(rng: RandomNumberGenerator, room: Rect2i) -> Vector2i:
	return Vector2i(
		rng.randi_range(room.position.x, room.position.x + room.size.x - 1),
		rng.randi_range(room.position.y, room.position.y + room.size.y - 1)
	)
