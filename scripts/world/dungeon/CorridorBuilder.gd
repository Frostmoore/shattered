class_name CorridorBuilder

## Connects all rooms using a Minimum Spanning Tree, then adds extra loop
## connections equal to CORRIDOR_LOOP_FRACTION × room count.
## Operates on a wall_set Dictionary (Vector2i → true) and removes tiles to carve corridors.

static func build(rng: RandomNumberGenerator, wall_set: Dictionary, rooms: Array[Rect2i], loop_fraction: float) -> void:
	if rooms.size() < 2:
		return

	var centers: Array[Vector2i] = []
	for room: Rect2i in rooms:
		centers.append(room.position + Vector2i(room.size.x / 2, room.size.y / 2))

	# Prim's MST: start from room 0, add nearest unconnected room at each step
	var in_mst: Array[bool] = []
	for _i: int in range(centers.size()):
		in_mst.append(false)
	in_mst[0] = true

	var edges: Array = []  # Array of [from_idx, to_idx]

	for _step: int in range(centers.size() - 1):
		var best_dist: float = INF
		var best_from: int = -1
		var best_to: int = -1

		for from_idx: int in range(centers.size()):
			if not in_mst[from_idx]:
				continue
			for to_idx: int in range(centers.size()):
				if in_mst[to_idx]:
					continue
				var d: float = float(centers[from_idx].distance_to(centers[to_idx]))
				if d < best_dist:
					best_dist = d
					best_from = from_idx
					best_to   = to_idx

		if best_from == -1:
			break
		in_mst[best_to] = true
		edges.append([best_from, best_to])

	# Extra loop connections to avoid dead-end corridors
	var extra: int = int(float(rooms.size()) * loop_fraction)
	var used: Dictionary = {}
	for e: Variant in edges:
		var pair: Array = e as Array
		used[_pair_key(pair[0], pair[1])] = true

	var attempts: int = 0
	while extra > 0 and attempts < 200:
		attempts += 1
		var a: int = rng.randi_range(0, centers.size() - 1)
		var b: int = rng.randi_range(0, centers.size() - 1)
		if a == b:
			continue
		var k: int = _pair_key(a, b)
		if used.has(k):
			continue
		used[k] = true
		edges.append([a, b])
		extra -= 1

	# Carve all corridors
	for e: Variant in edges:
		var pair: Array = e as Array
		_carve_l_corridor(wall_set, centers[int(pair[0])], centers[int(pair[1])])


static func _pair_key(a: int, b: int) -> int:
	return mini(a, b) * 10000 + maxi(a, b)


# L-shaped corridor: horizontal segment first, then vertical.
static func _carve_l_corridor(wall_set: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var mid: Vector2i = Vector2i(b.x, a.y)
	_carve_segment(wall_set, a, mid)
	_carve_segment(wall_set, mid, b)


static func _carve_segment(wall_set: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var pos: Vector2i = a
	var dx: int = int(sign(b.x - a.x))
	var dy: int = int(sign(b.y - a.y))

	while pos != b:
		wall_set.erase(pos)
		if dx != 0:
			pos.x += dx
		else:
			pos.y += dy
	wall_set.erase(b)
