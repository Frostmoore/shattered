extends Node

const MAX_LEVEL: int = 100


func add_xp(amount: int) -> void:
	if amount <= 0 or GameState.level >= MAX_LEVEL:
		return
	GameState.xp += amount
	EventBus.xp_gained.emit(amount)
	_check_level_up()


func xp_for_next_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(floor(100.0 * pow(level, 1.4)))


func get_xp_progress() -> float:
	var needed: int = xp_for_next_level(GameState.level)
	if needed <= 0:
		return 1.0
	return clampf(float(GameState.xp) / float(needed), 0.0, 1.0)


func _check_level_up() -> void:
	while GameState.level < MAX_LEVEL:
		var needed: int = xp_for_next_level(GameState.level)
		if GameState.xp < needed:
			break
		GameState.xp -= needed
		GameState.level += 1
		_apply_level_up()


func _apply_level_up() -> void:
	for attr: String in GameState.attributes:
		GameState.attributes[attr] = int(GameState.attributes[attr]) + 1
	GameState.recalculate_derived_stats()
	# Heal all resources to full on level up
	GameState.player_stats["hp"]      = int(GameState.player_stats["max_hp"])
	GameState.player_stats["mp"]      = int(GameState.player_stats["max_mp"])
	GameState.player_stats["stamina"] = int(GameState.player_stats["max_stamina"])
	EventBus.player_leveled_up.emit(GameState.level)
	EventBus.player_stats_changed.emit()
	EventBus.notification_shown.emit(Notification.level_up(GameState.level))
