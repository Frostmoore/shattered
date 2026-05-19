class_name ContentPlacer

## Places non-enemy content: stairs, save point, chests, and doors.

static func place(
	rng: RandomNumberGenerator,
	data: MapData,
	rooms: Array[Rect2i],
	entrance_idx: int,
	boss_idx: int,
	exit_idx: int,
	floor_num: int,
	total_floors: int,
	wall_set: Dictionary,
	player_level: int = 1
) -> void:
	var entrance_room: Rect2i = rooms[entrance_idx]
	var exit_room: Rect2i     = rooms[exit_idx]

	var entrance_center: Vector2i = entrance_room.position + Vector2i(entrance_room.size.x / 2, entrance_room.size.y / 2)
	var exit_center: Vector2i     = exit_room.position     + Vector2i(exit_room.size.x / 2,     exit_room.size.y / 2)

	# Stair UP (return to previous floor or overworld) — in entrance room
	data.transitions.append({
		"position":        entrance_center,
		"target_id":       "",
		"target_type":     "overworld",
		"target_position": Vector2i.ZERO,
		"stair_type":      "up",
	})

	# Stair DOWN — in exit room, separate from boss
	var down_target_type: String = "overworld" if floor_num == total_floors else "dungeon"
	data.transitions.append({
		"position":        exit_center,
		"target_id":       "",
		"target_type":     down_target_type,
		"target_position": Vector2i.ZERO,
		"stair_type":      "down",
	})

	# Save point: only on floors 1–2 before the boss.
	# Never on floor 1 unless the dungeon is too short to have any other pre-boss floor.
	var floors_before_boss: int = total_floors - floor_num
	var place_save: bool = (floors_before_boss >= 1 and floors_before_boss <= 2)
	if floor_num == 1 and total_floors > 2:
		place_save = false
	if place_save:
		var save_eligible: Array[int] = []
		for i: int in range(rooms.size()):
			if i != entrance_idx and i != boss_idx and i != exit_idx:
				save_eligible.append(i)
		if save_eligible.is_empty():
			save_eligible.append(entrance_idx)
		var save_room_idx: int = save_eligible[rng.randi_range(0, save_eligible.size() - 1)]
		var save_room: Rect2i = rooms[save_room_idx]
		var save_pos: Vector2i = save_room.position + Vector2i(save_room.size.x / 2, save_room.size.y / 2)
		data.add_entity("save_point", "save_point_f%d" % floor_num, save_pos, {"label": "Falò"})

	# Chests: roll the total count for this floor from a level-weighted distribution
	var chest_target: int = GameBalance.roll_chest_count(rng, player_level)

	if chest_target > 0:
		var chest_eligible: Array[int] = []
		for i: int in range(rooms.size()):
			if i != entrance_idx and i != boss_idx and i != exit_idx:
				chest_eligible.append(i)
		# Fisher-Yates shuffle so chest rooms are random
		for i: int in range(chest_eligible.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: int = chest_eligible[i]
			chest_eligible[i] = chest_eligible[j]
			chest_eligible[j] = tmp
		var to_place: int = mini(chest_target, chest_eligible.size())
		for ci: int in range(to_place):
			var room_idx: int = chest_eligible[ci]
			var room: Rect2i = rooms[room_idx]
			var chest_pos: Vector2i = Vector2i(
				rng.randi_range(room.position.x, room.position.x + room.size.x - 1),
				rng.randi_range(room.position.y, room.position.y + room.size.y - 1)
			)
			data.add_entity("chest", "chest_f%d_%d" % [floor_num, room_idx], chest_pos, {})

	# Doors at corridor entrances (30% chance per candidate tile)
	_place_doors(rng, data, rooms, wall_set, floor_num)


static func _place_doors(
	rng: RandomNumberGenerator,
	data: MapData,
	rooms: Array[Rect2i],
	wall_set: Dictionary,
	floor_num: int
) -> void:
	var map_w: int = data.width
	var map_h: int = data.height

	# Occupied positions: stairs, save points, chests already placed
	var occupied: Dictionary = {}
	for ent: Dictionary in data.entity_defs:
		var raw_p: Dictionary = ent.get("pos", {}) as Dictionary
		occupied[Vector2i(int(raw_p.get("x", -1)), int(raw_p.get("y", -1)))] = true
	for trans: Dictionary in data.transitions:
		var tp: Variant = trans.get("position")
		if tp is Vector2i:
			occupied[tp as Vector2i] = true

	var placed_doors: Dictionary = {}
	var door_uid_counter: int = 0

	for room: Rect2i in rooms:
		var rx0: int = room.position.x
		var ry0: int = room.position.y
		var rx1: int = rx0 + room.size.x - 1
		var ry1: int = ry0 + room.size.y - 1

		# Tiles just outside each room edge — walkable means a corridor enters here
		var candidates: Array[Vector2i] = []
		for x: int in range(rx0, rx1 + 1):
			var north: Vector2i = Vector2i(x, ry0 - 1)
			var south: Vector2i = Vector2i(x, ry1 + 1)
			if north.y >= 0 and not wall_set.has(north) and not placed_doors.has(north) and not occupied.has(north):
				candidates.append(north)
			if south.y < map_h and not wall_set.has(south) and not placed_doors.has(south) and not occupied.has(south):
				candidates.append(south)
		for y: int in range(ry0, ry1 + 1):
			var west: Vector2i = Vector2i(rx0 - 1, y)
			var east: Vector2i = Vector2i(rx1 + 1, y)
			if west.x >= 0 and not wall_set.has(west) and not placed_doors.has(west) and not occupied.has(west):
				candidates.append(west)
			if east.x < map_w and not wall_set.has(east) and not placed_doors.has(east) and not occupied.has(east):
				candidates.append(east)

		for door_pos: Vector2i in candidates:
			if rng.randf() < 0.30:
				data.add_entity("door", "door_f%d_%d" % [floor_num, door_uid_counter], door_pos, {})
				door_uid_counter += 1
				placed_doors[door_pos] = true
				occupied[door_pos] = true
