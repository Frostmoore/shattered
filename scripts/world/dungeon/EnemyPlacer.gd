class_name EnemyPlacer

## Places enemies using a pressure-budget system with role-based encounter composition.
## Each eligible room gets an archetype (name + 1-2 roles) and is filled with enemies
## matching those roles. EncounterTemplate data is stored in MapData.metadata["encounters"].

# ─── Archetype table ──────────────────────────────────────────────────────────
## Each entry: [archetype_name, roles_array, weight].
## An archetype is eligible if all its roles exist in the available enemy pool for the floor
## and the cheapest enemy of each role fits within the room budget.

const ARCHETYPES: Array = [
	["patrol",               ["soldier"],                      20],
	["ambush",               ["skirmisher"],                   18],
	["swarm_basic",          ["swarm"],                        15],
	["bastion",              ["tank"],                         10],
	["solo_brute",           ["brute"],                         8],
	["shadow_strike",        ["assassin"],                      7],
	["disruptor",            ["controller"],                    5],
	["glass_battery",        ["glass_cannon"],                  5],
	["flanked_post",         ["tank",        "skirmisher"],    12],
	["balanced_patrol",      ["soldier",     "skirmisher"],     8],
	["guarded_caster",       ["tank",        "controller"],     7],
	["brute_and_skirmishers",["brute",       "skirmisher"],     6],
	["glass_and_tank",       ["glass_cannon","tank"],           5],
	["tactical_squad",       ["soldier",     "controller"],     4],
	["death_from_shadows",   ["assassin",    "controller"],     3],
]


