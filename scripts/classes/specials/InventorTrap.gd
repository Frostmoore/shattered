extends ClassSpecial
# Trappola: tile adiacente libero. Esplode (INT×2) quando un nemico ci calpesta.

func _is_adjacent_empty(map: Node, tile: Vector2i, pp: Vector2i) -> bool:
	if abs(tile.x - pp.x) + abs(tile.y - pp.y) != 1: return false
	if not bool(map.call("is_walkable", tile)): return false
	return map.call("get_entity_at", tile) == null

const MAX_TRAPS: int = 3

var _traps: Array = []   # [{pos: Vector2i, damage: int}]


func compute_valid_targets(map: Node, pp: Vector2i, _attrs: Dictionary) -> Array:
	var result: Array = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if abs(dx) + abs(dy) != 1:
				continue
			var tile := pp + Vector2i(dx, dy)
			if _is_adjacent_empty(map, tile, pp):
				result.append(tile)
	return result


func use_targeted(tile: Vector2i) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var dmg: int = int(gs.get("effective_attributes").get("int", 0)) * 2
	if _traps.size() >= MAX_TRAPS:
		_traps.remove_at(0)
	_traps.append({"pos": tile, "damage": dmg})
	_combat_log("Trappola piazzata su (%d,%d) — %d danni." % [tile.x, tile.y, dmg])


func on_entity_at_position(entity: Node, pos: Vector2i) -> void:
	if not is_instance_valid(entity) or bool(entity.get("is_dead")):
		return
	if str(entity.get("faction")) != "enemy":
		return
	for i: int in range(_traps.size() - 1, -1, -1):
		if _traps[i].get("pos") == pos:
			var dmg: int = int(_traps[i].get("damage", 0))
			entity.call("take_damage", dmg)
			_traps.remove_at(i)
			_combat_log("BOOM! Trappola su %s: %d danni!" % [
				str(entity.get("display_name")), dmg])
			return


func on_floor_changed() -> void:
	_traps.clear()
