extends Node

# id → {type, params}
var _definitions: Dictionary = {}
# id → MapData  (generated on first access, then cached)
var _cache: Dictionary = {}
# id → LocationState
var _states: Dictionary = {}


func clear() -> void:
	_definitions.clear()
	_cache.clear()
	_states.clear()


func register(id: String, type: String, params: Dictionary) -> void:
	_definitions[id] = {"type": type, "params": params.duplicate(true)}
	_cache.erase(id)


func get_or_generate(id: String) -> MapData:
	if _cache.has(id):
		return _cache[id] as MapData
	if not _definitions.has(id):
		push_error("LocationRegistry: unknown location: " + id)
		return null
	var def: Dictionary = _definitions[id] as Dictionary
	var p: Dictionary   = (def["params"] as Dictionary).duplicate(true)
	p["id"] = id
	var data: MapData = _generate(str(def["type"]), p)
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


# ── Serialization (split: world saves definitions, character saves states) ──

func serialize_definitions() -> Dictionary:
	var locs: Dictionary = {}
	for id: String in _definitions:
		locs[id] = (_definitions[id] as Dictionary).duplicate(true)
	return {"locations": locs}


func serialize_states() -> Dictionary:
	var states: Dictionary = {}
	for id: String in _states:
		states[id] = (_states[id] as LocationState).serialize()
	return states


func deserialize_definitions(data: Dictionary) -> void:
	_definitions.clear()
	_cache.clear()
	var raw_locs: Variant = data.get("locations", {})
	if raw_locs is Dictionary:
		for id: Variant in (raw_locs as Dictionary):
			var loc: Dictionary = (raw_locs as Dictionary)[id] as Dictionary
			register(
				str(id),
				str(loc.get("type", "")),
				loc.get("params", {}) as Dictionary
			)


func deserialize_states(data: Dictionary) -> void:
	_states.clear()
	for id: Variant in data:
		var sd: Dictionary = (data as Dictionary)[id] as Dictionary
		_states[str(id)] = LocationState.deserialize(sd)


func clear_states() -> void:
	_states.clear()
