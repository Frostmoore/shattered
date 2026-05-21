extends ClassSpecial
# Furia: sotto il 30% HP, ATK ×1.5.

func on_before_player_attack(ctx) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	var hp:     int = int(stats.get("hp",     1))
	var max_hp: int = int(stats.get("max_hp", 1))
	if max_hp > 0 and float(hp) / float(max_hp) < 0.30:
		ctx.set("attack_multiplier", float(ctx.get("attack_multiplier")) * 1.5)
