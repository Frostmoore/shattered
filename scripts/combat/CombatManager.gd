extends Node

const HIT_CHANCE: float  = 0.80
const CTX_SCRIPT: String = "res://scripts/combat/DamageContext.gd"


func attack(attacker: Entity, defender: Entity) -> void:
	if randf() > HIT_CHANCE:
		EventBus.combat_log.emit("%s manca %s!" % [attacker.display_name, defender.display_name])
		return

	var ctx: Object = load(CTX_SCRIPT).new()
	ctx.set("attacker",    attacker)
	ctx.set("defender",    defender)
	ctx.set("base_damage", attacker.attack)
	ctx.set("damage_type", "physical")

	var pipeline: Node = get_node_or_null("/root/DamagePipeline")
	if pipeline:
		pipeline.execute(ctx)
	else:
		# Fallback se la pipeline non è ancora caricata
		var dmg: int = maxi(1, attacker.attack - defender.defense)
		defender.take_damage(dmg)
		EventBus.combat_log.emit("%s colpisce %s per %d danni!" % [
			attacker.display_name, defender.display_name, dmg])
		return

	if bool(ctx.get("cancelled")):
		EventBus.combat_log.emit("%s schiva l'attacco!" % defender.display_name)
	else:
		var final_dmg: int = int(ctx.get("final_damage"))
		EventBus.combat_log.emit("%s colpisce %s per %d danni!" % [
			attacker.display_name, defender.display_name, final_dmg])
		if attacker.faction == "player":
			EventBus.damage_dealt.emit(final_dmg, "player")
		if defender.faction == "player":
			EventBus.damage_taken.emit(final_dmg)
