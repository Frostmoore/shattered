extends Node

const CTX_SCRIPT:   String = "res://scripts/combat/DamageContext.gd"
const FLOAT_SCRIPT: String = "res://scripts/ui/FloatingText.gd"


func attack(attacker: Entity, defender: Entity) -> void:
	var hit := _calc_hit(attacker, defender)
	if randf() > hit["chance"]:
		if hit["is_dodge"]:
			EventBus.combat_log.emit("%s schiva %s!" % [defender.display_name, attacker.display_name])
			_spawn_float("schivato", defender.position, Color(0.3, 0.85, 1.0))
		else:
			EventBus.combat_log.emit("%s manca %s!" % [attacker.display_name, defender.display_name])
			_spawn_float("mancato", defender.position, Color(0.55, 0.55, 0.55))
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
		var dmg: int = maxi(1, attacker.attack - defender.defense)
		defender.take_damage(dmg)
		EventBus.combat_log.emit("%s colpisce %s per %d danni!" % [
			attacker.display_name, defender.display_name, dmg])
		_spawn_float(str(dmg), defender.position, _damage_color(defender), _damage_dir(defender))
		return

	if bool(ctx.get("cancelled")):
		EventBus.combat_log.emit("%s schiva l'attacco!" % defender.display_name)
		_spawn_float("schivato", defender.position, Color(0.3, 0.85, 1.0))
	else:
		var final_dmg: int = int(ctx.get("final_damage"))
		EventBus.combat_log.emit("%s colpisce %s per %d danni!" % [
			attacker.display_name, defender.display_name, final_dmg])
		_spawn_float(str(final_dmg), defender.position, _damage_color(defender), _damage_dir(defender))
		if attacker.faction == "player":
			EventBus.damage_dealt.emit(final_dmg, "player")
		if defender.faction == "player":
			EventBus.damage_taken.emit(final_dmg)


func _calc_hit(attacker: Entity, defender: Entity) -> Dictionary:
	var hit_stat: float
	var dodge_stat: float
	if attacker.faction == "player":
		var attrs: Dictionary = GameState.effective_attributes
		match _player_combat_type():
			"melee":  hit_stat = (float(attrs.get("str", 5)) + float(attrs.get("dex", 5))) / 2.0
			"ranged": hit_stat = float(attrs.get("dex", 5))
			"magic":  hit_stat = (float(attrs.get("int", 5)) + float(attrs.get("wil", 5))) / 2.0
			_:        hit_stat = float(attrs.get("dex", 5))
		dodge_stat = float(defender.dex)
	else:
		hit_stat   = float(attacker.dex)
		dodge_stat = float(GameState.effective_attributes.get("dex", 5))
	var eff_hit:   float = hit_stat   + float(attacker.accuracy) * BalanceCombat.accuracy_multiplier(attacker.dex)
	var eff_dodge: float = dodge_stat + float(defender.evasion)  * BalanceCombat.accuracy_multiplier(defender.dex)
	return {
		"chance":   clampf(GameBalance.BASE_HIT_CHANCE + (eff_hit - eff_dodge) * GameBalance.ACCURACY_K,
		                   GameBalance.MIN_HIT_CHANCE, GameBalance.MAX_HIT_CHANCE),
		"is_dodge": eff_dodge > eff_hit,
	}


func _player_combat_type() -> String:
	var data: Dictionary = ClassRegistry.get_class_data(GameState.current_class)
	return str(data.get("combat_type", "melee"))


func _damage_color(defender: Entity) -> Color:
	if defender.faction == "player":
		return Color(1.0, 0.35, 0.35)
	return Color(1.0, 0.9, 0.3)


func _damage_dir(defender: Entity) -> float:
	return -1.0 if defender.faction == "player" else 1.0


func _spawn_float(text: String, world_pos: Vector2, color: Color, dir_x: float = 0.0) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var ft: Node2D = load(FLOAT_SCRIPT).new()
	ft.position = world_pos
	scene.add_child(ft)
	ft.setup(text, color, dir_x)
