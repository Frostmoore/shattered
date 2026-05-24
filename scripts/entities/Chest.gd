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
		EventBus.notification_shown.emit(Notification.warning(LocaleManager.t("UI_CHEST_EMPTY_LOOTED")))
		return
	_looted = true
	is_dead  = true  # save_location_state() uses this to mark uid as dead

	var drops: Array = _roll_loot()
	if drops.is_empty():
		EventBus.notification_shown.emit(Notification.warning(LocaleManager.t("UI_CHEST_EMPTY_NO_LOOT")))
	else:
		EventBus.loot_screen_open.emit(drops, "Forziere")

	# Update visual to show empty chest
	var lbl: Label = get_node_or_null("Label") as Label
	if lbl != null:
		lbl.text = "_"
		if lbl.label_settings != null:
			lbl.label_settings.font_color = Color(0.45, 0.40, 0.20, 1)

	EventBus.map_changed.emit(GameState.current_map_id)


func _roll_loot() -> Array:
	var map: BaseMap = get_parent() as BaseMap
	var floor_num: int = 1
	if map != null:
		var parts: Array = str(map.get("map_id")).split("_")
		for part: String in parts:
			if part.is_valid_int():
				floor_num = int(part)
				break
	var ctx: Dictionary = {
		"source_type":   "chest",
		"source_id":     "chest",
		"chest_variant": "comune",
		"player_class":  str(GameState.current_class),
		"player_level":  GameState.level,
		"floor":         floor_num,
	}
	return LootResolver.resolve(ctx)
