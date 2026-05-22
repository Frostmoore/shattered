extends Entity
class_name Enemy

var enemy_data_id: String = ""
var detection_range: int = 5
var xp_reward: int = 0
var is_boss: bool = false
var affixes: Array = []
var _alerted: bool = false


func setup(data: Dictionary) -> void:
	enemy_data_id   = data.get("id", "unknown_enemy")
	display_name    = data.get("name", "Enemy")
	level           = int(data.get("level", GameState.level))
	dex             = int(data.get("dex", 5))
	xp_reward       = data.get("xp_reward", 0)
	is_boss         = bool(data.get("boss", false))
	detection_range = int(data.get("detection_range", 5))
	faction         = "enemy"

	_apply_runtime_stats(data)
	affixes = data.get("affixes", []) as Array

	var char: String = "e"
	var col: Color   = Color(0.88, 0.28, 0.28, 1)
	var entry: Dictionary = EnemyRegistry.get_enemy_data(enemy_data_id)
	if not entry.is_empty():
		char = str(entry["char"])
		var c: Array = entry["color"] as Array
		col = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	if is_boss:
		char = char.to_upper()
		col = Color(1.0, 0.15, 0.15, 1.0)

	# Apply affix prefix to name and color tint (last affix tint wins)
	var affix_ids: Array = data.get("affixes", []) as Array
	var prefix_parts: Array = []
	for affix_id: Variant in affix_ids:
		var affix: Dictionary = AffixRegistry.get_affix(str(affix_id))
		if affix.is_empty():
			continue
		var pfx: String = str(affix.get("prefix", ""))
		if pfx != "":
			prefix_parts.append(pfx)
		if affix.has("color_tint") and not is_boss:
			var t: Array = affix["color_tint"] as Array
			col = Color(float(t[0]), float(t[1]), float(t[2]), float(t[3]))
	if not prefix_parts.is_empty():
		display_name = " ".join(prefix_parts) + " " + display_name

	_setup_visual(char, col)


func _apply_runtime_stats(data: Dictionary) -> void:
	var template: Dictionary = EnemyRegistry.get_enemy_data(enemy_data_id)
	if template.is_empty():
		# Fallback: use baked values if registry lookup fails (unknown id or old save)
		hp      = int(data.get("hp", 8))
		max_hp  = hp
		attack  = int(data.get("attack", 3))
		defense = int(data.get("defense", 0))
		return

	# Enemy level = player level offset by floor depth and tier, clamped to zone range
	var floor_num:   int = int(data.get("floor_num", 1))
	var tier:        int = int(template.get("tier", 3))
	var zone_min:    int = int(template.get("zone_min_level", 1))
	var zone_max:    int = int(template.get("zone_max_level", 50))
	var floor_bonus: int = floori(float(floor_num - 1) / 5.0)
	var enemy_level: int = clampi(GameState.level + floor_bonus + (tier - 3), zone_min, zone_max)
	level = enemy_level

	var lf:      float = BalanceCombat.level_factor(enemy_level)
	var lf_base: float = BalanceCombat.level_factor(1)

	var base_hp:  int = roundi(float(int(template["hp_base"])) * lf / lf_base)
	var base_atk: int = int(template["atk_base"]) + floori(float(enemy_level - 1) * float(template.get("atk_growth", 0.15)))
	var base_def: int = maxi(0, int(template["def_base"]) + floori(float(enemy_level - 1) * float(template.get("def_growth", 0.05))))

	# Affix multipliers (applied before boss multipliers so boss stacks on top)
	var affix_ids: Array  = data.get("affixes", []) as Array
	var aff_hp:   float   = 1.0
	var aff_atk:  float   = 1.0
	var aff_def:  float   = 1.0
	var aff_dex:  float   = 1.0
	var aff_xp:   float   = 1.0
	for affix_id: Variant in affix_ids:
		var affix: Dictionary = AffixRegistry.get_affix(str(affix_id))
		if affix.is_empty():
			continue
		aff_hp  *= float(affix.get("hp_mult",  1.0))
		aff_atk *= float(affix.get("atk_mult", 1.0))
		aff_def *= float(affix.get("def_mult", 1.0))
		aff_dex *= float(affix.get("dex_mult", 1.0))
		aff_xp  *= float(affix.get("xp_mult",  1.0))

	base_hp  = roundi(float(base_hp)  * aff_hp)
	base_atk = roundi(float(base_atk) * aff_atk)
	base_def = maxi(0, roundi(float(base_def) * aff_def))
	dex      = roundi(float(dex) * aff_dex)
	xp_reward = roundi(float(xp_reward) * aff_xp)

	if is_boss:
		var hp_mult:  float = float(data.get("boss_hp_mult",  1.8))
		var atk_mult: float = float(data.get("boss_atk_mult", 1.2))
		var def_mult: float = float(data.get("boss_def_mult", 1.3))
		hp      = roundi(float(base_hp)  * hp_mult)
		attack  = roundi(float(base_atk) * atk_mult)
		defense = roundi(float(base_def) * def_mult)
	else:
		hp      = base_hp
		attack  = base_atk
		defense = base_def
	max_hp = hp


