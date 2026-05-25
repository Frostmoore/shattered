extends Node

const CRIME_FINE_PCT:        float = 0.25
const CRIME_REP_HIT_CRIME:   int   = -20
const CRIME_REP_HIT_ARREST:  int   = -10
const CRIME_GUARD_MIN_HP:    int   = 1
const CRIME_GUARD_COUNT:     int   = 6
const CRIME_GUARD_WAVE_TURNS: int  = 8
const CRIME_GUARD_WAVE_SIZE: int   = 3
const NPC_VIEW_RANGE:        int   = 30
const CRIME_NPC_REP_PENALTY: int   = -50

const GUARD_SPAWN_RADIUS_MIN: int = 3
const GUARD_SPAWN_RADIUS_MAX: int = 5

var _attacked_npcs:     Array[Node] = []
var _guard_wave_timer:  int         = 0
var _witness_check_result: bool     = false  # cached for DebugScreen display


func _ready() -> void:
	EventBus.player_turn_started.connect(_on_player_turn)


func _on_player_turn() -> void:
	if _guard_wave_timer <= 0:
		return
	_guard_wave_timer -= 1
	if _guard_wave_timer <= 0 and is_crime_active(GameState.current_city_id):
		_spawn_guards(CRIME_GUARD_WAVE_SIZE)
		_guard_wave_timer = CRIME_GUARD_WAVE_TURNS


# ── Public API ────────────────────────────────────────────────────────────────

func is_crime_active(city_id: String) -> bool:
	return GameState.get_crime_level(city_id) == 1


func get_criminal_record() -> Array:
	return GameState.criminal_record


func track_attacked_npc(npc: Node) -> void:
	if not _attacked_npcs.has(npc):
		_attacked_npcs.append(npc)


func register_crime(city_id: String) -> void:
	if GameState.get_crime_level(city_id) == 1:
		return  # already active
	GameState.set_crime_level(city_id, 1)
	FactionReputation.add_rep("milizia_campane", CRIME_REP_HIT_CRIME, "crime", false)
	_guard_wave_timer = CRIME_GUARD_WAVE_TURNS
	_spawn_guards(CRIME_GUARD_COUNT)
	EventBus.crime_committed.emit(city_id)
	EventBus.notification_shown.emit(Notification.crime_committed())


func arrest_player(city_id: String) -> void:
	var gold: int  = int(GameState.player_stats.get("gold", 0))
	var fine: int  = int(floor(gold * CRIME_FINE_PCT))
	GameState.player_stats["gold"] = maxi(0, gold - fine)
	EventBus.inventory_changed.emit()

	GameState.set_crime_level(city_id, 2)
	var city_name: String = _get_city_name(city_id)
	GameState.add_arrest_to_record(city_id, city_name)

	FactionReputation.add_rep("milizia_campane", CRIME_REP_HIT_ARREST, "arrest", false)
	_apply_post_crime_rep_penalty()

	_guard_wave_timer = 0
	_attacked_npcs.clear()

	_remove_all_guards()

	EventBus.player_arrested.emit(city_id, fine)
	EventBus.notification_shown.emit(Notification.player_arrested(fine))
	EventBus.player_stats_changed.emit()


func clear_crime(city_id: String) -> void:
	if not is_crime_active(city_id):
		return
	GameState.set_crime_level(city_id, 0)
	_guard_wave_timer = 0
	_attacked_npcs.clear()
	_remove_all_guards()
	EventBus.crime_cleared.emit(city_id)
	EventBus.notification_shown.emit(Notification.crime_cleared())


func initialize_for_new_game() -> void:
	GameState.crime_state.clear()
	GameState.criminal_record.clear()
	_attacked_npcs.clear()
	_guard_wave_timer = 0


# ── Witness detection ─────────────────────────────────────────────────────────

func has_witnesses(origin: Vector2i) -> bool:
	var map: BaseMap = WorldManager.get_current_map()
	if map == null:
		return false
	var result: bool = false
	for entity: Variant in map.get_children():
		if not is_instance_valid(entity):
			continue
		var node: Node = entity as Node
		if node == null:
			continue
		if node.get("npc_id") == null:
			continue  # not an NPC
		if _attacked_npcs.has(node):
			continue  # victim doesn't count as witness
		var npc_pos: Variant = node.get("grid_position")
		if not npc_pos is Vector2i:
			continue
		var dist: int = (origin - (npc_pos as Vector2i)).length()
		if dist > NPC_VIEW_RANGE:
			continue
		if map.has_line_of_sight(npc_pos as Vector2i, origin):
			result = true
			break
	_witness_check_result = result
	return result


