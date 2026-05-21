extends ClassSpecial
# Analisi: rivela stats di un nemico adiacente. Azione libera.

func _enemy_at_tile(map: Node, tile: Vector2i) -> Node:
	var e: Variant = map.call("get_entity_at", tile)
	if e == null or not is_instance_valid(e): return null
	if str(e.get("faction")) != "enemy" or bool(e.get("is_dead")): return null
	return e as Node

func compute_valid_targets(map: Node, pp: Vector2i, _attrs: Dictionary) -> Array:
	var result: Array = []
	for step: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var tile := pp + step
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
	_combat_log("Analisi — %s%s: HP %d/%d | ATK %d | DEF %d" % [
		str(enemy.get("display_name")),
		" [BOSS]" if bool(enemy.get("is_boss")) else "",
		int(enemy.get("hp")), int(enemy.get("max_hp")),
		int(enemy.get("attack")), int(enemy.get("defense"))])
	_notify("Analisi di %s completata." % str(enemy.get("display_name")))
