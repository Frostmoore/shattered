extends ClassSpecial
# Colpo Sporco: ogni attacco fisico ha 35% di chance di stordire il nemico (1 turno).

const STUN_CHANCE: float = 0.35


func on_after_player_attack(ctx) -> void:
	if bool(ctx.get("cancelled")):
		return
	var defender: Node = ctx.get("defender") as Node
	if not is_instance_valid(defender) or bool(defender.get("is_dead")):
		return
	if randf() > STUN_CHANCE:
		return
	var sem: Node = _runtime.get_node_or_null("/root/StatusEffectManager")
	if not sem:
		return
	sem.call("apply", defender, {
		"id": "stun", "source": "corsaro",
		"duration_turns": 1, "stacking": "replace",
		"data": {}
	})
	_combat_log("Colpo Sporco! %s è stordito per 1 turno." % str(defender.get("display_name")))
