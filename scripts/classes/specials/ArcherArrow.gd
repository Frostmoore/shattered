extends ClassSpecial
# Freccia Precisa: attacco fisico a distanza (range DEX/4, min 2). Cooldown 2 turni.

func _enemy_at_tile(map: Node, tile: Vector2i) -> Node:
	var e: Variant = map.call("get_entity_at", tile)
	if e == null or not is_instance_valid(e): return null
	if str(e.get("faction")) != "enemy" or bool(e.get("is_dead")): return null
	return e as Node

const COOLDOWN: int = 2


func get_usage_config() -> Dictionary:
	return {"cooldown_turns": COOLDOWN}


func compute_valid_targets(map: Node, pp: Vector2i, attrs: Dictionary) -> Array:
	var result: Array = []
	var dex: int     = int(attrs.get("dex", 0))
	var range_t: int = maxi(2, dex / 4)
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
	var map: Node = _get_map()
	if not map:
		return
	var enemy: Node = _enemy_at_tile(map, tile)
	if not enemy:
		return
	var player: Node = _get_player()
	var dmg: int = player.attack if player else 0
	_deal_damage(player, enemy, dmg, false, "physical")
	_combat_log("Freccia Precisa: colpisce %s!" % str(enemy.get("display_name")))
