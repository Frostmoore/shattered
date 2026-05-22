extends Node2D
class_name BaseMap

var map_id: String = ""
var map_type: String = ""
var map_width: int = 0
var map_height: int = 0
# Dictionary (Vector2i → true) for O(1) walkability lookup
var _blocked_tiles: Dictionary = {}
var _transitions: Array[Dictionary] = []
var _entities: Array = []
var _entity_uids: Dictionary = {}        # entity node → spawn uid string
var _save_point_positions: Array[Vector2i] = []
var _map_data: MapData = null            # kept for enemy respawn
var _player: Player = null
var _corpses: Array[Dictionary] = []     # {pos: Vector2i, color: Color}

# ── Fog of War ────────────────────────────────────────────────────────────────
# _visible_tiles: transient per-frame visibility (0 = not in FOV, 1 = in FOV)
# _seen_tiles:    persistent memory (0 = never seen, 1 = seen before)
# Both are flat arrays: index = y * map_width + x
var _visible_tiles: PackedByteArray = PackedByteArray()
var _seen_tiles: PackedByteArray = PackedByteArray()


func _ready() -> void:
	_add_renderer()
	_spawn_player()
	_setup_turn_manager()
	EventBus.player_moved.connect(_on_player_moved)
	_on_player_moved(GameState.player_position)


# Called by WorldManager BEFORE add_child so _ready() sees populated data.
func populate(data: MapData, state: LocationState) -> void:
	map_id    = data.id
	map_type  = data.type
	map_width  = data.width
	map_height = data.height
	_map_data  = data

	_blocked_tiles = {}
	for wall: Vector2i in data.walls:
		_blocked_tiles[wall] = true

	_transitions = []
	for t: Dictionary in data.transitions:
		_transitions.append(t.duplicate(true))

	# Init fog arrays
	var tile_count: int = map_width * map_height
	_visible_tiles.resize(tile_count)
	_visible_tiles.fill(0)
	_seen_tiles.resize(tile_count)
	_seen_tiles.fill(0)

	var dead_uids: Array[String] = []
	var open_door_uids: Array[String] = []
	var saved_positions: Dictionary = {}

	if state != null:
		dead_uids       = state.dead_entity_uids
		open_door_uids  = state.open_entity_uids
		saved_positions = state.entity_positions
		# Restore fog of war
		if state.fog_of_war.size() == tile_count:
			_seen_tiles = state.fog_of_war.duplicate()
		# Restore corpses
		for cdef: Variant in state.corpse_defs:
			var d: Dictionary = cdef as Dictionary
			var raw_col: Variant = d.get("color", [])
			var col: Color = Color(0.35, 0.10, 0.06, 1.0)
			if raw_col is Array and (raw_col as Array).size() >= 4:
				var ca: Array = raw_col as Array
				col = Color(float(ca[0]), float(ca[1]), float(ca[2]), float(ca[3]))
			_corpses.append({"pos": Vector2i(int(d.get("x", 0)), int(d.get("y", 0))), "color": col})

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
			_spawn_entity(overridden, uid, open_door_uids)
		else:
			_spawn_entity(def, uid, open_door_uids)


func _spawn_entity(def: Dictionary, uid: String, open_door_uids: Array[String] = []) -> void:
	var kind: String       = def.get("kind", "")
	var raw_pos: Dictionary = def.get("pos", {"x": 0, "y": 0}) as Dictionary
	var pos: Vector2i      = Vector2i(int(raw_pos.get("x", 0)), int(raw_pos.get("y", 0)))
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

		"door":
			var door: Door = Door.new()
			var door_params: Dictionary = params.duplicate(true)
			door_params["uid"] = uid
			door_params["open"] = open_door_uids.has(uid)
			door.setup(door_params)
			_add_entity(door, pos, uid)

		"chest":
			var chest: Chest = Chest.new()
			chest.setup(params)
			_add_entity(chest, pos, uid)

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
		# Doors: track open state
		if e is Door:
			if (e as Door).is_open:
				state.open_entity_uids.append(uid)
			continue
		# Chests: is_dead = true means looted — save as dead so they don't respawn
		if e is Chest:
			if e.get("is_dead") == true:
				state.dead_entity_uids.append(uid)
			continue
		if e.get("is_dead") == true:
			state.dead_entity_uids.append(uid)
		else:
			var pos: Variant = e.get("grid_position")
			if pos is Vector2i:
				state.entity_positions[uid] = {"x": (pos as Vector2i).x, "y": (pos as Vector2i).y}

	# Persist fog of war
	state.fog_of_war = _seen_tiles.duplicate()

	# Persist corpses
	for corpse: Dictionary in _corpses:
		var cpos: Vector2i = corpse["pos"] as Vector2i
		var ccol: Color    = corpse["color"] as Color
		state.corpse_defs.append({
			"x": cpos.x, "y": cpos.y,
			"color": [ccol.r, ccol.g, ccol.b, ccol.a],
		})

	LocationRegistry.set_state(map_id, state)


