extends Entity
class_name Ally

var ally_type: String = ""
var atk_mult: float = 1.0
var permanent: bool = false
var turns_left: int = -1
var detection_range: int = 8
var is_pet: bool = false

const _GLYPHS: Dictionary = {
	"wolf":             ["w", Color(0.4,  0.9,  0.4,  1.0)],
	"undead":           ["z", Color(0.7,  0.3,  0.9,  1.0)],
	"demon":            ["d", Color(0.8,  0.1,  0.1,  1.0)],
	"elemental_fire":   ["f", Color(1.0,  0.5,  0.1,  1.0)],
	"elemental_water":  ["~", Color(0.2,  0.6,  0.9,  1.0)],
	"elemental_earth":  ["E", Color(0.55, 0.38, 0.18, 1.0)],
}


func setup(data: Dictionary) -> void:
	ally_type    = str(data.get("type", "ally"))
	display_name = str(data.get("display_name", "Alleato"))
	hp           = int(data.get("hp", 10))
	max_hp       = int(data.get("max_hp", hp))
	atk_mult     = float(data.get("atk_mult", 1.0))
	permanent    = bool(data.get("permanent", false))
	turns_left   = int(data.get("turns_left", -1))
	is_pet       = bool(data.get("is_pet", false))
	faction      = "ally"

	var glyph: Array = (_GLYPHS.get(ally_type, ["a", Color(0.4, 0.9, 0.4, 1.0)]) as Array)
	_setup_visual(str(glyph[0]), glyph[1] as Color)


func take_turn() -> void:
	if is_dead:
		return
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return

	var sem: Node = get_node_or_null("/root/StatusEffectManager")

	if sem and sem.call("has_effect", self, "stun"):
		EventBus.combat_log.emit("%s è stordito e salta il turno!" % display_name)
		sem.call("tick", self)
		EventBus.turn_ended.emit(self)
		return

	var target: Node = _nearest_enemy()
	if target != null:
		var dist: int = _manhattan(grid_position, target.grid_position)
		if dist <= 1:
			_attack(target)
		elif dist <= detection_range:
			_move_toward(target.grid_position, map)

	if sem and not is_dead:
		sem.call("tick", self)
	if not is_dead:
		EventBus.turn_ended.emit(self)


func to_dict() -> Dictionary:
	return {
		"type":         ally_type,
		"display_name": display_name,
		"hp":           hp,
		"max_hp":       max_hp,
		"atk_mult":     atk_mult,
		"permanent":    permanent,
		"turns_left":   turns_left,
		"is_pet":       is_pet,
	}


func die() -> void:
	is_dead = true
	var ally_mgr: Node = get_node_or_null("/root/AllyManager")
	if ally_mgr:
		ally_mgr.call("_on_ally_died", self)
	EventBus.combat_log.emit("%s è caduto!" % display_name)
	queue_free()


func _attack(target: Node) -> void:
	var player_atk: int = int(GameState.player_stats.get("attack", 4))
	var dmg: int = maxi(1, int(float(player_atk) * atk_mult))
	target.call("take_damage", dmg)
	EventBus.combat_log.emit("%s attacca %s per %d!" % [
		display_name,
		str(target.get("display_name") or "nemico"),
		dmg
	])


func _nearest_enemy() -> Node:
	var tm: Node = get_node_or_null("/root/TurnManager")
	if tm == null:
		return null
	var enemies: Array = tm.get("_enemies")
	var best: Node = null
	var best_d: int = 999999
	for e: Variant in enemies:
		if not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		var ep: Vector2i = e.get("grid_position") as Vector2i
		var d: int = _manhattan(grid_position, ep)
		if d < best_d:
			best_d = d
			best = e as Node
	return best


func _move_toward(target_pos: Vector2i, map: BaseMap) -> void:
	var dx: int = int(sign(target_pos.x - grid_position.x))
	var dy: int = int(sign(target_pos.y - grid_position.y))
	var options: Array[Vector2i] = []
	if abs(target_pos.x - grid_position.x) >= abs(target_pos.y - grid_position.y):
		options = [Vector2i(dx, 0), Vector2i(0, dy)]
	else:
		options = [Vector2i(0, dy), Vector2i(dx, 0)]

	for step: Vector2i in options:
		if step == Vector2i.ZERO:
			continue
		var candidate: Vector2i = grid_position + step
		if not map.is_walkable(candidate):
			continue
		if map.get_entity_at(candidate) == null:
			move_to(candidate)
			return


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
