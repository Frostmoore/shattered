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
	GameState.player_stats["max_hp"] = int(GameState.player_stats["max_hp"]) + 5
	GameState.player_stats["hp"]     = GameState.player_stats["max_hp"]
	GameState.player_stats["attack"] = int(GameState.player_stats["attack"]) + 1
	EventBus.player_leveled_up.emit(GameState.level)
	EventBus.player_stats_changed.emit()
	EventBus.notification_shown.emit(Notification.level_up(GameState.level))
