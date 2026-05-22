extends Node

# id → {type, params}
var _definitions: Dictionary = {}
# id → MapData  (generated on first access or pre-baked, then cached)
var _cache: Dictionary = {}
# id → LocationState
var _states: Dictionary = {}
# id → MapData  (pre-baked floors from procedural generation)
var _prebuilt: Dictionary = {}


func clear() -> void:
	_definitions.clear()
	_cache.clear()
	_states.clear()
	_prebuilt.clear()


func register(id: String, type: String, params: Dictionary) -> void:
	_definitions[id] = {"type": type, "params": params.duplicate(true)}
	_cache.erase(id)


## Store a fully-generated MapData directly, bypassing generator.
## Used for procedurally generated dungeon floors whose layout must persist across sessions.
func register_prebuilt(id: String, data: MapData) -> void:
	_prebuilt[id] = data
	_cache[id] = data
	_definitions[id] = {"type": "prebuilt", "params": {}}


func get_or_generate(id: String) -> MapData:
	if _cache.has(id):
		return _cache[id] as MapData
	if not _definitions.has(id):
		push_error("LocationRegistry: unknown location: " + id)
		return null
	var def: Dictionary = _definitions[id] as Dictionary
	var type: String = str(def["type"])
	if type == "prebuilt":
		# Should be in _cache already if register_prebuilt was called; fallback to _prebuilt
		if _prebuilt.has(id):
			_cache[id] = _prebuilt[id]
			return _prebuilt[id] as MapData
		push_error("LocationRegistry: prebuilt data missing for: " + id)
		return null
	var p: Dictionary = (def["params"] as Dictionary).duplicate(true)
	p["id"] = id
	var data: MapData = _generate(type, p)
	_cache[id] = data
	return data


func _generate(type: String, params: Dictionary) -> MapData:
	match type:
		"overworld": return OverworldGenerator.generate(params)
		"village":   return VillageGenerator.generate(params)
		"dungeon":   return DungeonGenerator.generate(params)
		"building":  return BuildingGenerator.generate(params)
		_:
			push_error("LocationRegistry: unknown type: " + type)
			return MapData.new()


func set_state(id: String, state: LocationState) -> void:
	_states[id] = state


func get_state(id: String) -> LocationState:
	return _states.get(id, null) as LocationState


func has_location(id: String) -> bool:
	return _definitions.has(id)


# ── Serialization ─────────────────────────────────────────────────────────────

func serialize_definitions() -> Dictionary:
	var locs: Dictionary = {}
	for id: String in _definitions:
		var def: Dictionary = _definitions[id] as Dictionary
		if str(def["type"]) == "prebuilt" and _prebuilt.has(id):
			locs[id] = {
				"type":    "prebuilt",
				"params":  {},
				"mapdata": (_prebuilt[id] as MapData).serialize()
			}
		else:
			locs[id] = def.duplicate(true)
	return {"locations": locs}


func serialize_states() -> Dictionary:
	var states: Dictionary = {}
	for id: String in _states:
		states[id] = (_states[id] as LocationState).serialize()
	return states


func deserialize_definitions(data: Dictionary) -> void:
	_definitions.clear()
	_cache.clear()
	_prebuilt.clear()
	var raw_locs: Variant = data.get("locations", {})
	if not raw_locs is Dictionary:
		return
	for id: Variant in (raw_locs as Dictionary):
		var loc: Dictionary = (raw_locs as Dictionary)[id] as Dictionary
		var loc_type: String = str(loc.get("type", ""))
		if loc_type == "prebuilt":
			var raw_md: Variant = loc.get("mapdata", {})
			if raw_md is Dictionary:
				var md: MapData = MapData.from_dict(raw_md as Dictionary)
				register_prebuilt(str(id), md)
		else:
			register(
				str(id),
				loc_type,
				loc.get("params", {}) as Dictionary
			)


func deserialize_states(data: Dictionary) -> void:
	_states.clear()
	for id: Variant in data:
		var sd: Dictionary = (data as Dictionary)[id] as Dictionary
		_states[str(id)] = LocationState.deserialize(sd)


func clear_states() -> void:
	_states.clear()


## Remove dead non-boss enemy UIDs from all unloaded dungeon floors so they respawn on next visit.
## Called when the player uses a save point.
func respawn_non_boss_enemies_in_unloaded_floors(exclude_map_id: String) -> void:
	for raw_id: Variant in _states:
		var map_id: String = str(raw_id)
		if map_id == exclude_map_id:
			continue
		if not _prebuilt.has(map_id):
			continue
		var state: LocationState = _states[map_id] as LocationState
		if state == null or state.dead_entity_uids.is_empty():
			continue
		var map_data: MapData = _prebuilt[map_id] as MapData
		if map_data == null:
			continue
		# Index boss UIDs from the prebuilt entity definitions
		var boss_uids: Dictionary = {}
		for def: Dictionary in map_data.entity_defs:
			var uid: String = str(def.get("uid", ""))
			var params: Dictionary = def.get("params", {}) as Dictionary
			if bool(params.get("boss", false)):
				boss_uids[uid] = true
		# Retain only boss UIDs in the dead list; regular enemies will respawn
		var kept: Array[String] = []
		for uid: String in state.dead_entity_uids:
			if boss_uids.has(uid):
				kept.append(uid)
		state.dead_entity_uids = kept
		state.corpse_defs.clear()
