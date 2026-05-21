class_name ClassSpecial
extends RefCounted

# Base per tutte le abilità speciali.
# ClassRuntime chiama init_with_runtime() subito dopo l'istanziazione.

var _runtime: Node = null


func init_with_runtime(rt: Node) -> void:
	_runtime = rt


func get_usage_config() -> Dictionary:
	return {}


# ── Targeting: nuovo metodo principale ───────────────────────────────────────
# start_targeting chiama questo metodo con la mappa già ottenuta.
# Override nelle sottoclassi active_target — nessuna chiamata a _get_map() necessaria.
# Restituisce Array[Vector2i] con i tile validi.
func compute_valid_targets(_map: Node, _pp: Vector2i, _attrs: Dictionary) -> Array:
	return []


# Helper per compute_valid_targets: nemico vivo sul tile dato (mappa passata direttamente)
func _enemy_at_tile(map: Node, tile: Vector2i) -> Node:
	var entity: Variant = map.call("get_entity_at", tile)
	if entity == null or not is_instance_valid(entity):
		return null
	if str(entity.get("faction")) != "enemy" or bool(entity.get("is_dead")):
		return null
	return entity as Node


# Helper: tile adiacente (manhattan=1), calpestabile e vuoto
func _is_adjacent_empty(map: Node, tile: Vector2i, pp: Vector2i) -> bool:
	if abs(tile.x - pp.x) + abs(tile.y - pp.y) != 1:
		return false
	if not bool(map.call("is_walkable", tile)):
		return false
	return map.call("get_entity_at", tile) == null


# ── Helper per accedere agli autoload (usati da use_targeted e dai hook) ─────

func _gs() -> Node:
	return _runtime.get_node_or_null("/root/GameState") if _runtime else null


func _eb() -> Node:
	return _runtime.get_node_or_null("/root/EventBus") if _runtime else null


func _get_map() -> Node:
	if not _runtime:
		return null
	var wm: Node = _runtime.get_node_or_null("/root/WorldManager")
	return wm.call("get_current_map") if wm else null


func _get_player() -> Node:
	var map: Node = _get_map()
	return map.call("get_player") if map else null


func _player_pos() -> Vector2i:
	var gs: Node = _gs()
	return gs.get("player_position") if gs else Vector2i.ZERO


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _deal_damage(attacker: Node, defender: Node, dmg: int,
		ignore_def: bool = false, dtype: String = "magic") -> void:
	if not _runtime:
		if is_instance_valid(defender):
			defender.call("take_damage", dmg)
		return
	var pipeline: Node = _runtime.get_node_or_null("/root/DamagePipeline")
	if not pipeline:
		if is_instance_valid(defender):
			defender.call("take_damage", dmg)
		return
	var ctx: Object = load("res://scripts/combat/DamageContext.gd").new()
	ctx.set("attacker",       attacker)
	ctx.set("defender",       defender)
	ctx.set("base_damage",    dmg)
	ctx.set("ignore_defense", ignore_def)
	ctx.set("damage_type",    dtype)
	pipeline.execute(ctx)


func _notify(text: String) -> void:
	var eb: Node = _eb()
	if eb:
		eb.notification_shown.emit(Notification.warning(text))


func _combat_log(text: String) -> void:
	var eb: Node = _eb()
	if eb:
		eb.combat_log.emit(text)


# ── Hook virtuali ──────────────────────────────────────────────────────────────

func uses_menu()                                -> bool: return false
func can_phase_walls()                          -> bool: return false
func can_enter_wall_at(_map: Node, _target: Vector2i) -> bool: return can_phase_walls()
func get_detection_range_cap()                  -> int:  return -1
func on_before_player_attack(_ctx)              -> void: pass
func on_after_player_attack(_ctx)               -> void: pass
func on_before_player_damaged(_ctx)             -> void: pass
func on_before_damage_apply(_ctx)               -> void: pass
func on_after_player_damaged(_ctx)              -> void: pass
func on_enemy_killed(_ctx)                      -> void: pass
func on_turn_end()                              -> void: pass
func on_floor_changed()                         -> void: pass
func on_combat_start()                          -> void: pass
func on_player_moved()                          -> void: pass
func blocks_item_use_in_combat()                -> bool: return false
func use_active()                               -> void: pass
func use_targeted(_tile: Vector2i)              -> void: pass
func on_entity_at_position(_e: Node, _pos: Vector2i) -> void: pass