func add_corpse(pos: Vector2i, color: Color) -> void:
	_corpses.append({"pos": pos, "color": color})


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


# ── Walkability ───────────────────────────────────────────────────────────────

func is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= map_width or pos.y >= map_height:
		return false
	return not _blocked_tiles.has(pos)


func is_blocked_tile(pos: Vector2i) -> bool:
	return _blocked_tiles.has(pos)


# ── Entity queries ────────────────────────────────────────────────────────────

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


func get_entity_uid(entity: Node) -> String:
	return str(_entity_uids.get(entity, ""))


# Called by Door when opened — persists open state without a full save
func mark_door_open(uid: String) -> void:
	var state: LocationState = LocationRegistry.get_state(map_id)
	if state == null:
		state = LocationState.new()
		state.location_id = map_id
		state.visited = true
		LocationRegistry.set_state(map_id, state)
	if not state.open_entity_uids.has(uid):
		state.open_entity_uids.append(uid)


# Called by Chest when looted — marks uid so it is excluded on next load
func mark_entity_dead_for_save(uid: String) -> void:
	var state: LocationState = LocationRegistry.get_state(map_id)
	if state == null:
		state = LocationState.new()
		state.location_id = map_id
		state.visited = true
		LocationRegistry.set_state(map_id, state)
	if not state.dead_entity_uids.has(uid):
		state.dead_entity_uids.append(uid)


# ── Enemy respawn ─────────────────────────────────────────────────────────────

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

	_corpses.clear()
	var renderer: Node = get_node_or_null("MapRenderer")
	if renderer != null:
		renderer.queue_redraw()


func _add_entity(entity: Node, pos: Vector2i, uid: String = "") -> void:
	_entities.append(entity)
	if uid != "":
		_entity_uids[entity] = uid
	add_child(entity)
	entity.grid_position = pos
	entity.snap_to_grid()


# ── Fog of War / Field of View ────────────────────────────────────────────────

func _on_player_moved(_pos: Vector2i) -> void:
	if map_width == 0 or map_height == 0:
		return
	_compute_fov(GameState.player_position, GameBalance.FOV_RADIUS)


func _compute_fov(origin: Vector2i, radius: int) -> void:
	_visible_tiles.fill(0)
	# Mark tiles in a circular area visible if there is an unobstructed line from origin
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var target: Vector2i = origin + Vector2i(dx, dy)
			if target.x < 0 or target.y < 0 or target.x >= map_width or target.y >= map_height:
				continue
			if _has_line_of_sight(origin, target):
				var idx: int = target.y * map_width + target.x
				_visible_tiles[idx] = 1
				_seen_tiles[idx] = 1


func _has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	# Bresenham walk; intermediate tiles (not 'from', not 'to') must be transparent
	var x0: int = from.x;  var y0: int = from.y
	var x1: int = to.x;    var y1: int = to.y
	var dx: int = abs(x1 - x0);  var sx: int = 1 if x0 < x1 else -1
	var dy: int = abs(y1 - y0);  var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	var cx: int = x0;  var cy: int = y0
	var max_steps: int = dx + dy + 2  # safety cap

	for _step: int in range(max_steps):
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			cx += sx
		if e2 < dx:
			err += dx
			cy += sy
		if cx == x1 and cy == y1:
			return true  # reached destination unobstructed
		if _is_opaque(Vector2i(cx, cy)):
			return false
	return true


func _is_opaque(pos: Vector2i) -> bool:
	if _blocked_tiles.has(pos):
		return true
	if GameBalance.FOV_DOORS_BLOCK_SIGHT:
		var e: Node = get_entity_at(pos)
		if e != null and e.get("is_open") != null and not bool(e.get("is_open")):
			return true
	return false


## Returns 1 if tile is currently in FOV, 0 otherwise.
func is_tile_visible(pos: Vector2i) -> int:
	if pos.x < 0 or pos.y < 0 or pos.x >= map_width or pos.y >= map_height:
		return 0
	return int(_visible_tiles[pos.y * map_width + pos.x])


## Returns 1 if tile has ever been seen (fog-of-war memory), 0 otherwise.
func is_tile_seen(pos: Vector2i) -> int:
	if pos.x < 0 or pos.y < 0 or pos.x >= map_width or pos.y >= map_height:
		return 0
	return int(_seen_tiles[pos.y * map_width + pos.x])
