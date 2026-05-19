class_name FloorGenerator

## Generates a single dungeon floor.
## Returns a Dictionary: { "data": MapData, "entrance_pos": Vector2i, "exit_pos": Vector2i }
## The MapData transitions[0] and [1] have empty target_id / target_position — the caller
## (WorldSaveManager) fills these in after generating all floors.

static func generate(rng: RandomNumberGenerator, floor_num: int, total_floors: int, player_level: int = 1, enemy_balance: Dictionary = {}) -> Dictionary:
	var size: Dictionary = GameBalance.roll_dungeon_size(rng, player_level)
	var width:  int = size["width"]
	var height: int = size["height"]

	var room_variance: int = rng.randi_range(-GameBalance.ROOM_RNG_VARIANCE, GameBalance.ROOM_RNG_VARIANCE)
	var room_min: int = maxi(2, rng.randi_range(GameBalance.ROOM_MIN_SIZE_LO, GameBalance.ROOM_MIN_SIZE_HI) + room_variance)
	var room_max: int = maxi(rng.randi_range(GameBalance.ROOM_MAX_SIZE_LO, GameBalance.ROOM_MAX_SIZE_HI) + room_variance, room_min + 2)
	var bsp_min_leaf: int = room_max + GameBalance.BSP_LEAF_EXTRA
	var loop_frac: float  = rng.randf_range(GameBalance.CORRIDOR_LOOP_MIN, GameBalance.CORRIDOR_LOOP_MAX)

	# ── 1. Fill entire map as walls ───────────────────────────────────────────
	var wall_set: Dictionary = {}
	for y: int in range(height):
		for x: int in range(width):
			wall_set[Vector2i(x, y)] = true

	# ── 2. BSP room placement ─────────────────────────────────────────────────
	var rooms: Array[Rect2i] = RoomPlacer.place_rooms(rng, width, height, room_min, room_max, bsp_min_leaf)

	if rooms.is_empty():
		rooms.append(Rect2i(2, 2, width - 4, height - 4))

	# ── 3. Carve room interiors ───────────────────────────────────────────────
	for room: Rect2i in rooms:
		for ry: int in range(room.position.y, room.position.y + room.size.y):
			for rx: int in range(room.position.x, room.position.x + room.size.x):
				wall_set.erase(Vector2i(rx, ry))

	# ── 4. Carve corridors ────────────────────────────────────────────────────
	CorridorBuilder.build(rng, wall_set, rooms, loop_frac)

	# ── 5. Identify entrance, boss room (farthest), exit room (second-farthest) ──
	var entrance_idx: int = 0
	var boss_idx: int = _farthest_room(rooms, entrance_idx)
	var exit_idx: int = _second_farthest_room(rooms, entrance_idx, boss_idx)

	# ── 6. Place content (stairs, save point, chests, doors) ──────────────────
	var data := MapData.new()
	data.type   = "dungeon"
	data.width  = width
	data.height = height

	ContentPlacer.place(rng, data, rooms, entrance_idx, boss_idx, exit_idx, floor_num, total_floors, wall_set, player_level)

	# ── 7. Place enemies ──────────────────────────────────────────────────────
	EnemyPlacer.place(rng, data, rooms, entrance_idx, boss_idx, exit_idx, floor_num, total_floors, enemy_balance)

	# ── 8. Convert wall_set to MapData.walls ──────────────────────────────────
	for pos: Variant in wall_set:
		data.walls.append(pos as Vector2i)

	# ── 9. Re-assert map border ───────────────────────────────────────────────
	_assert_border(data, width, height)

	var entrance_pos: Vector2i = (data.transitions[0]["position"] as Vector2i)
	var exit_pos: Vector2i     = (data.transitions[1]["position"] as Vector2i)

	return {
		"data":         data,
		"entrance_pos": entrance_pos,
		"exit_pos":     exit_pos,
	}


static func _farthest_room(rooms: Array[Rect2i], from_idx: int) -> int:
	var from_center: Vector2i = rooms[from_idx].position + Vector2i(rooms[from_idx].size.x / 2, rooms[from_idx].size.y / 2)
	var best_dist: float = 0.0
	var best_idx: int = (from_idx + 1) % rooms.size()
	for i: int in range(rooms.size()):
		if i == from_idx:
			continue
		var c: Vector2i = rooms[i].position + Vector2i(rooms[i].size.x / 2, rooms[i].size.y / 2)
		var d: float = float(from_center.distance_to(c))
		if d > best_dist:
			best_dist = d
			best_idx  = i
	return best_idx


static func _second_farthest_room(rooms: Array[Rect2i], from_idx: int, exclude_idx: int) -> int:
	var from_center: Vector2i = rooms[from_idx].position + Vector2i(rooms[from_idx].size.x / 2, rooms[from_idx].size.y / 2)
	var best_dist: float = 0.0
	var best_idx: int = -1
	for i: int in range(rooms.size()):
		if i == from_idx or i == exclude_idx:
			continue
		var c: Vector2i = rooms[i].position + Vector2i(rooms[i].size.x / 2, rooms[i].size.y / 2)
		var d: float = float(from_center.distance_to(c))
		if d > best_dist:
			best_dist = d
			best_idx  = i
	if best_idx == -1:
		# Fewer than 3 rooms: exit falls back to boss room
		best_idx = exclude_idx
	return best_idx


static func _assert_border(data: MapData, width: int, height: int) -> void:
	var wall_dict: Dictionary = {}
	for w: Vector2i in data.walls:
		wall_dict[w] = true

	for x: int in range(width):
		if not wall_dict.has(Vector2i(x, 0)):
			data.walls.append(Vector2i(x, 0))
		if not wall_dict.has(Vector2i(x, height - 1)):
			data.walls.append(Vector2i(x, height - 1))
	for y: int in range(1, height - 1):
		if not wall_dict.has(Vector2i(0, y)):
			data.walls.append(Vector2i(0, y))
		if not wall_dict.has(Vector2i(width - 1, y)):
			data.walls.append(Vector2i(width - 1, y))
