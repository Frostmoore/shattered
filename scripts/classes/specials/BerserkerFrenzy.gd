extends ClassSpecial
# Frenesia Totale: in combattimento ATK +40%. Non può usare oggetti.

const ATK_BONUS: float = 1.40


func on_before_player_attack(ctx) -> void:
	var tm: Node = _runtime.get_node_or_null("/root/TurnManager")
	if tm and bool(tm.get("is_active")):
		ctx.set("attack_multiplier", float(ctx.get("attack_multiplier")) * ATK_BONUS)


func blocks_item_use_in_combat() -> bool:
	var tm: Node = _runtime.get_node_or_null("/root/TurnManager")
	return tm != null and bool(tm.get("is_active"))
