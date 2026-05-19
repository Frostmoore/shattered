class_name RoomPlacer

## BSP recursive room placement.
## Returns an Array[Rect2i] of placed rooms.
## Each Rect2i describes the INTERIOR of the room (position = top-left corner,
## size = interior dimensions — walls are carved around the outside).

static func place_rooms(rng: RandomNumberGenerator, width: int, height: int, room_min: int, room_max: int, bsp_min_leaf: int) -> Array[Rect2i]:
	var rooms: Array[Rect2i] = []
	_bsp(rng, Rect2i(1, 1, width - 2, height - 2), rooms, room_min, room_max, bsp_min_leaf)
	return rooms


static func _bsp(rng: RandomNumberGenerator, area: Rect2i, rooms: Array[Rect2i], room_min: int, room_max: int, min_leaf: int) -> void:

	var can_split_h: bool = area.size.y >= min_leaf * 2
	var can_split_v: bool = area.size.x >= min_leaf * 2

	if not can_split_h and not can_split_v:
		_place_room_in_leaf(rng, area, rooms, room_min, room_max)
		return

	var split_horizontal: bool
	if can_split_h and can_split_v:
		split_horizontal = rng.randi() % 2 == 0
	else:
		split_horizontal = can_split_h

	if split_horizontal:
		var min_split: int = min_leaf
		var max_split: int = area.size.y - min_leaf
		if min_split >= max_split:
			_place_room_in_leaf(rng, area, rooms, room_min, room_max)
			return
		var split: int = rng.randi_range(min_split, max_split)
		_bsp(rng, Rect2i(area.position.x, area.position.y, area.size.x, split), rooms, room_min, room_max, min_leaf)
		_bsp(rng, Rect2i(area.position.x, area.position.y + split, area.size.x, area.size.y - split), rooms, room_min, room_max, min_leaf)
	else:
		var min_split: int = min_leaf
		var max_split: int = area.size.x - min_leaf
		if min_split >= max_split:
			_place_room_in_leaf(rng, area, rooms, room_min, room_max)
			return
		var split: int = rng.randi_range(min_split, max_split)
		_bsp(rng, Rect2i(area.position.x, area.position.y, split, area.size.y), rooms, room_min, room_max, min_leaf)
		_bsp(rng, Rect2i(area.position.x + split, area.position.y, area.size.x - split, area.size.y), rooms, room_min, room_max, min_leaf)


static func _place_room_in_leaf(rng: RandomNumberGenerator, area: Rect2i, rooms: Array[Rect2i], min_size: int, max_size: int) -> void:
	var max_w: int = mini(max_size, area.size.x - 2)
	var max_h: int = mini(max_size, area.size.y - 2)
	if max_w < min_size or max_h < min_size:
		return

	var room_w: int = rng.randi_range(min_size, max_w)
	var room_h: int = rng.randi_range(min_size, max_h)

	var room_x: int = area.position.x + rng.randi_range(1, area.size.x - room_w - 1)
	var room_y: int = area.position.y + rng.randi_range(1, area.size.y - room_h - 1)

	rooms.append(Rect2i(room_x, room_y, room_w, room_h))
