class_name MapData

var id: String = ""
var type: String = ""        # "overworld" | "village" | "dungeon" | "building"
var width: int = 0
var height: int = 0
var walls: Array[Vector2i] = []
var transitions: Array[Dictionary] = []   # {position, target_id, target_type, target_position}
var entity_defs: Array[Dictionary] = []   # {kind, uid, pos, params}
var metadata: Dictionary = {}


func add_border_walls() -> void:
	for x: int in range(width):
		walls.append(Vector2i(x, 0))
		walls.append(Vector2i(x, height - 1))
	for y: int in range(height):
		walls.append(Vector2i(0, y))
		walls.append(Vector2i(width - 1, y))


func add_blocked_rect(top_left: Vector2i, size: Vector2i) -> void:
	for y: int in range(top_left.y, top_left.y + size.y):
		for x: int in range(top_left.x, top_left.x + size.x):
			walls.append(Vector2i(x, y))


func add_transition(pos: Vector2i, target_id: String, target_type: String, target_pos: Vector2i) -> void:
	transitions.append({
		"position":        pos,
		"target_id":       target_id,
		"target_type":     target_type,
		"target_position": target_pos
	})


func add_entity(kind: String, uid: String, pos: Vector2i, params: Dictionary) -> void:
	entity_defs.append({
		"kind":   kind,
		"uid":    uid,
		"pos":    {"x": pos.x, "y": pos.y},
		"params": params.duplicate(true)
	})
