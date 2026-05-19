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


func serialize() -> Dictionary:
	var wall_arr: Array = []
	for w: Vector2i in walls:
		wall_arr.append([w.x, w.y])

	var trans_arr: Array = []
	for t: Dictionary in transitions:
		var ts: Dictionary = t.duplicate(true)
		var p: Variant = ts.get("position")
		if p is Vector2i:
			ts["position"] = {"x": (p as Vector2i).x, "y": (p as Vector2i).y}
		var tp: Variant = ts.get("target_position")
		if tp is Vector2i:
			ts["target_position"] = {"x": (tp as Vector2i).x, "y": (tp as Vector2i).y}
		trans_arr.append(ts)

	return {
		"id":          id,
		"type":        type,
		"width":       width,
		"height":      height,
		"walls":       wall_arr,
		"transitions": trans_arr,
		"entity_defs": entity_defs.duplicate(true),
		"metadata":    metadata.duplicate(true),
	}


static func from_dict(d: Dictionary) -> MapData:
	var data := MapData.new()
	data.id     = str(d.get("id",     ""))
	data.type   = str(d.get("type",   "dungeon"))
	data.width  = int(d.get("width",  0))
	data.height = int(d.get("height", 0))
	data.metadata = (d.get("metadata", {}) as Dictionary).duplicate(true)

	var raw_walls: Variant = d.get("walls", [])
	if raw_walls is Array:
		for w: Variant in (raw_walls as Array):
			if w is Array and (w as Array).size() >= 2:
				data.walls.append(Vector2i(int((w as Array)[0]), int((w as Array)[1])))

	var raw_trans: Variant = d.get("transitions", [])
	if raw_trans is Array:
		for t: Variant in (raw_trans as Array):
			if not t is Dictionary:
				continue
			var td: Dictionary = (t as Dictionary).duplicate(true)
			var p: Variant = td.get("position")
			if p is Dictionary:
				td["position"] = Vector2i(int((p as Dictionary).get("x", 0)), int((p as Dictionary).get("y", 0)))
			var tp: Variant = td.get("target_position")
			if tp is Dictionary:
				td["target_position"] = Vector2i(int((tp as Dictionary).get("x", 0)), int((tp as Dictionary).get("y", 0)))
			data.transitions.append(td)

	var raw_ent: Variant = d.get("entity_defs", [])
	if raw_ent is Array:
		for e: Variant in (raw_ent as Array):
			if e is Dictionary:
				data.entity_defs.append((e as Dictionary).duplicate(true))

	return data
