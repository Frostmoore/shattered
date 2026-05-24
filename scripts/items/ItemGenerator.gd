extends Node

const QUALITY_TIERS: Array[String] = ["normale", "magico", "raro", "epico", "leggendario"]

const ID_THRESHOLD: Dictionary = {
	"normale":    0,
	"magico":     10,
	"raro":       24,
	"epico":      40,
	"leggendario":60,
	"unico":      70,
}

const QUALITY_COLORS: Dictionary = {
	"normale":    Color(1.0, 1.0, 1.0),
	"magico":     Color(0.3, 0.55, 1.0),
	"raro":       Color(1.0, 0.9, 0.15),
	"epico":      Color(0.75, 0.3, 1.0),
	"leggendario":Color(1.0, 0.55, 0.1),
	"unico":      Color(1.0, 0.85, 0.1),
}


# ── drop ─────────────────────────────────────────────────────────────────────

# Generates an item skeleton from a base template. No affixes yet.
func drop(base_id: String, player_level: int, rng: RandomNumberGenerator = null, quality_bias: int = 0) -> Dictionary:
	var base: Dictionary = ItemDB.get_item(base_id)
	if base.is_empty():
		push_error("ItemGenerator.drop: unknown base_id '%s'" % base_id)
		return {}

	var cat: String = str(base.get("item_category", base.get("type", "")))
	var quality: String
	var identified: bool

	# Consumables are always normale + auto-identified
	if cat == "consumable" or cat == "key_item":
		quality    = "normale"
		identified = true
	else:
		var quality_override: String = str(base.get("quality_override", ""))
		if quality_override != "":
			quality = quality_override
		else:
			quality = _roll_quality(player_level, quality_bias, rng)
		identified = quality == "normale"

	var affix_seed: int = (rng.randi() if rng else randi())
	var instance: Dictionary = {
		"instance_id": _gen_uid(),
		"base_id":     base_id,
		"quality":     quality,
		"affix_seed":  affix_seed,
		"identified":  identified,
		"name_unid":   _make_unid_name(base, quality),
	}

	# Auto-identify if quality == normale (no affixes anyway)
	if identified:
		return _bake_normal(instance, base)

	return instance


# ── identify ─────────────────────────────────────────────────────────────────

# Rolls affixes deterministically from affix_seed and bakes stats.
# For Legendary/Unique: sets identified=true but does NOT bake stats (use resolve_stats).
func identify(instance: Dictionary, player_level: int) -> Dictionary:
	if bool(instance.get("identified", false)):
		return instance.duplicate(true)

	var base_id: String = str(instance.get("base_id", ""))
	var base: Dictionary = ItemDB.get_item(base_id)
	if base.is_empty():
		return instance.duplicate(true)

	var quality: String = str(instance.get("quality", "normale"))
	var result: Dictionary = instance.duplicate(true)

	if quality == "leggendario":
		result["identified"] = true
		result["name"] = base.get("name", base_id)
		return result

	if quality == "unico":
		result["identified"] = true
		result["name"] = base.get("name", base_id)
		result["affixes"] = base.get("fixed_affixes", [])
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = int(instance.get("affix_seed", 0))

	var item_type: String = str(base.get("item_type", ""))
	var max_prefix: int
	var max_suffix: int
	match quality:
		"magico": max_prefix = 1; max_suffix = 1
		"raro":   max_prefix = 2; max_suffix = 2
		"epico":  max_prefix = 3; max_suffix = 2
		_:        max_prefix = 0; max_suffix = 0

	var all_eligible: Array = ItemAffixDB.get_eligible(item_type, player_level, quality)
	var prefixes: Array = []
	var suffixes: Array = []

	var eligible_p: Array = all_eligible.filter(func(a: Dictionary) -> bool:
		return str(a.get("type", "")) == "prefix")
	for _i: int in max_prefix:
		if eligible_p.is_empty():
			break
		var pick: Dictionary = _weighted_affix_pick(eligible_p, rng)
		if not pick.is_empty():
			prefixes.append(str(pick["id"]))
			eligible_p.erase(pick)

	var eligible_s: Array = all_eligible.filter(func(a: Dictionary) -> bool:
		return str(a.get("type", "")) == "suffix")
	for _i: int in max_suffix:
		if eligible_s.is_empty():
			break
		var pick: Dictionary = _weighted_affix_pick(eligible_s, rng)
		if not pick.is_empty():
			suffixes.append(str(pick["id"]))
			eligible_s.erase(pick)

	# Name = [NomeBase] [tutti gli affissi come suffissi] — in italiano l'aggettivo va dopo
	var gender: String = str(base.get("gender", "m"))
	var base_name: String = ItemDB.get_display_name(base_id)
	var name_parts: Array[String] = [base_name]
	for pid: String in prefixes:
		name_parts.append(ItemAffixDB.get_display_name(pid, gender))
	for sid: String in suffixes:
		name_parts.append(ItemAffixDB.get_display_name(sid, gender))

	# Bake stats
	var baked: Dictionary = {}
	for key: String in (base.get("base_stats", {}) as Dictionary):
		baked[key] = int((base["base_stats"] as Dictionary)[key])
	for pid: String in prefixes:
		for key: Variant in (ItemAffixDB.get_affix(pid).get("bonuses", {}) as Dictionary):
			baked[str(key)] = int(baked.get(str(key), 0)) + int((ItemAffixDB.get_affix(pid)["bonuses"] as Dictionary)[key])
	for sid: String in suffixes:
		for key: Variant in (ItemAffixDB.get_affix(sid).get("bonuses", {}) as Dictionary):
			baked[str(key)] = int(baked.get(str(key), 0)) + int((ItemAffixDB.get_affix(sid)["bonuses"] as Dictionary)[key])

	result["affixes"]     = prefixes + suffixes
	result["name"]        = " ".join(name_parts)
	result["baked_stats"] = baked
	result["identified"]  = true
	return result


