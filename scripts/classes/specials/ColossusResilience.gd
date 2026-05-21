extends ClassSpecial
# passive: rigenera VIT/2 HP per turno in combattimento.
# Immune a stordimento/rallentamento (stubs — StatusEffectManager non applica se la spec è attiva).

func on_turn_end() -> void:
	var tm: Node = _runtime.get_node_or_null("/root/TurnManager") if _runtime else null
	if not tm:
		return
	if not bool(tm.get("_in_combat")):
		return
	var gs: Node = _gs()
	if not gs:
		return
	var attrs: Dictionary = gs.get("effective_attributes")
	var regen: int = maxi(1, int(attrs.get("vit", 0)) / 2)
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("hp", 0)) < int(stats.get("max_hp", 0)):
		GameState.heal_player(regen)
		_combat_log("Resilienza: +%d HP." % regen)
