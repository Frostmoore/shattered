extends ClassSpecial
# passive: secondo colpo al 50% del danno finale dopo ogni attacco del player.

var _hitting_second: bool = false


func on_after_player_attack(ctx) -> void:
	if _hitting_second:
		return
	var defender: Node = ctx.get("defender") as Node
	if not is_instance_valid(defender):
		return
	if bool(defender.get("is_dead")):
		return
	var final_dmg: int = int(ctx.get("final_damage"))
	if final_dmg <= 0:
		return
	var second_hit: int = maxi(1, final_dmg / 2)
	_hitting_second = true
	var attacker: Node = ctx.get("attacker") as Node
	_deal_damage(attacker, defender, second_hit, false, "physical")
	_hitting_second = false
	_combat_log("Doppio Colpo: secondo colpo per %d." % second_hit)
