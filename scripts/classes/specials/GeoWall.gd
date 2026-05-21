extends ClassSpecial
# Muro di Terra: tile adiacente libero bloccato per VIT/3 turni.

func _is_adjacent_empty(map: Node, tile: Vector2i, pp: Vector2i) -> bool:
	if abs(tile.x - pp.x) + abs(tile.y - pp.y) != 1: return false
	if not bool(map.call("is_walkable", tile)): return false
	return map.call("get_entity_at", tile) == null

var _wall_tile:        Vector2i = Vector2i(-1, -1)
var _wall_turns_left:  int      = 0


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
	if _wall_tile != Vector2i(-1, -1):
		_remove_wall()
	var vit: int = int(gs.get("effective_attributes").get("vit", 0))
	var dur: int = maxi(2, vit / 3)
	var map: Node = _get_map()
	if not map:
		return
	var blocked: Dictionary = map.get("_blocked_tiles")
	blocked[tile] = true
	_wall_tile       = tile
	_wall_turns_left = dur
	_force_redraw(map)
	_combat_log("Muro di Terra su (%d,%d) per %d turni." % [tile.x, tile.y, dur])


func on_turn_end() -> void:
	if _wall_tile == Vector2i(-1, -1) or _wall_turns_left <= 0:
		return
	_wall_turns_left -= 1
	if _wall_turns_left <= 0:
		_remove_wall()
		_combat_log("Il muro di terra crolla.")


func on_floor_changed() -> void:
	_wall_tile       = Vector2i(-1, -1)
	_wall_turns_left = 0


func _remove_wall() -> void:
	var map: Node = _get_map()
	if map and _wall_tile != Vector2i(-1, -1):
		var blocked: Dictionary = map.get("_blocked_tiles")
		blocked.erase(_wall_tile)
		_force_redraw(map)
	_wall_tile = Vector2i(-1, -1)


func _force_redraw(map: Node) -> void:
	var renderer: Node = map.get_node_or_null("MapRenderer")
	if renderer:
		renderer.queue_redraw()
