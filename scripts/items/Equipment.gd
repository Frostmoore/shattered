extends Node

const VALID_SLOTS: Array[String] = [
	"helm", "armor", "left_hand", "right_hand",
	"ring_1", "ring_2", "amulet", "boots", "cloak", "accessory"
]


func equip(item_id: String) -> void:
	var data: Dictionary = ItemDB.get_item(item_id)
	if data.get("type", "") != "equipment":
		return
	var slot: String = data.get("slot", "")
	if not VALID_SLOTS.has(slot):
		return
	GameState.equipped[slot] = item_id
	EventBus.equipment_changed.emit()


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
		var data: Dictionary = ItemDB.get_item(item_id)
		bonus += int(data.get("attack_bonus", 0))
	return bonus


func get_defense_bonus() -> int:
	var bonus: int = 0
	for slot: String in GameState.equipped:
		var item_id: String = str(GameState.equipped[slot])
		if item_id == "":
			continue
		var data: Dictionary = ItemDB.get_item(item_id)
		bonus += int(data.get("defense_bonus", 0))
	return bonus


func get_attack_bonus_breakdown() -> Array:
	var result: Array = []
	for slot: String in GameState.equipped:
		var item_id: String = str(GameState.equipped[slot])
		if item_id == "":
			continue
		var data: Dictionary = ItemDB.get_item(item_id)
		var bonus: int = int(data.get("attack_bonus", 0))
		if bonus != 0:
			result.append({"name": data.get("name", item_id), "bonus": bonus})
	return result


func get_defense_bonus_breakdown() -> Array:
	var result: Array = []
	for slot: String in GameState.equipped:
		var item_id: String = str(GameState.equipped[slot])
		if item_id == "":
			continue
		var data: Dictionary = ItemDB.get_item(item_id)
		var bonus: int = int(data.get("defense_bonus", 0))
		if bonus != 0:
			result.append({"name": data.get("name", item_id), "bonus": bonus})
	return result
