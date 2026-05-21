extends ClassSpecial
# passive: ignora DEF nemica, aggiunge DEX/4 all'ATK come flat_bonus.

func on_before_player_attack(ctx) -> void:
	ctx.set("ignore_defense", true)
	var gs: Node = _gs()
	if not gs:
		return
	var attrs: Dictionary = gs.get("effective_attributes")
	var dex_bonus: int = int(attrs.get("dex", 0)) / 4
	if dex_bonus > 0:
		ctx.set("flat_bonus", int(ctx.get("flat_bonus")) + dex_bonus)
