extends ClassSpecial
# Schivata: DEX/100 probabilità di evadere (cap 40%).

func on_before_player_damaged(ctx) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var dex: int = int(gs.get("effective_attributes").get("dex", 0))
	var chance: float = minf(float(dex) / 100.0, 0.40)
	if randf() < chance:
		ctx.set("cancelled", true)
		_combat_log("Il Monaco schiva l'attacco!")
