extends ClassSpecial
# passive: 50% miss rate; wall-phasing con profondità max 3 tile dal walkable più vicino;
# nemici non si allertano oltre 1 tile.

const MAX_DEPTH: int = 3


func can_phase_walls() -> bool:
	return true


func can_enter_wall_at(map: Node, target: Vector2i) -> bool:
	var w: int = int(map.get("map_width"))
	var h: int = int(map.get("map_height"))
	for dy: int in range(-MAX_DEPTH, MAX_DEPTH + 1):
		for dx: int in range(-MAX_DEPTH, MAX_DEPTH + 1):
			if abs(dx) + abs(dy) > MAX_DEPTH:
				continue
			var t: Vector2i = target + Vector2i(dx, dy)
			if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h:
				continue
			if not bool(map.call("is_blocked_tile", t)):
				return true
	return false


func get_detection_range_cap() -> int:
	return 2


func on_before_player_damaged(ctx) -> void:
	if randf() < 0.50:
		ctx.set("cancelled", true)
		_combat_log("Incorporeità: l'attacco attraversa lo Spettro!")