func take_turn() -> void:
	if is_dead:
		return
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return
	var player: Node = map.get_player()
	if player == null or player.is_dead:
		return

	var sem: Node = get_node_or_null("/root/StatusEffectManager")

	# Controlla trappole alla posizione corrente
	var runtime_trap: Node = get_node_or_null("/root/ClassRuntime")
	if runtime_trap:
		runtime_trap.call("check_entity_at_position", self, grid_position)
	if is_dead:
		return   # trappola potrebbe aver ucciso il nemico

	# Stordito: salta il turno
	if sem and sem.call("has_effect", self, "stun"):
		EventBus.combat_log.emit("%s è stordito e salta il turno!" % display_name)
		sem.call("tick", self)
		EventBus.turn_ended.emit(self)
		return

	# Rallentato: salta ogni altro turno
	if sem and sem.call("has_effect", self, "slow"):
		var slow_eff: Dictionary = sem.call("get_effect", self, "slow")
		var skip: bool = bool(slow_eff.get("data", {}).get("skip_this_turn", false))
		slow_eff.get("data", {})["skip_this_turn"] = not skip
		if skip:
			EventBus.combat_log.emit("%s è rallentato e salta questo turno." % display_name)
			sem.call("tick", self)
			EventBus.turn_ended.emit(self)
			return

	var target: Node = _find_nearest_hostile(map, player)
	if target != null:
		var dist: int = _manhattan(grid_position, target.grid_position)
		if dist <= 1:
			_alerted = true
			CombatManager.attack(self, target)
		else:
			var eff_range: int = detection_range
			if target == player and not _alerted:
				var cr: Node = get_node_or_null("/root/ClassRuntime")
				if cr:
					var cap: int = int(cr.call("get_detection_range_cap"))
					if cap >= 0:
						eff_range = mini(detection_range, cap)
			if dist <= eff_range:
				_alerted = true
				_move_toward(target.grid_position, map)

	# Bruciatura: danno prima del tick
	if sem and sem.call("has_effect", self, "burn") and not is_dead:
		var burn_eff: Dictionary = sem.call("get_effect", self, "burn")
		var burn_dmg: int = int(burn_eff.get("data", {}).get("dmg_per_turn", 0))
		if burn_dmg > 0:
			take_damage(burn_dmg)
			if not is_dead:
				EventBus.combat_log.emit("%s brucia per %d danni!" % [display_name, burn_dmg])

	if sem and not is_dead:
		sem.call("tick", self)
	if not is_dead:
		EventBus.turn_ended.emit(self)


func _move_toward(target: Vector2i, map: BaseMap) -> void:
	var dx: int = int(sign(target.x - grid_position.x))
	var dy: int = int(sign(target.y - grid_position.y))
	var options: Array[Vector2i] = []
	if abs(target.x - grid_position.x) >= abs(target.y - grid_position.y):
		options = [Vector2i(dx, 0), Vector2i(0, dy)]
	else:
		options = [Vector2i(0, dy), Vector2i(dx, 0)]

	for step: Vector2i in options:
		if step == Vector2i.ZERO:
			continue
		var candidate: Vector2i = grid_position + step
		if not map.is_walkable(candidate):
			continue
		var entity_at: Node = map.get_entity_at(candidate)
		if entity_at == null:
			move_to(candidate)
			return
		# Open closed doors instead of blocking
		if entity_at.get("is_open") != null and not bool(entity_at.get("is_open")):
			entity_at.call("open")
			return


func _find_nearest_hostile(_map: BaseMap, player: Node) -> Node:
	var best: Node = null
	var best_d: int = 999999

	if not player.is_dead:
		var d: int = _manhattan(grid_position, player.grid_position)
		if d < best_d:
			best_d = d
			best = player

	var ally_mgr: Node = get_node_or_null("/root/AllyManager")
	if ally_mgr:
		for a: Variant in ally_mgr.call("get_allies"):
			if not is_instance_valid(a):
				continue
			if bool(a.get("is_dead")) or bool(a.get("is_pet")):
				continue
			var ap: Vector2i = a.get("grid_position") as Vector2i
			var d: int = _manhattan(grid_position, ap)
			if d < best_d:
				best_d = d
				best = a as Node

	return best


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func die() -> void:
	is_dead = true
	TurnManager.unregister_enemy(self)
	var map: BaseMap = get_parent() as BaseMap
	if map != null:
		map.add_corpse(grid_position, entity_color.darkened(0.5))
	EventBus.enemy_died.emit(self)
	QuestManager.on_enemy_killed(enemy_data_id)
	if is_boss:
		QuestManager.on_enemy_killed("dungeon_boss")
	LevelSystem.add_xp(xp_reward)
	queue_free()
