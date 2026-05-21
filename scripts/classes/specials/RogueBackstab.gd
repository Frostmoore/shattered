extends ClassSpecial
# Pugnalata: primo attacco in ogni combattimento × 3 danno.
# Si azzera a inizio combattimento (on_combat_start).

var _first_attack: bool = true


func on_combat_start() -> void:
	_first_attack = true


func on_before_player_attack(ctx) -> void:
	if not _first_attack:
		return
	ctx.set("attack_multiplier", float(ctx.get("attack_multiplier")) * 3.0)
	_first_attack = false
	_combat_log("Pugnalata! ×3 danno.")
