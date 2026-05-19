class_name LocationState

var location_id: String = ""
var visited: bool = false
var dead_entity_uids: Array[String] = []
var collected_items: Array[String] = []
# uid → {x, y} for living entities that moved from their spawn
var entity_positions: Dictionary = {}
# UIDs of doors that have been opened
var open_entity_uids: Array[String] = []
# Per-tile fog-of-war: 0 = unseen, 1 = seen/remembered.  Size = width × height.
var fog_of_war: PackedByteArray = PackedByteArray()


func serialize() -> Dictionary:
	return {
		"location_id":       location_id,
		"visited":           visited,
		"dead":              dead_entity_uids.duplicate(),
		"items":             collected_items.duplicate(),
		"entity_positions":  entity_positions.duplicate(true),
		"open_doors":        open_entity_uids.duplicate(),
		"fog_of_war":        fog_of_war.hex_encode(),
	}


static func deserialize(data: Dictionary) -> LocationState:
	var state := LocationState.new()
	state.location_id = str(data.get("location_id", ""))
	state.visited     = bool(data.get("visited", false))

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

	var raw_open: Variant = data.get("open_doors", [])
	if raw_open is Array:
		for uid: Variant in (raw_open as Array):
			state.open_entity_uids.append(str(uid))

	var raw_fog: Variant = data.get("fog_of_war", "")
	if raw_fog is String and (raw_fog as String) != "":
		state.fog_of_war = (raw_fog as String).hex_decode()

	return state
