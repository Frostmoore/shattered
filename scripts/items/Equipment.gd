extends Node

const VALID_SLOTS: Array[String] = [
	"head", "body", "left_hand", "right_hand",
	"ring_1", "ring_2", "neck", "feet", "cloak", "trinket", "hands"
]


# Equips a base item_id or an instance_id. Returns false if class-restricted.
func equip(item_id: String) -> bool:
	var data: Dictionary = get_base_data(item_id)
	if data.is_empty():
		return false
	var item_cat: String = str(data.get("type", data.get("item_category", "")))
	if item_cat not in ["equipment", "weapon", "armor", "accessory"]:
		return false
	if not _check_class_restriction(data):
		return false
	var slot: String = _pick_slot(data)
	if slot == "":
		return false
	# Equipping a two-handed weapon also frees the left hand
	if _is_two_handed(data):
		GameState.equipped["left_hand"] = ""
	# Prevent equipping left_hand while a two-handed weapon occupies right_hand
	if slot == "left_hand":
		var rh_id: String = str(GameState.equipped.get("right_hand", ""))
		if rh_id != "":
			var rh_base: Dictionary = get_base_data(rh_id)
			if _is_two_handed(rh_base):
				return false
	GameState.equipped[slot] = item_id
	EventBus.equipment_changed.emit()
	return true


# Convenience: equip a full item instance dict.
func equip_instance(instance: Dictionary) -> bool:
	var iid: String = str(instance.get("instance_id", ""))
	if iid == "":
		return false
	return equip(iid)


func unequip(slot: String) -> void:
	if not GameState.equipped.has(slot):
		return
	GameState.equipped[slot] = ""
	EventBus.equipment_changed.emit()


func get_equipped_slot(item_id: String) -> String:
	for slot: String in GameState.equipped:
		if str(GameState.equipped[slot]) == item_id:
			return slot
	return ""


func is_equipped(item_id: String) -> bool:
	return get_equipped_slot(item_id) != ""


func get_attack_bonus() -> int:
	var bonus: int = 0
	for slot: String in GameState.equipped:
		var item_id: String = str(GameState.equipped[slot])
		if item_id == "":
			continue
		bonus += int(get_stats(item_id).get("attack_bonus", 0))
	return bonus


func get_defense_bonus() -> int:
	var bonus: int = 0
	for slot: String in GameState.equipped:
		var item_id: String = str(GameState.equipped[slot])
		if item_id == "":
			continue
		bonus += int(get_stats(item_id).get("defense_bonus", 0))
	return bonus


func get_attack_bonus_breakdown() -> Array:
	var result: Array = []
	for slot: String in GameState.equipped:
		var item_id: String = str(GameState.equipped[slot])
		if item_id == "":
			continue
		var bonus: int = int(get_stats(item_id).get("attack_bonus", 0))
		if bonus != 0:
			result.append({"name": get_display_name(item_id), "bonus": bonus})
	return result


func get_defense_bonus_breakdown() -> Array:
	var result: Array = []
	for slot: String in GameState.equipped:
		var item_id: String = str(GameState.equipped[slot])
		if item_id == "":
			continue
		var bonus: int = int(get_stats(item_id).get("defense_bonus", 0))
		if bonus != 0:
			result.append({"name": get_display_name(item_id), "bonus": bonus})
	return result


# ── public helpers ─────────────────────────────────────────────────────────────

# Returns the base item data dict for item_id, whether it's an old-format base
# item id or a new-format instance_id.
func get_base_data(item_id: String) -> Dictionary:
	var data: Dictionary = ItemDB.get_item(item_id)
	if not data.is_empty():
		return data
	var instance: Dictionary = find_instance(item_id)
	if instance.is_empty():
		return {}
	return ItemDB.get_item(str(instance.get("base_id", "")))


# Returns the effective stats dict for item_id.
# Old format: the data dict itself (stats are top-level fields).
# New format identified: baked_stats (or resolve_stats for legendary/unique).
# New format unidentified: base_stats from base JSON.
func get_stats(item_id: String) -> Dictionary:
	var data: Dictionary = ItemDB.get_item(item_id)
	if not data.is_empty():
		return data
	var instance: Dictionary = find_instance(item_id)
	if instance.is_empty():
		return {}
	if bool(instance.get("identified", false)):
		var quality: String = str(instance.get("quality", "normale"))
		if quality in ["leggendario", "unico"]:
			return ItemGenerator.resolve_stats(instance, GameState.level)
		var baked: Variant = instance.get("baked_stats")
		if baked is Dictionary:
			return baked as Dictionary
	var base: Dictionary = ItemDB.get_item(str(instance.get("base_id", "")))
	return (base.get("base_stats", {}) as Dictionary)


# Returns the display name: instance name (if identified) > name_unid > base name.
func get_display_name(item_id: String) -> String:
	var data: Dictionary = ItemDB.get_item(item_id)
	if not data.is_empty():
		return str(data.get("name", item_id))
	var instance: Dictionary = find_instance(item_id)
	if instance.is_empty():
		return item_id
	if bool(instance.get("identified", false)):
		return str(instance.get("name", item_id))
	return str(instance.get("name_unid", item_id))


# Finds an instance in GameState.inventory by instance_id.
func find_instance(item_id: String) -> Dictionary:
	for entry: Dictionary in GameState.inventory:
		if str(entry.get("instance_id", "")) == item_id:
			return entry
	return {}


# ── private helpers ────────────────────────────────────────────────────────────

# Returns true if item_type is in the current class's allowed_item_types.
# Always returns true for "noob" (special_id: noob_adaptability) or if class has no restrictions.
func _check_class_restriction(base: Dictionary) -> bool:
	var class_id: String = GameState.current_class
	if class_id == "noob":
		return true
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if reg == null:
		return true
	var class_data: Variant = reg.call("get_class_data", class_id)
	if not class_data is Dictionary:
		return true
	var allowed: Array = (class_data as Dictionary).get("allowed_item_types", []) as Array
	if allowed.is_empty():
		return true
	var itype: String = str(base.get("item_type", ""))
	return itype == "" or allowed.has(itype)


func _is_two_handed(base: Dictionary) -> bool:
	return str(base.get("slot", "")) == "both_hands"


# Resolves which slot to use for equipping.
# For single-slot items: uses "slot" field.
# two-handed items ("slot": "both_hands") map to right_hand.
# For multi-slot items (rings, dual-wield daggers): uses "allowed_slots",
# preferring the first empty slot, then the first valid one.
func _pick_slot(data: Dictionary) -> String:
	var slot: String = str(data.get("slot", ""))
	if slot == "both_hands":
		return "right_hand"
	if slot != "" and VALID_SLOTS.has(slot):
		return slot
	var allowed: Array = data.get("allowed_slots", []) as Array
	var fallback: String = ""
	for s: Variant in allowed:
		var sv: String = str(s)
		if not VALID_SLOTS.has(sv):
			continue
		if str(GameState.equipped.get(sv, "")) == "":
			return sv
		if fallback == "":
			fallback = sv
	return fallback
