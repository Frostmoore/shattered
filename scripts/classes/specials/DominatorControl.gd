extends ClassSpecial
# active_target: controlla un nemico adiacente per WIL/3 turni. Costo: 30 MP.

const MP_COST: int = 30


func compute_valid_targets(map: Node, pp: Vector2i, attrs: Dictionary) -> Array:
	var results: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for d: Vector2i in dirs:
		var t: Vector2i = pp + d
		if _enemy_at_tile(map, t) != null:
			results.append(t)
	return results


func use_targeted(tile: Vector2i) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)." % MP_COST)
		return
	var map: Node = _get_map()
	if not map:
		return
	var enemy: Node = _enemy_at_tile(map, tile)
	if not is_instance_valid(enemy):
		_notify("Nessun nemico valido.")
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	var attrs: Dictionary = gs.get("effective_attributes")
	var duration: int = maxi(1, int(attrs.get("wil", 0)) / 3)
	var sem: Node = _runtime.get_node_or_null("/root/StatusEffectManager") if _runtime else null
	if sem:
		sem.call("apply", enemy, {
			"id":             "dominated",
			"source":         "player",
			"duration_turns": duration,
			"stacking":       "replace",
			"data":           {}
		})
	_notify("Controllo Mentale: %s controllato per %d turni!" % [
		str(enemy.get("display_name")), duration])
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