static func place(
	rng: RandomNumberGenerator,
	data: MapData,
	rooms: Array[Rect2i],
	entrance_idx: int,
	boss_idx: int,
	exit_idx: int,
	floor_num: int,
	total_floors: int,
	enemy_balance: Dictionary = {}
) -> void:
	var max_per_room:   int   = int(enemy_balance.get("max_per_room",    3))
	var boss_hp_mult:  float = float(enemy_balance.get("boss_hp_mult",  1.8))
	var boss_atk_mult: float = float(enemy_balance.get("boss_atk_mult", 1.2))
	var boss_def_mult: float = float(enemy_balance.get("boss_def_mult", 1.3))
	var boss_xp_mult:  float = float(enemy_balance.get("boss_xp_mult",  5.0))
	var boss_detection: int  = int(enemy_balance.get("boss_detection",  10))

	# Per-floor budget: prefer pre-computed curve array; fall back to old linear formula
	var floor_budgets_arr: Array = enemy_balance.get("floor_budgets", []) as Array
	var budget: int
	if floor_budgets_arr.size() >= floor_num:
		budget = int(floor_budgets_arr[floor_num - 1])
	else:
		budget = int(enemy_balance.get("pressure_base", 30)) + (floor_num - 1) * int(enemy_balance.get("pressure_per_floor", 12))

	var available: Array = []
	for entry: Variant in EnemyRegistry.get_all():
		var e: Dictionary = entry as Dictionary
		if floor_num >= int(e["min_floor"]):
			available.append(e)

	if available.is_empty():
		return

	# Entrance and exit rooms are safe; boss room is included so minions can spawn there
	var eligible_rooms: Array[int] = []
	for i: int in range(rooms.size()):
		if i == entrance_idx or i == exit_idx:
			continue
		eligible_rooms.append(i)

	if eligible_rooms.is_empty():
		return

	var per_room: int = budget / eligible_rooms.size()
	var room_budgets: Array[int] = []
	for _r: int in eligible_rooms:
		room_budgets.append(per_room)

	var pl_level:      int = GameState.level
	var danger_rating: int = int(enemy_balance.get("danger_rating", 1))
	var world_seed:    int = GameState.world_seed

	var occupied: Dictionary = {}
	for ent: Dictionary in data.entity_defs:
		var raw_p: Dictionary = ent.get("pos", {}) as Dictionary
		occupied[Vector2i(int(raw_p.get("x", -1)), int(raw_p.get("y", -1)))] = true
	for trans: Dictionary in data.transitions:
		var tp: Variant = trans.get("position")
		if tp is Vector2i:
			occupied[tp as Vector2i] = true

	if not data.metadata.has("encounters"):
		data.metadata["encounters"] = {}

	var uid_counter: int = 0
	for ri: int in range(eligible_rooms.size()):
		var room_idx: int     = eligible_rooms[ri]
		var room: Rect2i      = rooms[room_idx]
		var room_budget: int  = room_budgets[ri]
		var remaining: int    = room_budget
		var placed: int       = 0
		var encounter_group: String = "f%d_r%d" % [floor_num, room_idx]

		# ── Role-based encounter composition ─────────────────────────────────
		var selected: Array       = _select_encounter_roles(rng, available, room_budget)
		var archetype_name: String = str(selected[0]) if not selected.is_empty() else "generic"
		var selected_roles: Array  = selected[1] as Array if not selected.is_empty() else []
		var pool: Array = available if selected_roles.is_empty() else _filter_by_roles(available, selected_roles)
		if pool.is_empty():
			pool = available

		var placed_uids: Array = []

		while remaining > 0 and placed < max_per_room:
			var choices: Array = []
			for entry: Variant in pool:
				var e: Dictionary = entry as Dictionary
				var el: int  = _compute_enemy_level(pl_level, floor_num, e)
				var eff: int = roundi(float(int(e["pressure_cost"])) * GameBalance.level_pressure_mult(el, int(e.get("zone_min_level", 1))))
				if eff <= remaining:
					choices.append(e)
			if choices.is_empty():
				break

			var pick: Dictionary = choices[rng.randi_range(0, choices.size() - 1)] as Dictionary
			var pick_el:  int = _compute_enemy_level(pl_level, floor_num, pick)
			var pick_eff: int = roundi(float(int(pick["pressure_cost"])) * GameBalance.level_pressure_mult(pick_el, int(pick.get("zone_min_level", 1))))
			remaining -= pick_eff
			placed += 1

			var pos: Vector2i = _random_room_pos(rng, room)
			var tries: int = 0
			while occupied.has(pos) and tries < 10:
				pos = _random_room_pos(rng, room)
				tries += 1
			occupied[pos] = true

			var uid: String = "enemy_f%d_%d" % [floor_num, uid_counter]
			uid_counter += 1
			placed_uids.append(uid)

			# EnemySpawnTemplate — no baked hp/atk/def; Enemy.setup() computes them at entry time
			var affix_seed: int = _seed_hash(_seed_hash(world_seed, floor_num), uid_counter)
			var affixes: Array  = _roll_affixes(affix_seed, pick, floor_num, danger_rating)
			data.add_entity("enemy", uid, pos, {
				"id":              pick["id"],
				"name":            pick["name"],
				"schema_version":  int(pick.get("schema_version", 1)),
				"dex":             int(pick["dex_base"]),
				"xp_reward":       int(pick["xp_reward"]),
				"detection_range": int(pick["detection"]),
				"encounter_group": encounter_group,
				"floor_num":       floor_num,
				"affixes":         affixes,
			})

		# ── Store EncounterTemplate in metadata ───────────────────────────────
		data.metadata["encounters"][encounter_group] = {
			"floor":           floor_num,
			"room_idx":        room_idx,
			"archetype":       archetype_name,
			"roles":           selected_roles,
			"pressure_budget": room_budget,
			"pressure_used":   room_budget - remaining,
			"enemy_uids":      placed_uids,
		}

	# ── Boss placement (last floor only) ──────────────────────────────────────
	if floor_num == total_floors:
		var boss_base: Dictionary = available[0] as Dictionary
		for entry: Variant in available:
			var e: Dictionary = entry as Dictionary
			if int(e["pressure_cost"]) > int(boss_base["pressure_cost"]):
				boss_base = e

		var boss_room: Rect2i = rooms[boss_idx]
		var entrance_center: Vector2i = rooms[entrance_idx].position + Vector2i(rooms[entrance_idx].size.x / 2, rooms[entrance_idx].size.y / 2)
		var corners: Array[Vector2i] = [
			boss_room.position + Vector2i(1, 1),
			boss_room.position + Vector2i(boss_room.size.x - 2, 1),
			boss_room.position + Vector2i(1, boss_room.size.y - 2),
			boss_room.position + Vector2i(boss_room.size.x - 2, boss_room.size.y - 2),
		]
		var boss_pos: Vector2i = corners[0]
		var best_corner_dist: float = 0.0
		for corner: Vector2i in corners:
			var d: float = float(entrance_center.distance_to(corner))
			if d > best_corner_dist:
				best_corner_dist = d
				boss_pos = corner
		occupied[boss_pos] = true

		var boss_uid: String = "boss_f%d" % floor_num
		# EnemySpawnTemplate for boss — multipliers stored so Enemy.setup() can compute runtime stats
		data.add_entity("enemy", boss_uid, boss_pos, {
			"id":              boss_base["id"],
			"name":            "Gran " + str(boss_base["name"]),
			"schema_version":  int(boss_base.get("schema_version", 1)),
			"dex":             int(boss_base.get("dex_base", 5)),
			"xp_reward":       roundi(float(int(boss_base["xp_reward"])) * boss_xp_mult),
			"detection_range": boss_detection,
			"boss":            true,
			"boss_hp_mult":    boss_hp_mult,
			"boss_atk_mult":   boss_atk_mult,
			"boss_def_mult":   boss_def_mult,
			"encounter_group": "f%d_boss" % floor_num,
			"floor_num":       floor_num,
		})
		data.metadata["encounters"]["f%d_boss" % floor_num] = {
			"floor":           floor_num,
			"room_idx":        boss_idx,
			"roles":           [boss_base.get("role", "boss")],
			"pressure_budget": -1,
			"pressure_used":   int(boss_base["pressure_cost"]),
			"enemy_uids":      [boss_uid],
		}


# ─── Role selection helpers ───────────────────────────────────────────────────

