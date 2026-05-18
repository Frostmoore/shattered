extends Entity
class_name Enemy

var enemy_data_id: String = ""
var detection_range: int = 5
var xp_reward: int = 0
var is_boss: bool = false


func setup(data: Dictionary) -> void:
	enemy_data_id = data.get("id", "unknown_enemy")
	display_name   = data.get("name", "Enemy")
	hp             = data.get("hp", 8)
	max_hp         = hp
	attack         = data.get("attack", 3)
	defense        = data.get("defense", 0)
	xp_reward      = data.get("xp_reward", 0)
	is_boss        = bool(data.get("boss", false))
	faction        = "enemy"

	var char: String
	var col: Color
	match enemy_data_id:
		"goblin":
			char = "g"
			col  = Color(0.28, 0.88, 0.28, 1)
		"skeleton":
			char = "s"
			col  = Color(0.80, 0.78, 0.70, 1)
		"mine_boss":
			char = "B"
			col  = Color(1.00, 0.12, 0.12, 1)
		_:
			char = "e"
			col  = Color(0.88, 0.28, 0.28, 1)
	_setup_visual(char, col)


func take_turn() -> void:
	if is_dead:
		return
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return
	var player: Node = map.get_player()
	if player == null or player.is_dead:
		return

	var dist: int = _manhattan(grid_position, player.grid_position)

	if dist <= 1:
		CombatManager.attack(self, player)
	elif dist <= detection_range:
		_move_toward(player.grid_position, map)

	EventBus.turn_ended.emit(self)


func _move_toward(target: Vector2i, map: BaseMap) -> void:
	var dx: int = int(sign(target.x - grid_position.x))
	var dy: int = int(sign(target.y - grid_position.y))
	var options: Array[Vector2i] = []
	if abs(target.x - grid_position.x) >= abs(target.y - grid_position.y):
		options = [Vector2i(dx, 0), Vector2i(0, dy)]
	else:
		options = [Vector2i(0, dy), Vector2i(dx, 0)]

	for step: Vector2i in options:
		if step == Vector2i.ZERO:
			continue
		var candidate: Vector2i = grid_position + step
		if map.is_walkable(candidate) and map.get_entity_at(candidate) == null:
			move_to(candidate)
			return


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func die() -> void:
	is_dead = true
	TurnManager.unregister_enemy(self)
	EventBus.enemy_died.emit(self)
	QuestManager.on_enemy_killed(enemy_data_id)
	LevelSystem.add_xp(xp_reward)
	queue_free()
