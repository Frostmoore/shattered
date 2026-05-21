extends ClassSpecial
# Totem Curativo: cura WIL/4 HP ogni 2 turni del player per 6 turni. 1×/piano.
# active_target: piazzato su tile adiacente (il tile è solo "colore locale").

const HEAL_INTERVAL: int = 2

var _active_turns: int = 0
var _turn_counter: int = 0

func _is_adjacent_empty(map: Node, tile: Vector2i, pp: Vector2i) -> bool:
	if abs(tile.x - pp.x) + abs(tile.y - pp.y) != 1: return false
	if not bool(map.call("is_walkable", tile)): return false
	return map.call("get_entity_at", tile) == null


func get_usage_config() -> Dictionary:
	return {"limit": 1, "reset": "floor"}


func compute_valid_targets(map: Node, pp: Vector2i, _attrs: Dictionary) -> Array:
	var result: Array = []
	for step: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var tile := pp + step
		if _is_adjacent_empty(map, tile, pp):
			result.append(tile)
	return result


func use_targeted(_tile: Vector2i) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var wil: int = int(gs.get("effective_attributes").get("wil", 0))
	_active_turns = 6
	_turn_counter = 0
	_notify("Totem Curativo attivo! +%d HP ogni %d turni." % [maxi(1, wil / 4), HEAL_INTERVAL])
	_combat_log("Lo Sciamano evoca il Totem Curativo.")


func on_turn_end() -> void:
	if _active_turns <= 0:
		return
	_active_turns -= 1
	_turn_counter += 1
	if _turn_counter >= HEAL_INTERVAL:
		_turn_counter = 0
		var gs: Node = _gs()
		if gs:
			var wil: int  = int(gs.get("effective_attributes").get("wil", 0))
			var heal: int = maxi(1, wil / 4)
			gs.call("heal_player", heal)
	if _active_turns <= 0:
		_combat_log("Il Totem Curativo svanisce.")


func on_floor_changed() -> void:
	_active_turns = 0
	_turn_counter = 0
