extends Node

const CTX_SCRIPT:   String = "res://scripts/combat/DamageContext.gd"
const FLOAT_SCRIPT: String = "res://scripts/ui/FloatingText.gd"

var _float_spawn_count: int = 0


func attack(attacker: Entity, defender: Entity) -> void:
	# Gate: player attacking an NPC requires Amuleto del Sangue
	if attacker.faction == "player" and defender.get("npc_id") != null:
		if not _can_attack_npc():
			EventBus.notification_shown.emit(Notification.warning(
				LocaleManager.t_or("WARN_NEED_AMULETO", "Serve l'Amuleto del Sangue per attaccare un civile.")))
			return
		CrimeSystem.track_attacked_npc(defender)
		_check_and_register_crime()

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
		if attacker.get("is_guard") == true and defender.faction == "player":
			var cur_hp: int = int(GameState.player_stats.get("hp", 1))
			dmg = max(0, min(dmg, cur_hp - CrimeSystem.CRIME_GUARD_MIN_HP))
		defender.take_damage(dmg)
		EventBus.combat_log.emit("%s colpisce %s per %d danni!" % [
			attacker.display_name, defender.display_name, dmg])
		_spawn_float(str(dmg), defender.position, _damage_color(defender), _damage_dir(defender))
		_check_guard_arrest(attacker, defender)
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
		_check_guard_arrest(attacker, defender)


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
	ft.position = world_pos + Vector2(0.0, -float(_float_spawn_count) * 12.0)
	scene.add_child(ft)
	ft.setup(text, color, dir_x)
	_float_spawn_count += 1
	if _float_spawn_count == 1:
		call_deferred("_reset_float_spawn_count")


func _reset_float_spawn_count() -> void:
	_float_spawn_count = 0


func _can_attack_npc() -> bool:
	var equip: Node = get_node_or_null("/root/Equipment")
	if equip:
		return bool(equip.call("is_equipped", "amuleto_del_sangue"))
	for slot_val: Variant in GameState.equipped.values():
		if str(slot_val) == "amuleto_del_sangue":
			return true
	return false


func _check_and_register_crime() -> void:
	var city_id: String = GameState.current_city_id
	if city_id == "" or CrimeSystem.is_crime_active(city_id):
		return
	if CrimeSystem.has_witnesses(GameState.player_position):
		CrimeSystem.register_crime(city_id)


func _check_guard_arrest(attacker: Entity, defender: Entity) -> void:
	if attacker.get("is_guard") != true or defender.faction != "player":
		return
	var hp: int = int(GameState.player_stats.get("hp", 0))
	if hp > CrimeSystem.CRIME_GUARD_MIN_HP:
		return
	GameState.player_stats["hp"] = CrimeSystem.CRIME_GUARD_MIN_HP
	EventBus.player_stats_changed.emit()
	var city_id: String = GameState.current_city_id
	if city_id != "" and CrimeSystem.is_crime_active(city_id):
		CrimeSystem.arrest_player(city_id)