# ── resolve_stats ─────────────────────────────────────────────────────────────

# Returns the effective stat bonuses for an item at the given player level.
func resolve_stats(instance: Dictionary, player_level: int) -> Dictionary:
	var quality: String = str(instance.get("quality", "normale"))
	if quality not in ["leggendario", "unico"]:
		var baked: Variant = instance.get("baked_stats")
		if baked is Dictionary:
			return baked as Dictionary
		var base_id2: String = str(instance.get("base_id", ""))
		return (ItemDB.get_item(base_id2).get("base_stats", {}) as Dictionary).duplicate()

	var base_id: String = str(instance.get("base_id", ""))
	var base: Dictionary = ItemDB.get_item(base_id)
	if base.is_empty():
		return {}

	var stats: Dictionary = (base.get("base_stats", {}) as Dictionary).duplicate()
	var mode: String = str(base.get("scaling_mode", "threshold"))
	var scale_expr: Dictionary = base.get("scale", {}) as Dictionary

	match mode:
		"full":
			for key: Variant in scale_expr:
				stats[str(key)] = _eval_scale(str(scale_expr[key]), player_level)
		"partial":
			var factor: float = float(base.get("scale_factor", 0.5))
			for key: Variant in scale_expr:
				var full_val: int = _eval_scale(str(scale_expr[key]), player_level)
				var base_val: int = _eval_scale(str(scale_expr[key]), 1)
				stats[str(key)] = roundi(float(base_val) + float(full_val - base_val) * factor)
		"threshold":
			var scale_levels: Array = base.get("scale_levels", [1])
			var effective_lv: int = 1
			for lvl: Variant in scale_levels:
				if player_level >= int(lvl):
					effective_lv = int(lvl)
			for key: Variant in scale_expr:
				stats[str(key)] = _eval_scale(str(scale_expr[key]), effective_lv)

	# Apply fixed affixes for uniques
	if quality == "unico":
		var affix_ids: Array = instance.get("affixes", base.get("fixed_affixes", []))
		for aid: Variant in affix_ids:
			var affix: Dictionary = ItemAffixDB.get_affix(str(aid))
			for key: Variant in (affix.get("bonuses", {}) as Dictionary):
				stats[str(key)] = int(stats.get(str(key), 0)) + int((affix["bonuses"] as Dictionary)[key])

	return stats


# ── helpers ───────────────────────────────────────────────────────────────────

func get_quality_color(quality: String) -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE) as Color


func get_id_threshold(quality: String) -> int:
	return int(ID_THRESHOLD.get(quality, 0))


func _bake_normal(instance: Dictionary, base: Dictionary) -> Dictionary:
	var result: Dictionary = instance.duplicate(true)
	result["name"] = str(base.get("name", str(instance.get("base_id", ""))))
	result["baked_stats"] = (base.get("base_stats", {}) as Dictionary).duplicate()
	result["affixes"] = []
	return result


func _roll_quality(player_level: int, bias: int, rng: RandomNumberGenerator) -> String:
	var t: float = float(player_level - 1) / 99.0
	var w: Array[float] = [
		lerpf(70.0,  5.0, t),   # normale
		lerpf(22.0, 20.0, t),   # magico
		lerpf( 6.0, 35.0, t),   # raro
		lerpf( 1.5, 25.0, t),   # epico
		lerpf( 0.5, 15.0, t),   # leggendario
	]
	var total: float = 0.0
	for v: float in w:
		total += v
	var roll: float = (float(rng.randi() % 10000) / 10000.0) * total if rng else randf() * total
	var acc: float = 0.0
	var idx: int = 0
	for i: int in w.size():
		acc += w[i]
		if roll < acc:
			idx = i
			break
		idx = i
	# Apply bias: shift index upward, clamped to leggendario
	idx = mini(idx + bias, QUALITY_TIERS.size() - 1)
	return QUALITY_TIERS[idx]


func _make_unid_name(base: Dictionary, quality: String) -> String:
	if quality == "normale":
		return str(base.get("name", "???"))
	var itype: String = str(base.get("item_type", "oggetto")).replace("_", " ")
	var q_label: Dictionary = {
		"magico":     "magico",
		"raro":       "raro",
		"epico":      "epico",
		"leggendario":"leggendario",
	}
	return "[?] %s %s" % [itype, q_label.get(quality, quality)]


func _weighted_affix_pick(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for a: Variant in pool:
		total += int((a as Dictionary).get("weight", 1))
	if total == 0:
		return {}
	var roll: int = rng.randi() % total
	var acc: int = 0
	for a: Variant in pool:
		var d: Dictionary = a as Dictionary
		acc += int(d.get("weight", 1))
		if roll < acc:
			return d
	return pool[-1] as Dictionary


func _eval_scale(expr_str: String, level: int) -> int:
	var expr := Expression.new()
	var err: int = expr.parse(expr_str, ["level"])
	if err != OK:
		push_error("ItemGenerator: invalid scale formula '%s'" % expr_str)
		return 0
	var result: Variant = expr.execute([level])
	if expr.has_execute_failed():
		push_error("ItemGenerator: formula execution failed '%s'" % expr_str)
		return 0
	return roundi(float(result))


func _gen_uid() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]
