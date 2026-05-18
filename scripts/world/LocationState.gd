class_name LocationState

var location_id: String = ""
var visited: bool = false
var dead_entity_uids: Array[String] = []
var collected_items: Array[String] = []
# uid → {x, y} for living entities that moved from their spawn
var entity_positions: Dictionary = {}


func serialize() -> Dictionary:
	return {
		"location_id":       location_id,
		"visited":           visited,
		"dead":              dead_entity_uids.duplicate(),
		"items":             collected_items.duplicate(),
		"entity_positions":  entity_positions.duplicate(true)
	}


static func deserialize(data: Dictionary) -> LocationState:
	var state := LocationState.new()
	state.location_id = str(data.get("location_id", ""))
	state.visited = bool(data.get("visited", false))
	var raw_dead: Variant = data.get("dead", [])
	if raw_dead is Array:
		for uid: Variant in (raw_dead as Array):
			state.dead_entity_uids.append(str(uid))
	var raw_items: Variant = data.get("items", [])
	if raw_items is Array:
		for item: Variant in (raw_items as Array):
			state.collected_items.append(str(item))
	var raw_pos: Variant = data.get("entity_positions", {})
	if raw_pos is Dictionary:
		for uid: Variant in (raw_pos as Dictionary):
			var p: Variant = (raw_pos as Dictionary)[uid]
			if p is Dictionary:
				state.entity_positions[str(uid)] = p
	return state
