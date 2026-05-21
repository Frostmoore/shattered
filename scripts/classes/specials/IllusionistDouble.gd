extends ClassSpecial
# Sosia: per DEX/4 turni ogni attacco al player ha 50% di essere schivato.
# active_target: piazzato su tile adiacente (visivo/lore).

const DODGE_CHANCE: float = 0.50

var _dodge_turns: int = 0

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
	var dex: int  = int(gs.get("effective_attributes").get("dex", 0))
	_dodge_turns  = maxi(3, dex / 4)
	_notify("Sosia attivo! 50%% schivata per %d turni." % _dodge_turns)
	_combat_log("L'Illusionista crea un sosia.")


func on_before_player_damaged(ctx) -> void:
	if _dodge_turns <= 0:
		return
	if randf() < DODGE_CHANCE:
		ctx.set("cancelled", true)
		_combat_log("Il sosia inganna il nemico!")


func on_turn_end() -> void:
	if _dodge_turns <= 0:
		return
	_dodge_turns -= 1
	if _dodge_turns <= 0:
		_combat_log("Il sosia svanisce.")


func on_floor_changed() -> void:
	_dodge_turns = 0
