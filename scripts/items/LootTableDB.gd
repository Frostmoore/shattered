extends Node

# Lazy-loaded cache: absolute path -> parsed table Dictionary
var _cache: Dictionary = {}


# ── API pubblica ──────────────────────────────────────────────────────────────

func get_enemy(class_id: String, tier: int, loot_profile: String) -> Dictionary:
	return _resolve(class_id, tier, "enemies/" + loot_profile + ".json")


func get_chest(class_id: String, tier: int) -> Dictionary:
	return _resolve(class_id, tier, "chest.json")


func get_ground(class_id: String, tier: int) -> Dictionary:
	return _resolve(class_id, tier, "ground.json")


func invalidate_cache() -> void:
	_cache.clear()


# ── Internals ─────────────────────────────────────────────────────────────────

func _resolve(class_id: String, tier: int, rel_path: String) -> Dictionary:
	var t: int = clampi(tier, 1, 6)
	var tier_dir: String = "tier" + str(t)
	var archetype: String = _get_archetype(class_id)

	var candidates: Array = [
		"res://data/loot/" + class_id + "/" + tier_dir + "/" + rel_path,
	]
	if archetype != "":
		candidates.append("res://data/loot/archetypes/" + archetype + "/" + tier_dir + "/" + rel_path)
	candidates.append("res://data/loot/default/" + tier_dir + "/" + rel_path)

	for path: Variant in candidates:
		var p: String = str(path)
		if _cache.has(p):
			return _cache[p]
		if FileAccess.file_exists(p):
			var table: Dictionary = _load_file(p)
			_cache[p] = table
			return table

	push_warning("LootTableDB: no table found for %s/%s/%s" % [class_id, tier_dir, rel_path])
	return {}


func _load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("LootTableDB: cannot open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("LootTableDB: expected dict in " + path)
	return {}


func _get_archetype(class_id: String) -> String:
	var cls: Dictionary = ClassRegistry.get_class_data(class_id)
	var archetype: String = str(cls.get("loot_archetype", ""))
	return archetype if archetype != "" else "martial"
