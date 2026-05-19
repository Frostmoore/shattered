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

	# Look up visual from ENEMY_TABLE
	var char: String = "e"
	var col: Color   = Color(0.88, 0.28, 0.28, 1)
	for entry: Variant in GameBalance.get_enemy_table():
		var e: Dictionary = entry as Dictionary
		if str(e["id"]) == enemy_data_id:
			char = str(e["char"])
			var c: Array = e["color"] as Array
			col = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
			break
	# Boss: uppercase glyph, bright red
	if is_boss:
		char = char.to_upper()
		col = Color(1.0, 0.15, 0.15, 1.0)
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
		if not map.is_walkable(candidate):
			continue
		var entity_at: Node = map.get_entity_at(candidate)
		if entity_at == null:
			move_to(candidate)
			return
		# Open closed doors instead of blocking
		if entity_at.get("is_open") != null and not bool(entity_at.get("is_open")):
			entity_at.call("open")
			return


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func die() -> void:
	is_dead = true
	TurnManager.unregister_enemy(self)
	EventBus.enemy_died.emit(self)
	QuestManager.on_enemy_killed(enemy_data_id)
	if is_boss:
		QuestManager.on_enemy_killed("dungeon_boss")
	LevelSystem.add_xp(xp_reward)
	queue_free()
