extends Node

# Gestisce gli alleati del player come nodi reali sulla mappa.
# Permanenti: salvati in GameState, rispawnati ad ogni cambio mappa.
# Temporanei: rimossi al cambio mappa.

var _allies: Array = []  # Array[Ally node]


func _ready() -> void:
	EventBus.map_changed.connect(_on_map_changed)


# ── API pubblica ──────────────────────────────────────────────────────────────

func add_ally(data: Dictionary) -> void:
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		push_error("AllyManager.add_ally: no current map")
		return
	var ally: Node = _spawn_ally_node(data, map)
	if ally == null:
		return
	EventBus.combat_log.emit("%s si unisce a te!" % str(data.get("display_name", "Alleato")))
	_sync_permanent_to_gamestate()


func remove_ally_type(type: String) -> void:
	var to_remove: Array = []
	for a: Variant in _allies:
		if is_instance_valid(a) and str(a.get("ally_type")) == type:
			to_remove.append(a)
	for a: Variant in to_remove:
		_allies.erase(a)
		(a as Node).queue_free()
	_sync_permanent_to_gamestate()


func has_ally_type(type: String) -> bool:
	for a: Variant in _allies:
		if is_instance_valid(a) and str(a.get("ally_type")) == type:
			return true
	return false


func get_allies() -> Array:
	_allies = _allies.filter(func(a: Variant) -> bool: return is_instance_valid(a))
	return _allies.duplicate()


func get_ally_count() -> int:
	return get_allies().size()


func clear_temp_allies() -> void:
	var to_remove: Array = []
	for a: Variant in _allies:
		if is_instance_valid(a) and not bool(a.get("permanent")):
			to_remove.append(a)
	for a: Variant in to_remove:
		_allies.erase(a)
		EventBus.combat_log.emit("%s scompare." % str(a.get("display_name")))
		(a as Node).queue_free()


func restore_permanent(_saved: Array) -> void:
	# No-op: permanent allies are respawned in _on_map_changed from GameState.permanent_allies.
	# SaveManager calls this but _apply_save_data already sets GameState.permanent_allies.
	pass


func run_ally_turns() -> void:
	_allies = _allies.filter(func(a: Variant) -> bool: return is_instance_valid(a))
	for a: Variant in _allies.duplicate():
		if is_instance_valid(a) and not bool(a.get("is_dead")):
			(a as Node).call("take_turn")
	_tick_temp_allies()


func _on_ally_died(ally: Node) -> void:
	_allies.erase(ally)
	_sync_permanent_to_gamestate()


# ── Cambio piano ──────────────────────────────────────────────────────────────

func _on_map_changed(_map_id: String) -> void:
	# Old ally nodes are children of the old map (queued for free) — just clear refs.
	_allies.clear()
	_spawn_permanent_allies()


func _spawn_permanent_allies() -> void:
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return
	for entry: Variant in GameState.permanent_allies:
		if not entry is Dictionary:
			continue
		var d: Dictionary = (entry as Dictionary).duplicate()
		d["permanent"] = true
		d["turns_left"] = -1
		d["hp"] = int(d.get("max_hp", 10))
		_spawn_ally_node(d, map)


# ── Internal ──────────────────────────────────────────────────────────────────

func _spawn_ally_node(data: Dictionary, map: BaseMap) -> Node:
	var scene: PackedScene = load("res://scenes/entities/Ally.tscn")
	if scene == null:
		push_error("AllyManager: Ally.tscn not found")
		return null
	var ally: Node = scene.instantiate()
	ally.call("setup", data)
	var spawn_pos: Vector2i = _find_spawn_pos(map)
	map.call("_add_entity", ally, spawn_pos, "")
	_allies.append(ally)
	return ally


func _find_spawn_pos(map: BaseMap) -> Vector2i:
	var pp: Vector2i = GameState.player_position
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for d: Vector2i in dirs:
		var c: Vector2i = pp + d
		if map.is_walkable(c) and map.get_entity_at(c) == null:
			return c
	for radius: int in range(2, 8):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var c: Vector2i = pp + Vector2i(dx, dy)
				if map.is_walkable(c) and map.get_entity_at(c) == null:
					return c
	return pp


func _tick_temp_allies() -> void:
	var expired: Array[String] = []
	for a: Variant in get_allies():
		var tl: int = int(a.get("turns_left"))
		if tl < 0:
			continue
		tl -= 1
		(a as Node).set("turns_left", tl)
		if tl <= 0:
			expired.append(str(a.get("ally_type")))
			EventBus.combat_log.emit("%s scompare." % str(a.get("display_name")))
	for t: String in expired:
		remove_ally_type(t)


func _sync_permanent_to_gamestate() -> void:
	var perms: Array = []
	for a: Variant in get_allies():
		if bool(a.get("permanent")):
			perms.append((a as Node).call("to_dict"))
	GameState.permanent_allies = perms
