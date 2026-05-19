extends Entity
class_name Chest

var _looted: bool = false


func _ready() -> void:
	faction     = "neutral"
	is_blocking = true
	_setup_visual("$", Color(0.95, 0.80, 0.10, 1))


func setup(_params: Dictionary) -> void:
	pass


func interact(_player: Node) -> void:
	if _looted:
		EventBus.notification_shown.emit(Notification.warning("Il forziere è vuoto."))
		return
	_looted = true
	is_dead  = true  # save_location_state() uses this to mark uid as dead

	var item_id: String = _roll_loot()
	if item_id != "":
		Inventory.add_item(item_id)
	else:
		EventBus.notification_shown.emit(Notification.warning("Forziere vuoto!"))

	# Update visual to show empty chest
	var lbl: Label = get_node_or_null("Label") as Label
	if lbl != null:
		lbl.text = "_"
		if lbl.label_settings != null:
			lbl.label_settings.font_color = Color(0.45, 0.40, 0.20, 1)

	EventBus.map_changed.emit(GameState.current_map_id)


func _roll_loot() -> String:
	var player_level: int = GameState.level
	var eligible: Array = []
	var total_weight: int = 0
	for entry: Variant in GameBalance.CHEST_LOOT_TABLE:
		var e: Dictionary = entry as Dictionary
		if int(e["min_level"]) <= player_level:
			eligible.append(e)
			total_weight += int(e["weight"])
	if total_weight == 0:
		return ""
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for e: Variant in eligible:
		var entry: Dictionary = e as Dictionary
		cumulative += int(entry["weight"])
		if roll < cumulative:
			return str(entry["item_id"])
	return ""
