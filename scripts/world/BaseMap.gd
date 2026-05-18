extends Node2D
class_name BaseMap

var map_id: String = ""
var map_type: String = ""
var map_width: int = 0
var map_height: int = 0
var _blocked_tiles: Array[Vector2i] = []
var _transitions: Array[Dictionary] = []
var _entities: Array = []
var _entity_uids: Dictionary = {}        # entity node → spawn uid string
var _save_point_positions: Array[Vector2i] = []
var _map_data: MapData = null            # kept for enemy respawn
var _player: Player = null


func _ready() -> void:
	_add_renderer()
	_spawn_player()
	_setup_turn_manager()


# Called by WorldManager BEFORE add_child so _ready() sees populated data.
func populate(data: MapData, state: LocationState) -> void:
	map_id    = data.id
	map_type  = data.type
	map_width  = data.width
	map_height = data.height
	_map_data  = data

	_blocked_tiles = data.walls.duplicate()
	_transitions   = data.transitions.duplicate(true)

	var dead_uids: Array[String] = []
	var saved_positions: Dictionary = {}
	if state != null:
		dead_uids       = state.dead_entity_uids
		saved_positions = state.entity_positions

	for def: Dictionary in data.entity_defs:
		var uid: String = def.get("uid", "")
		var kind: String = def.get("kind", "")
		if kind == "save_point":
			var raw: Dictionary = def.get("pos", {"x": 0, "y": 0}) as Dictionary
			_save_point_positions.append(Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0))))
			continue
		if dead_uids.has(uid):
			continue
		var spawn_pos: Variant = saved_positions.get(uid, null)
		if spawn_pos is Dictionary:
			var sp: Dictionary = spawn_pos as Dictionary
			var overridden: Dictionary = def.duplicate(true)
			overridden["pos"] = {"x": int(sp.get("x", 0)), "y": int(sp.get("y", 0))}
			_spawn_entity(overridden, uid)
		else:
			_spawn_entity(def, uid)


func _spawn_entity(def: Dictionary, uid: String) -> void:
	var kind: String    = def.get("kind", "")
	var raw_pos: Dictionary = def.get("pos", {"x": 0, "y": 0}) as Dictionary
	var pos: Vector2i   = Vector2i(int(raw_pos.get("x", 0)), int(raw_pos.get("y", 0)))
	var params: Dictionary = def.get("params", {}) as Dictionary

	match kind:
		"enemy":
			var scene: PackedScene = load("res://scenes/entities/Enemy.tscn")
			var enemy: Enemy = scene.instantiate()
			enemy.setup(params)
			if params.has("detection_range"):
				enemy.detection_range = int(params["detection_range"])
			_add_entity(enemy, pos, uid)
		"npc":
			var scene: PackedScene = load("res://scenes/entities/NPC.tscn")
			var npc: NPC = scene.instantiate()
			npc.setup(params)
			_add_entity(npc, pos, uid)
		_:
			push_error("BaseMap: unknown entity kind: " + kind)


# Save current location state to registry (called by WorldManager before freeing).
func save_location_state() -> void:
	if map_id == "":
		return
	var state := LocationState.new()
	state.location_id = map_id
	state.visited = true
	for entity_node: Variant in _entity_uids:
		var uid: String = str(_entity_uids[entity_node])
		if not is_instance_valid(entity_node):
			state.dead_entity_uids.append(uid)
			continue
		var e: Node = entity_node as Node
		if e == null:
			continue
		if e.get("is_dead") == true:
			state.dead_entity_uids.append(uid)
		else:
			var pos: Variant = e.get("grid_position")
			if pos is Vector2i:
				state.entity_positions[uid] = {"x": (pos as Vector2i).x, "y": (pos as Vector2i).y}
	LocationRegistry.set_state(map_id, state)


func _add_renderer() -> void:
	var renderer: Node2D = load("res://scripts/world/MapRenderer.gd").new()
	renderer.name = "MapRenderer"
	add_child(renderer)


func _spawn_player() -> void:
	var player_scene: PackedScene = load("res://scenes/entities/Player.tscn")
	_player = player_scene.instantiate()
	add_child(_player)
	_player.grid_position = GameState.player_position
	_player.snap_to_grid()
	var cam := Camera2D.new()
	cam.enabled = true
	cam.zoom = Vector2(SettingsManager.zoom_level, SettingsManager.zoom_level)
	_player.add_child(cam)
	EventBus.settings_changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam != null:
		cam.zoom = Vector2(SettingsManager.zoom_level, SettingsManager.zoom_level)


func _setup_turn_manager() -> void:
	var enemies: Array = []
	for e: Variant in _entities:
		if is_instance_valid(e) and e is Enemy:
			enemies.append(e)
	if enemies.size() > 0:
		TurnManager.activate(enemies)
	else:
		TurnManager.deactivate()


func is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= map_width or pos.y >= map_height:
		return false
	return not _blocked_tiles.has(pos)


func is_blocked_tile(pos: Vector2i) -> bool:
	return _blocked_tiles.has(pos)


func get_entity_at(pos: Vector2i) -> Node:
	if _player != null and _player.grid_position == pos and not _player.is_dead:
		return _player
	_entities = _entities.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	for e: Variant in _entities:
		if not is_instance_valid(e):
			continue
		var entity: Node = e as Node
		if entity != null and entity.grid_position == pos and not entity.is_dead:
			return entity
	return null


func get_transition_at(pos: Vector2i) -> Variant:
	for t: Dictionary in _transitions:
		if t["position"] == pos:
			return t
	return null


func get_player() -> Player:
	return _player


func has_save_point_at(pos: Vector2i) -> bool:
	return _save_point_positions.has(pos)


func respawn_non_boss_enemies() -> void:
	if _map_data == null:
		return
	var dead_node_keys: Array = []
	var uids_to_respawn: Array[String] = []

	for entity_node: Variant in _entity_uids:
		var uid: String = str(_entity_uids[entity_node])
		var node_is_dead: bool = not is_instance_valid(entity_node)
		if not node_is_dead:
			var e: Node = entity_node as Node
			if e == null or e.get("is_dead") != true:
				continue
		# Dead node — find its def to check boss flag
		for def: Dictionary in _map_data.entity_defs:
			if def.get("uid", "") != uid or def.get("kind", "") != "enemy":
				continue
			dead_node_keys.append(entity_node)
			var p: Dictionary = def.get("params", {}) as Dictionary
			if not bool(p.get("boss", false)):
				uids_to_respawn.append(uid)
			break

	for key: Variant in dead_node_keys:
		_entity_uids.erase(key)

	for uid: String in uids_to_respawn:
		for def: Dictionary in _map_data.entity_defs:
			if def.get("uid", "") == uid:
				_spawn_entity(def, uid)
				break

	if uids_to_respawn.size() > 0:
		_setup_turn_manager()


func _add_entity(entity: Node, pos: Vector2i, uid: String = "") -> void:
	_entities.append(entity)
	if uid != "":
		_entity_uids[entity] = uid
	add_child(entity)
	entity.grid_position = pos
	entity.snap_to_grid()
