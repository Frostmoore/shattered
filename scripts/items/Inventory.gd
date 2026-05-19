extends Node


func add_item(item_id: String, quantity: int = 1, notify: bool = true) -> void:
	for entry: Dictionary in GameState.inventory:
		if entry["id"] == item_id:
			entry["qty"] += quantity
			EventBus.inventory_changed.emit()
			if notify:
				_emit_item_notification(item_id, quantity)
			return
	GameState.inventory.append({"id": item_id, "qty": quantity})
	EventBus.inventory_changed.emit()
	if notify:
		_emit_item_notification(item_id, quantity)


func _emit_item_notification(item_id: String, quantity: int) -> void:
	var data: Dictionary = ItemDB.get_item(item_id)
	EventBus.notification_shown.emit(Notification.item(data.get("name", item_id), quantity))


func remove_item(item_id: String, quantity: int = 1) -> bool:
	for entry: Dictionary in GameState.inventory:
		if entry["id"] == item_id:
			if entry["qty"] < quantity:
				return false
			entry["qty"] -= quantity
			if entry["qty"] <= 0:
				GameState.inventory.erase(entry)
			EventBus.inventory_changed.emit()
			return true
	return false


func has_item(item_id: String, quantity: int = 1) -> bool:
	for entry: Dictionary in GameState.inventory:
		if entry["id"] == item_id:
			return entry["qty"] >= quantity
	return false


func get_quantity(item_id: String) -> int:
	for entry: Dictionary in GameState.inventory:
		if entry["id"] == item_id:
			return int(entry["qty"])
	return 0


func use_item(item_id: String) -> void:
	var item_data: Dictionary = ItemDB.get_item(item_id)
	if item_data.is_empty():
		return
	if item_data.get("type") == "consumable":
		var effect: Dictionary = item_data.get("effect", {})
		if effect.has("heal"):
			GameState.heal_player(effect["heal"])
			remove_item(item_id)
			print("Used %s, healed %d hp" % [item_data.get("name", item_id), effect["heal"]])
