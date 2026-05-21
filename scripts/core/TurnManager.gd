extends Node

var is_active: bool = false
var is_player_turn: bool = true
var _enemies: Array = []


func activate(enemies: Array) -> void:
	_enemies = enemies
	is_active = true
	is_player_turn = true
	EventBus.combat_started.emit()
	EventBus.player_turn_started.emit()


func deactivate() -> void:
	if is_active:
		EventBus.combat_ended.emit()
	is_active = false
	_enemies = []


func register_enemy(enemy: Node) -> void:
	if not _enemies.has(enemy):
		_enemies.append(enemy)


func unregister_enemy(enemy: Node) -> void:
	_enemies.erase(enemy)
	if _enemies.is_empty() and is_active:
		deactivate()


func on_player_action_done() -> void:
	if not is_active:
		return
	is_player_turn = false
	_run_ally_turns()
	_run_enemy_turns()


func _run_ally_turns() -> void:
	var ally_mgr: Node = get_node_or_null("/root/AllyManager")
	if ally_mgr:
		ally_mgr.call("run_ally_turns")


func _run_enemy_turns() -> void:
	for enemy in _enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_turn()
	_check_deaths()
	if is_active:
		is_player_turn = true
		EventBus.player_turn_started.emit()


func _check_deaths() -> void:
	for enemy in _enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_dead:
			_enemies.erase(enemy)
	if _enemies.is_empty() and is_active:
		deactivate()
