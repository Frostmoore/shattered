extends Node

const HIT_CHANCE: float = 0.80


func attack(attacker: Entity, defender: Entity) -> void:
	if randf() > HIT_CHANCE:
		EventBus.combat_log.emit("%s manca %s!" % [attacker.display_name, defender.display_name])
		return
	var dmg: int = maxi(1, attacker.attack - defender.defense)
	defender.take_damage(dmg)
	EventBus.combat_log.emit("%s colpisce %s per %d danni!" % [attacker.display_name, defender.display_name, dmg])
