extends Node

const TILE_SIZE: int = 16

const TYPE_SCENES: Dictionary = {
	"overworld": "res://scenes/world/OverworldMap.tscn",
	"village":   "res://scenes/world/VillageMap.tscn",
	"dungeon":   "res://scenes/world/DungeonMap.tscn",
	"building":  "res://scenes/world/BuildingMap.tscn",
}

var _current_map_node: BaseMap = null
var _map_container: Node = null


func init(container: Node) -> void:
	_map_container = container


func change_map(location_id: String, spawn_position: Vector2i) -> void:
	if not LocationRegistry.has_location(location_id):
		push_error("WorldManager: unknown location: " + location_id)
		return

	# Save state and unload current map.
	if _current_map_node != null and is_instance_valid(_current_map_node):
		TurnManager.deactivate()
		_current_map_node.save_location_state()
		_current_map_node.queue_free()
		_current_map_node = null

	GameState.current_map_id  = location_id
	GameState.player_position = spawn_position

	var data: MapData       = LocationRegistry.get_or_generate(location_id)
	GameState.current_location_faction_id = str(data.metadata.get("signoria", ""))
	var state: LocationState = LocationRegistry.get_state(location_id)

	_update_city_id(location_id, data)

	var scene_path: String = TYPE_SCENES.get(data.type, "")
	if scene_path == "":
		push_error("WorldManager: no scene for type: " + data.type)
		return

	var scene: PackedScene = load(scene_path)
	_current_map_node = scene.instantiate() as BaseMap
	# Inject data BEFORE entering the tree so _ready() can use it.
	_current_map_node.populate(data, state)
	_map_container.add_child(_current_map_node)

	EventBus.map_changed.emit(location_id)


func _update_city_id(location_id: String, data: MapData) -> void:
	match data.type:
		"village", "city":
			var prev_city: String = GameState.current_city_id
			if prev_city != "" and prev_city != location_id:
				_on_leave_city(prev_city)
			GameState.current_city_id = location_id
			if CrimeSystem.is_crime_active(location_id):
				CrimeSystem.spawn_guards_debug(CrimeSystem.CRIME_GUARD_COUNT)
		"building":
			var meta_city: String = str(data.metadata.get("city_id", ""))
			if meta_city != "":
				GameState.current_city_id = meta_city
			# Otherwise keep existing city_id (building is inside current city)
		"dungeon", "overworld", _:
			var prev_city: String = GameState.current_city_id
			if prev_city != "":
				_on_leave_city(prev_city)
			GameState.current_city_id = ""


func _on_leave_city(city_id: String) -> void:
	if CrimeSystem.is_crime_active(city_id):
		CrimeSystem.apply_post_crime_rep_on_flee()


func discard_current_map() -> void:
	if _current_map_node != null and is_instance_valid(_current_map_node):
		TurnManager.deactivate()
		_current_map_node.queue_free()
		_current_map_node = null


func get_current_map() -> BaseMap:
	return _current_map_node


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
				   grid_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
