extends ClassSpecial
# Marchio: nemico designato riceve +50% danno da tutte le fonti. Max 1 bersaglio.

func _enemy_at_tile(map: Node, tile: Vector2i) -> Node:
	var e: Variant = map.call("get_entity_at", tile)
	if e == null or not is_instance_valid(e): return null
	if str(e.get("faction")) != "enemy" or bool(e.get("is_dead")): return null
	return e as Node

const DMG_MULT: float = 1.5


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
	var map: Node = _get_map()
	if not map:
		return
	var enemy: Node = _enemy_at_tile(map, tile)
	if not enemy:
		return
	var sem: Node = _runtime.get_node_or_null("/root/StatusEffectManager")
	if not sem:
		return
	var tm: Node = _runtime.get_node_or_null("/root/TurnManager")
	if tm:
		for e: Variant in tm.get("_enemies"):
			if is_instance_valid(e):
				sem.call("remove", e, "marked")
	sem.call("apply", enemy, {
		"id": "marked", "source": "cacciatore_di_taglie",
		"duration_turns": 999, "stacking": "replace",
		"data": {"dmg_taken_mult": DMG_MULT}
	})
	_notify("Marchio: %s subirà +50%% danno!" % str(enemy.get("display_name")))
	_combat_log("Il Cacciatore di Taglie designa %s." % str(enemy.get("display_name")))
