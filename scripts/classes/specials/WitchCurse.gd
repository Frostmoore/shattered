extends ClassSpecial
# Maledizione: tutti gli stat del nemico -20% per 5 turni. 10 MP.

func _enemy_at_tile(map: Node, tile: Vector2i) -> Node:
	var e: Variant = map.call("get_entity_at", tile)
	if e == null or not is_instance_valid(e): return null
	if str(e.get("faction")) != "enemy" or bool(e.get("is_dead")): return null
	return e as Node

const MP_COST:   int   = 10
const DURATION:  int   = 5
const STAT_MULT: float = 0.80


func compute_valid_targets(map: Node, _pp: Vector2i, _attrs: Dictionary) -> Array:
	var result: Array = []
	var w: int = int(map.get("map_width"))
	var h: int = int(map.get("map_height"))
	for y: int in range(h):
		for x: int in range(w):
			var tile := Vector2i(x, y)
			if int(map.call("is_tile_visible", tile)) == 0:
				continue
			if _enemy_at_tile(map, tile) != null:
				result.append(tile)
	return result


func use_targeted(tile: Vector2i) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)" % MP_COST)
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	var map: Node = _get_map()
	if not map:
		return
	var enemy: Node = _enemy_at_tile(map, tile)
	if not enemy:
		return
	var sem: Node = _runtime.get_node_or_null("/root/StatusEffectManager")
	if sem:
		sem.call("apply", enemy, {
			"id": "curse", "source": "strega",
			"duration_turns": DURATION, "stacking": "refresh",
			"data": {"atk_mult": STAT_MULT}
		})
	_combat_log("Maledizione su %s: ATK -20%% per %d turni." % [
		str(enemy.get("display_name")), DURATION])
