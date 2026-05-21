extends ClassSpecial
# Posizione di Guardia: ogni turno senza muoversi né attaccare DEF ×(1+stacks), max ×4.
# Si azzera al primo movimento o attacco.

const MAX_STACKS: int = 3

var _guard_stacks:   int  = 0
var _acted_this_turn: bool = false


func on_combat_start() -> void:
	_guard_stacks    = 0
	_acted_this_turn = false


func on_floor_changed() -> void:
	_guard_stacks    = 0
	_acted_this_turn = false


func on_before_player_attack(ctx) -> void:
	_acted_this_turn = true
	if _guard_stacks > 0:
		_guard_stacks = 0
		_combat_log("Sentinella: guardia persa (attacco).")


func on_player_moved() -> void:
	_acted_this_turn = true
	if _guard_stacks > 0:
		_guard_stacks = 0


func on_turn_end() -> void:
	if _acted_this_turn:
		_acted_this_turn = false
		return
	if _guard_stacks < MAX_STACKS:
		_guard_stacks += 1
		var mult: int = _guard_stacks + 1
		_combat_log("Sentinella: %d stack → DEF ×%d." % [_guard_stacks, mult])


func on_before_player_damaged(ctx) -> void:
	if _guard_stacks <= 0:
		return
	var gs: Node = _gs()
	if not gs:
		return
	var base_def: int = int(gs.get("player_stats").get("defense", 0))
	var equip: Node   = _runtime.get_node_or_null("/root/Equipment")
	if equip:
		base_def += int(equip.call("get_defense_bonus"))
	ctx.set("defense_bonus", int(ctx.get("defense_bonus")) + base_def * _guard_stacks)
