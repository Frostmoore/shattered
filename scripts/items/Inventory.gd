extends Node


func add_item(item_id: String, quantity: int = 1, notify: bool = true) -> void:
	for entry: Dictionary in GameState.inventory:
		if entry.get("id", "") == item_id:
			entry["qty"] = int(entry.get("qty", 0)) + quantity
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
	for i: int in GameState.inventory.size():
		var entry: Dictionary = GameState.inventory[i]
		if entry.get("id", "") != item_id:
			continue
		if int(entry.get("qty", 0)) < quantity:
			return false
		entry["qty"] = int(entry.get("qty", 0)) - quantity
		if int(entry["qty"]) <= 0:
			GameState.inventory.remove_at(i)
		EventBus.inventory_changed.emit()
		return true
	return false


func has_item(item_id: String, quantity: int = 1) -> bool:
	for entry: Dictionary in GameState.inventory:
		if entry.get("id", "") == item_id:
			return int(entry.get("qty", 0)) >= quantity
	return false


func get_quantity(item_id: String) -> int:
	for entry: Dictionary in GameState.inventory:
		if entry.get("id", "") == item_id:
			return int(entry.get("qty", 0))
	return 0


# Adds a full item instance (equipment with quality/affixes/etc).
# Stackable consumables are merged by base_id; unique equipment entries are kept separate.
func add_item_instance(instance: Dictionary, notify: bool = true) -> void:
	if instance.is_empty():
		return
	var base_id: String = str(instance.get("base_id", ""))
	var base: Dictionary = ItemDB.get_item(base_id)
	var stackable: bool = bool(base.get("stackable", false))

	if stackable:
		# Merge into existing stack by base_id
		for entry: Dictionary in GameState.inventory:
			if entry.get("id") == base_id:
				entry["qty"] = int(entry.get("qty", 1)) + 1
				EventBus.inventory_changed.emit()
				if notify:
					EventBus.notification_shown.emit(Notification.item(
						str(instance.get("name", base.get("name", base_id))), 1))
				return
		GameState.inventory.append({"id": base_id, "qty": 1})
	else:
		GameState.inventory.append(instance)

	EventBus.inventory_changed.emit()
	if notify:
		var display: String = str(instance.get("name", instance.get("name_unid", base.get("name", base_id))))
		EventBus.notification_shown.emit(Notification.item(display, 1))


func identify_instance(instance_id: String, player_level: int) -> bool:
	for i: int in GameState.inventory.size():
		var entry: Dictionary = GameState.inventory[i]
		if not entry.has("instance_id"):
			continue
		if str(entry["instance_id"]) != instance_id:
			continue
		if bool(entry.get("identified", false)):
			return false
		GameState.inventory[i] = ItemGenerator.identify(entry, player_level)
		EventBus.inventory_changed.emit()
		return true
	return false


func use_item(item_id: String) -> void:
	var item_data: Dictionary = ItemDB.get_item(item_id)
	if item_data.is_empty():
		return
	var cat: String = str(item_data.get("type", item_data.get("item_category", "")))
	if cat != "consumable":
		return
	var effect: Dictionary = item_data.get("effect", {}) as Dictionary
	if effect.is_empty():
		return
	var consumed: bool = false
	# HP restore (legacy "heal" + new "restore_hp")
	var hp_val: int = int(effect.get("restore_hp", effect.get("heal", 0)))
	if hp_val > 0:
		GameState.heal_player(hp_val)
		consumed = true
	# MP restore
	var mp_val: int = int(effect.get("restore_mp", 0))
	if mp_val > 0:
		GameState.player_stats["mp"] = mini(
			int(GameState.player_stats["mp"]) + mp_val,
			int(GameState.player_stats["max_mp"]))
		EventBus.player_stats_changed.emit()
		consumed = true
	# Stamina restore
	var st_val: int = int(effect.get("restore_stamina", 0))
	if st_val > 0:
		GameState.player_stats["stamina"] = mini(
			int(GameState.player_stats["stamina"]) + st_val,
			int(GameState.player_stats["max_stamina"]))
		EventBus.player_stats_changed.emit()
		consumed = true
	# Full restore (HP + MP + Stamina)
	if bool(effect.get("restore_all", false)):
		GameState.player_stats["hp"]      = int(GameState.player_stats["max_hp"])
		GameState.player_stats["mp"]      = int(GameState.player_stats["max_mp"])
		GameState.player_stats["stamina"] = int(GameState.player_stats["max_stamina"])
		EventBus.player_stats_changed.emit()
		consumed = true
	# Identify: auto-identifies the first unidentified item in inventory
	if bool(effect.get("identify", false)):
		for i: int in GameState.inventory.size():
			var entry: Dictionary = GameState.inventory[i]
			if entry.has("instance_id") and not bool(entry.get("identified", false)):
				GameState.inventory[i] = ItemGenerator.identify(entry, GameState.level)
				EventBus.inventory_changed.emit()
				consumed = true
				break
	if consumed:
		remove_item(item_id)