## Returns [archetype_name, roles_array] for this room, or [] if no archetype is eligible.
static func _select_encounter_roles(rng: RandomNumberGenerator, available: Array, room_budget: int) -> Array:
	# Map role → cheapest enemy pressure cost
	var role_min_cost: Dictionary = {}
	for entry: Variant in available:
		var e: Dictionary = entry as Dictionary
		var role: String  = str(e.get("role", "soldier"))
		var cost: int     = int(e["pressure_cost"])
		if not role_min_cost.has(role) or cost < int(role_min_cost[role]):
			role_min_cost[role] = cost

	# Filter archetypes: all roles must be available and affordable within room_budget
	var valid_combos: Array = []
	var total_weight: int = 0
	for combo: Variant in ARCHETYPES:
		var c: Array        = combo as Array
		var roles: Array    = c[1] as Array
		var weight: int     = int(c[2])
		var ok: bool        = true
		var min_needed: int = 0
		for role: Variant in roles:
			var r: String = str(role)
			if not role_min_cost.has(r):
				ok = false
				break
			min_needed += int(role_min_cost[r])
		if ok and min_needed <= room_budget:
			valid_combos.append(c)
			total_weight += weight

	if valid_combos.is_empty():
		return []

	var roll: int = rng.randi_range(0, total_weight - 1)
	var acc: int  = 0
	for combo: Variant in valid_combos:
		var c: Array = combo as Array
		acc += int(c[2])
		if roll < acc:
			return [str(c[0]), (c[1] as Array).duplicate()]
	var last: Array = valid_combos[-1] as Array
	return [str(last[0]), (last[1] as Array).duplicate()]


## Returns a filtered copy of `available` keeping only enemies whose role is in `roles`.
static func _filter_by_roles(available: Array, roles: Array) -> Array:
	var role_set: Dictionary = {}
	for r: Variant in roles:
		role_set[str(r)] = true
	var result: Array = []
	for entry: Variant in available:
		var e: Dictionary = entry as Dictionary
		if role_set.has(str(e.get("role", "soldier"))):
			result.append(e)
	return result


static func _random_room_pos(rng: RandomNumberGenerator, room: Rect2i) -> Vector2i:
	return Vector2i(
		rng.randi_range(room.position.x, room.position.x + room.size.x - 1),
		rng.randi_range(room.position.y, room.position.y + room.size.y - 1)
	)


## Returns the effective level for an enemy given player level and floor depth.
## Mirrors the formula in Enemy._apply_runtime_stats().
static func _compute_enemy_level(pl_level: int, floor_num: int, e: Dictionary) -> int:
	var tier:     int = int(e.get("tier", 3))
	var zone_min: int = int(e.get("zone_min_level", 1))
	var zone_max: int = int(e.get("zone_max_level", 50))
	var fb: int = floori(float(floor_num - 1) / 5.0)
	return clampi(pl_level + fb + (tier - 3), zone_min, zone_max)


## Deterministic hash for deriving per-enemy affix seeds.
static func _seed_hash(a: int, b: int) -> int:
	return (a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF


## Rolls 0-2 affixes for an enemy deterministically via affix_seed.
## Probability of any affix: danger_rating × 10% (capped at 60%).
## Second affix: 30% chance if danger_rating >= 3, must pass compatibility rules.
static func _roll_affixes(affix_seed: int, enemy: Dictionary, floor_num: int, danger_rating: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = affix_seed

	var base_prob: float = clampf(float(danger_rating) * 0.10, 0.0, 0.60)
	if rng.randf() > base_prob:
		return []

	var family:   String = str(enemy.get("family", ""))
	var eligible: Array  = AffixRegistry.get_eligible(floor_num, family)
	if eligible.is_empty():
		return []

	var pick1: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)] as Dictionary
	var result: Array     = [str(pick1["id"])]

	# Second affix: only if danger_rating >= 3 and compatibility allows
	if danger_rating >= 3 and rng.randf() < 0.30:
		var cat1:   String = str(pick1.get("affix_category", ""))
		var rank1:  String = str(pick1.get("affix_rank", "minor"))
		var incompat1: Array = pick1.get("incompatible_categories", []) as Array

		var eligible2: Array = []
		for entry: Variant in eligible:
			var a: Dictionary = entry as Dictionary
			var a_id:    String = str(a["id"])
			var a_cat:   String = str(a.get("affix_category", ""))
			var a_rank:  String = str(a.get("affix_rank", "minor"))
			var a_incompat: Array = a.get("incompatible_categories", []) as Array
			if a_id == str(pick1["id"]):
				continue
			# No two major affixes on a non-boss
			if rank1 == "major" and a_rank == "major":
				continue
			# Incompatibility check (both ways)
			if incompat1.has(a_cat):
				continue
			if a_incompat.has(cat1):
				continue
			eligible2.append(a)

		if not eligible2.is_empty():
			var pick2: Dictionary = eligible2[rng.randi_range(0, eligible2.size() - 1)] as Dictionary
			result.append(str(pick2["id"]))

	return result