# ── Guard spawning ────────────────────────────────────────────────────────────

func spawn_guards_debug(count: int) -> void:
	_spawn_guards(count)


func _spawn_guards(count: int) -> void:
	var map: BaseMap = WorldManager.get_current_map()
	if map == null:
		return
	var player_pos: Vector2i = GameState.player_position
	var guard_script: GDScript = load("res://scripts/entities/Guard.gd") as GDScript
	if guard_script == null:
		push_error("CrimeSystem: Guard.gd not found")
		return

	var spawned: Array = []
	for i: int in count:
		var pos: Vector2i = _find_spawn_pos(map, player_pos)
		if pos == Vector2i(-1, -1):
			continue
		var guard: Node = guard_script.new()
		guard.call("setup_guard", GameState.level)
		map._add_entity(guard, pos)
		spawned.append(guard)

	if spawned.is_empty():
		return

	if TurnManager.is_active:
		for g: Variant in spawned:
			TurnManager.register_enemy(g as Node)
	else:
		TurnManager.activate(spawned)


func _find_spawn_pos(map: BaseMap, origin: Vector2i) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _attempt: int in range(30):
		var dist: int = rng.randi_range(GUARD_SPAWN_RADIUS_MIN, GUARD_SPAWN_RADIUS_MAX)
		var angle: float = rng.randf() * TAU
		var dx: int = int(round(cos(angle) * dist))
		var dy: int = int(round(sin(angle) * dist))
		var candidate: Vector2i = origin + Vector2i(dx, dy)
		if map.is_walkable(candidate) and map.get_entity_at(candidate) == null:
			return candidate
	return Vector2i(-1, -1)


func _remove_all_guards() -> void:
	var map: BaseMap = WorldManager.get_current_map()
	if map == null:
		return
	for entity: Variant in map.get_children().duplicate():
		if not is_instance_valid(entity):
			continue
		if entity.get("is_guard") == true:
			(entity as Node).call("die")


# ── Post-crime rep penalty ────────────────────────────────────────────────────

func apply_post_crime_rep_on_flee() -> void:
	_apply_post_crime_rep_penalty()
	_attacked_npcs.clear()


func _apply_post_crime_rep_penalty() -> void:
	var map: BaseMap = WorldManager.get_current_map()
	var player_pos: Vector2i = GameState.player_position
	var factions_to_penalize: Dictionary = {}

	factions_to_penalize["milizia_campane"] = true

	if map != null:
		for entity: Variant in map.get_children():
			if not is_instance_valid(entity):
				continue
			var node: Node = entity as Node
			if node == null or node.get("npc_id") == null:
				continue
			var npc_pos: Variant = node.get("grid_position")
			if not npc_pos is Vector2i:
				continue
			if (player_pos - (npc_pos as Vector2i)).length() <= NPC_VIEW_RANGE:
				var fid: Variant = node.get("primary_faction_id")
				if fid is String and (fid as String) != "":
					factions_to_penalize[fid as String] = true

	for npc: Variant in _attacked_npcs:
		if not is_instance_valid(npc):
			continue
		var fid: Variant = (npc as Node).get("primary_faction_id")
		if fid is String and (fid as String) != "":
			factions_to_penalize[fid as String] = true

	for fid: String in factions_to_penalize:
		FactionReputation.add_rep(fid, CRIME_NPC_REP_PENALTY, "crime_penalty", false)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_city_name(city_id: String) -> String:
	var reg: Node = get_node_or_null("/root/FactionRegistry")
	if reg == null:
		return city_id
	# Try to get a readable name from LocationRegistry metadata
	var state: Variant = LocationRegistry.get_state(city_id)
	if state != null and (state as Object).get("metadata") is Dictionary:
		var name_v: Variant = ((state as Object).get("metadata") as Dictionary).get("name", "")
		if name_v is String and (name_v as String) != "":
			return name_v as String
	return city_id
