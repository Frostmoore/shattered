extends Node

# Resolves a drop_context into an Array of item drops.
# Returns Array of Dictionaries — each is either an item instance or {type:"gold", amount:N}.
func resolve(ctx: Dictionary) -> Array:
	var floor_num:   int    = int(ctx.get("floor", 0))
	var tier:        int    = clampi(floor_num / 10 + 1, 1, 6)
	var class_id:    String = str(ctx.get("player_class", "noob"))
	var player_lv:   int    = int(ctx.get("player_level", GameState.level))
	var source_type: String = str(ctx.get("source_type", "enemy"))

	var table: Dictionary
	match source_type:
		"enemy":
			var profile: String = str(ctx.get("loot_profile", ""))
			if profile == "":
				return []
			table = LootTableDB.get_enemy(class_id, tier, profile)
		"chest":
			table = LootTableDB.get_chest(class_id, tier)
		"ground":
			table = LootTableDB.get_ground(class_id, tier)
		_:
			return []

	if table.is_empty():
		return []

	# Chest: read variant params; others: table IS params
	var params: Dictionary
	if source_type == "chest":
		var variant: String = str(ctx.get("chest_variant", "comune"))
		params = table.get(variant, {}) as Dictionary
		if params.is_empty():
			return []
	else:
		params = table

	var quality_bias: int = int(params.get("quality_bias", 0))
	var band: Dictionary  = _pick_band(table.get("level_bands", []), player_lv)
	if band.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var drops: Array = []
	var budget: Variant = ctx.get("budget")

	# Guaranteed rolls (e.g. boss chest minimum quality)
	for g: Variant in (params.get("guaranteed", []) as Array):
		var gd: Dictionary = g as Dictionary
		var cat: Variant   = gd.get("item_category", "")
		var cat_str: String
		if cat is Array:
			cat_str = str((cat as Array).pick_random())
		else:
			cat_str = str(cat)
		var min_q: String = str(gd.get("min_quality", ""))
		var base: Dictionary = ItemDB.pick_random(cat_str, player_lv, min_q)
		if not base.is_empty():
			var instance: Dictionary = ItemGenerator.drop(str(base["id"]), player_lv, rng, quality_bias)
			if not instance.is_empty():
				_consume_budget(budget, instance, source_type)
				drops.append(instance)

	# Random rolls
	var rolls_min: int = int(params.get("rolls_min", params.get("rolls", 1)))
	var rolls_max: int = int(params.get("rolls_max", params.get("rolls", 1)))
	var roll_count: int = rng.randi_range(rolls_min, rolls_max)

	var pool: Array = band.get("pool", [])
	for _i: int in roll_count:
		if pool.is_empty():
			break
		var entry: Dictionary = _weighted_pick(pool, rng)
		if entry.is_empty() or bool(entry.get("nothing", false)):
			continue
		if str(entry.get("type", "")) == "gold":
			drops.append({
				"type":   "gold",
				"amount": rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 5))),
			})
		elif entry.has("item_id"):
			var instance: Dictionary = ItemGenerator.drop(str(entry["item_id"]), player_lv, rng, quality_bias)
			if not instance.is_empty() and _budget_allows(budget, instance, source_type):
				_consume_budget(budget, instance, source_type)
				drops.append(instance)
		elif entry.has("item_category"):
			var base: Dictionary = ItemDB.pick_random(str(entry["item_category"]), player_lv)
			if not base.is_empty():
				var instance: Dictionary = ItemGenerator.drop(str(base["id"]), player_lv, rng, quality_bias)
				if not instance.is_empty() and _budget_allows(budget, instance, source_type):
					_consume_budget(budget, instance, source_type)
					drops.append(instance)

	# Filter out empty results
	var result: Array = []
	for d: Variant in drops:
		if not (d as Dictionary).is_empty():
			result.append(d)
	return result


# ── helpers ───────────────────────────────────────────────────────────────────

func _pick_band(bands: Array, level: int) -> Dictionary:
	var last: Dictionary = {}
	for band: Variant in bands:
		var d: Dictionary = band as Dictionary
		if level >= int(d.get("level_min", 0)) and level <= int(d.get("level_max", 9999)):
			return d
		last = d
	return last


func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for e: Variant in pool:
		total += int((e as Dictionary).get("weight", 1))
	if total == 0:
		return {}
	var roll: int = rng.randi() % total
	var acc: int  = 0
	for e: Variant in pool:
		var d: Dictionary = e as Dictionary
		acc += int(d.get("weight", 1))
		if roll < acc:
			return d
	return pool[-1] as Dictionary


# Returns false if the budget blocks this drop; true if budget is null or allows it.
func _budget_allows(budget: Variant, instance: Dictionary, source: String) -> bool:
	if budget == null:
		return true
	var quality: String = str(instance.get("quality", "normale"))
	if quality == "unico" and not budget.unique_ok():
		return false
	var base: Dictionary = ItemDB.get_item(str(instance.get("base_id", "")))
	var cat: String = str(base.get("item_category", "consumable"))
	if cat == "consumable":
		return budget.consumable_ok()
	if cat in ["weapon", "armor", "accessory"]:
		match source:
			"chest": return budget.chest_equipment_ok()
			"enemy": return budget.enemy_equipment_ok()
	return true


func _consume_budget(budget: Variant, instance: Dictionary, source: String) -> void:
	if budget == null:
		return
	var quality: String = str(instance.get("quality", "normale"))
	if quality == "unico":
		budget.consume_unique()
	var base: Dictionary = ItemDB.get_item(str(instance.get("base_id", "")))
	var cat: String = str(base.get("item_category", "consumable"))
	if cat == "consumable":
		budget.consume_consumable()
	elif cat in ["weapon", "armor", "accessory"]:
		budget.consume_equipment(source)
