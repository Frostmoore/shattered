extends ClassSpecial
# Proiettile Arcano: danno INT a distanza (range INT/3 tile, min 2). 5 MP.

func _enemy_at_tile(map: Node, tile: Vector2i) -> Node:
	var e: Variant = map.call("get_entity_at", tile)
	if e == null or not is_instance_valid(e): return null
	if str(e.get("faction")) != "enemy" or bool(e.get("is_dead")): return null
	return e as Node

const MP_COST: int = 5


func get_usage_config() -> Dictionary:
	return {}


func compute_valid_targets(map: Node, pp: Vector2i, attrs: Dictionary) -> Array:
	var result: Array = []
	var int_v: int   = int(attrs.get("int", 0))
	var range_t: int = maxi(2, int_v / 3)
	var w: int = int(map.get("map_width"))
	var h: int = int(map.get("map_height"))
	for y: int in range(h):
		for x: int in range(w):
			var tile := Vector2i(x, y)
			if int(map.call("is_tile_visible", tile)) == 0:
				continue
			if abs(tile.x - pp.x) + abs(tile.y - pp.y) > range_t:
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
	var int_v: int = int(gs.get("effective_attributes").get("int", 0))
	_deal_damage(_get_player(), enemy, int_v, true, "magic")
	_combat_log("Proiettile Arcano: %d danni a %s!" % [int_v, str(enemy.get("display_name"))])
