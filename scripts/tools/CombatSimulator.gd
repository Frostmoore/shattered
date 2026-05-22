class_name CombatSimulator

## Developer tool: simulates TTK for all registered enemies against class archetypes.
## Call CombatSimulator.run_validation() to print a full TTK table to the Godot Output panel.
## Usage: add a temporary call in _ready() or hook it to a debug button.

const _Profile = preload("res://scripts/tools/ClassCombatProfile.gd")

const PRIMARY_PROFILES:   Array = ["melee_bruiser", "caster_burst"]
const SECONDARY_PROFILES: Array = ["melee_tank", "evasion_based"]


## Returns combat metrics for one player profile vs one enemy entry at a given level.
## enemy_data: dict from EnemyRegistry (must have hp_base, atk_base, def_base, dex_base).
static func simulate_combat(profile_id: String, enemy_data: Dictionary, level: int) -> Dictionary:
	var p: Dictionary = _Profile.stats_at(profile_id, level)
	if p.is_empty():
		return {}

	var lf:      float = BalanceCombat.level_factor(level)
	var lf_base: float = BalanceCombat.level_factor(1)

	var e_hp:  int = roundi(float(int(enemy_data["hp_base"])) * lf / lf_base)
	var e_atk: int = int(enemy_data["atk_base"])
	var e_def: int = int(enemy_data["def_base"])
	var e_dex: int = int(enemy_data["dex_base"])

	var p_atk: int = int(p["attack"])
	var p_def: int = int(p["defense"])
	var p_dex: int = int(p["dex"])
	var p_hp:  int = int(p["hp"])

	# Player damage per hit
	var p_dmg: int = maxi(BalanceCombat.DAMAGE_MIN,
		floori(lf * float(p_atk) / maxf(1.0, float(e_def)) / BalanceCombat.DAMAGE_K))

	# Player hit stat and hit chance
	var ct: String = str(p.get("combat_type", "melee"))
	var p_hit_stat: int = p_dex if ct == "ranged" else floori((p_atk + p_dex) / 2.0)
	var p_hit_chance: float = clampf(
		BalanceCombat.BASE_HIT_CHANCE + float(p_hit_stat - e_dex) * BalanceCombat.ACCURACY_K,
		BalanceCombat.MIN_HIT_CHANCE, BalanceCombat.MAX_HIT_CHANCE)

	# TTK (expected, fractional hit model)
	var effective_p_dmg: float = p_hit_chance * float(p_dmg)
	var ttk: int = ceili(float(e_hp) / effective_p_dmg)

	# Enemy damage per hit — enemy.level defaults to GameState.level, so uses same lf
	var e_dmg: int = maxi(BalanceCombat.DAMAGE_MIN,
		floori(lf * float(e_atk) / maxf(1.0, float(p_def)) / BalanceCombat.DAMAGE_K))

	# Enemy hit chance (enemies are treated as melee unless tagged ranged — conservative)
	var e_hit_stat: int = floori((e_atk + e_dex) / 2.0)
	var e_hit_chance: float = clampf(
		BalanceCombat.BASE_HIT_CHANCE + float(e_hit_stat - p_dex) * BalanceCombat.ACCURACY_K,
		BalanceCombat.MIN_HIT_CHANCE, BalanceCombat.MAX_HIT_CHANCE)

	# Player goes first: enemy gets (ttk-1) attacks before dying
	var dmg_taken: float = float(maxi(0, ttk - 1)) * e_hit_chance * float(e_dmg)

	return {
		"ttk":           ttk,
		"hit_chance":    p_hit_chance,
		"dmg_per_hit":   p_dmg,
		"e_hp_scaled":   e_hp,
		"dmg_taken":     dmg_taken,
		"dmg_taken_pct": dmg_taken / float(maxi(1, p_hp)) * 100.0,
	}


## Returns "ok", "warn(easy)", "warn(hard)", "FAIL(easy)", or "FAIL(hard)".
static func verdict(ttk: int, role: String) -> String:
	var target: Array = _Profile.TTK_TARGETS.get(role, [3, 8]) as Array
	var lo: int = int(target[0])
	var hi: int = int(target[1])
	if ttk < lo:
		return "FAIL(easy)" if ttk <= lo - 2 else "warn(easy)"
	if ttk > hi:
		return "FAIL(hard)" if ttk >= hi + 3 else "warn(hard)"
	return "ok"


## Prints a full TTK validation table to the Godot Output panel.
static func run_validation() -> void:
	var enemies: Array = EnemyRegistry.get_all()
	if enemies.is_empty():
		print("[CombatSimulator] EnemyRegistry is empty — run from the game, not the editor.")
		return

	var profiles: Array = PRIMARY_PROFILES + SECONDARY_PROFILES
	var sep: String = "=".repeat(90)
	var dash: String = "-".repeat(90)

	print("")
	print(sep)
	print("[CombatSimulator] TTK Validation  (tested at zone_min_level, player goes first)")
	print("  profiles: " + ", ".join(profiles))
	print(sep)

	var header: String = "%-24s %4s" % ["ENEMY (role)", "LVL"]
	for pid: Variant in profiles:
		var short: String = str(pid).substr(0, 13)
		header += "  %13s" % short
	header += "  %s" % "verdict"
	print(header)
	print(dash)

	var fail_count: int = 0
	var warn_count: int = 0

	for entry: Variant in enemies:
		var e: Dictionary    = entry as Dictionary
		var role:  String    = str(e.get("role", "soldier"))
		var level: int       = int(e.get("zone_min_level", 1))
		var label: String    = "%s (%s)" % [str(e["name"]), role]
		if label.length() > 24:
			label = label.substr(0, 21) + "..."

		var row: String      = "%-24s %4d" % [label, level]
		var worst_v: String  = "ok"

		for prof: Variant in profiles:
			var result: Dictionary = simulate_combat(str(prof), e, level)
			if result.is_empty():
				row += "  %13s" % "—"
				continue
			var ttk: int    = int(result["ttk"])
			var v:   String = verdict(ttk, role)
			var cell: String = "%d %s" % [ttk, v]
			row += "  %13s" % cell
			# Verdict only from primary profiles — secondary are informational
			if PRIMARY_PROFILES.has(str(prof)):
				if v.begins_with("FAIL"):
					worst_v = v
				elif v.begins_with("warn") and not worst_v.begins_with("FAIL"):
					worst_v = v

		if worst_v.begins_with("FAIL"):
			fail_count += 1
			print("[FAIL] " + row)
		elif worst_v.begins_with("warn"):
			warn_count += 1
			print("[warn] " + row)
		else:
			print("[ ok ] " + row)

	print(dash)
	print("[CombatSimulator] Done.  FAILs: %d   warns: %d   / %d enemies" % [
		fail_count, warn_count, enemies.size()])
	print(sep)
	print("")
