class_name ClassValidator
extends RefCounted

const VALID_ATTRS := ["str", "dex", "int", "vit", "wil"]
const VALID_SPECIAL_TYPES := [
	"passive", "active_key", "active_target",
	"passive_and_active", "active_toggle",
]
const VALID_UNLOCK_TYPES := [
	"always", "level", "kills_total", "kills_boss", "dungeons_completed",
	"dungeons_completed_no_death", "deaths_total", "damage_dealt_total",
	"damage_taken_total", "scrolls_collected", "chests_opened", "quests_completed",
	"npcs_spoken", "consumables_used", "consumable_types_used", "items_collected_unique",
	"items_identified", "overworld_tiles", "overworld_zones_explored",
	"overworld_zones_visited", "dungeon_floors_total", "dungeon_floor_no_damage",
	"dungeon_rooms_explored", "dungeon_clear_no_death", "tiles_explored_total",
	"combat_wins_no_items", "equip_full_set", "stat_threshold", "dual_stat_threshold",
	"near_death_survived", "survived_at_1hp", "attacks_dodged_total",
	"damage_absorbed_total", "gold_accumulated", "boss_killed_no_damage",
	"boss_killed_no_items", "class_respec_count", "kills_enemy_type_all",
	"save_points_used", "enemies_seen_die", "all_classes_completed",
]


static func validate(classes: Dictionary) -> void:
	var errors: Array[String] = []
	var seen_ids: Dictionary  = {}

	for id: String in classes:
		var d: Dictionary  = classes[id]
		var prefix: String = "Classe '%s': " % id

		if seen_ids.has(id):
			errors.append(prefix + "id duplicato")
		seen_ids[id] = true

		_check_dict_keys(d, "growth",       errors, prefix)
		_check_dict_keys(d, "respec_bonus", errors, prefix)

		var stype: String = str(d.get("special_type", ""))
		if stype not in VALID_SPECIAL_TYPES:
			errors.append(prefix + "special_type non valido: '%s'" % stype)

		var unlock: Variant = d.get("unlock", {})
		if unlock is Dictionary:
			var utype: String = str((unlock as Dictionary).get("type", ""))
			if utype not in VALID_UNLOCK_TYPES:
				errors.append(prefix + "unlock.type non valido: '%s'" % utype)

	if errors.is_empty():
		print("ClassValidator: OK (%d classi)" % classes.size())
	else:
		for err: String in errors:
			push_error("ClassValidator: " + err)


static func _check_dict_keys(data: Dictionary, field: String,
		errors: Array[String], prefix: String) -> void:
	var val: Variant = data.get(field, null)
	if not val is Dictionary:
		errors.append(prefix + "'%s' mancante o non Dictionary" % field)
		return
	for attr: String in VALID_ATTRS:
		if not (val as Dictionary).has(attr):
			errors.append(prefix + "'%s' manca chiave '%s'" % [field, attr])
