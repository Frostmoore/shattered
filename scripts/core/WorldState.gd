extends Node

var faction_world_flags:     Dictionary = {}
var registered_dungeon_maps: Dictionary = {}  # Fase 11 — Collegio Cartografi
var built_post_stations:     Array      = []  # Fase 11 — Compagnia Ponti
var discovered_safe_houses:  Array      = []  # Fase 11 — Tavola Senza Nome
var opened_player_services:  Dictionary = {}  # Fase 11 — Congregazione Officine
var village_faction_changes: Dictionary = {}  # quest di villaggio
var dungeon_archive:         Dictionary = {}  # Corporazione Camere — dati noti sui dungeon

const POST_STATION_MIN_DIST: int = 30


func reset() -> void:
	faction_world_flags     = {}
	registered_dungeon_maps = {}
	built_post_stations     = []
	discovered_safe_houses  = []
	opened_player_services  = {}
	village_faction_changes = {}
	dungeon_archive         = {}


func serialize() -> Dictionary:
	return {
		"faction_world_flags":     faction_world_flags.duplicate(true),
		"registered_dungeon_maps": registered_dungeon_maps.duplicate(true),
		"built_post_stations":     built_post_stations.duplicate(true),
		"discovered_safe_houses":  discovered_safe_houses.duplicate(true),
		"opened_player_services":  opened_player_services.duplicate(true),
		"village_faction_changes": village_faction_changes.duplicate(true),
		"dungeon_archive":         dungeon_archive.duplicate(true),
	}


func deserialize(data: Dictionary) -> void:
	faction_world_flags     = _get_dict(data, "faction_world_flags")
	registered_dungeon_maps = _get_dict(data, "registered_dungeon_maps")
	built_post_stations     = _get_array(data, "built_post_stations")
	discovered_safe_houses  = _get_array(data, "discovered_safe_houses")
	opened_player_services  = _get_dict(data, "opened_player_services")
	village_faction_changes = _get_dict(data, "village_faction_changes")
	dungeon_archive         = _get_dict(data, "dungeon_archive")


func _get_dict(data: Dictionary, key: String) -> Dictionary:
	var val: Variant = data.get(key, {})
	return val if val is Dictionary else {}


func _get_array(data: Dictionary, key: String) -> Array:
	var val: Variant = data.get(key, [])
	return val if val is Array else []


# ── 11.1 Mappe depositate (Collegio Cartografi) ───────────────────────────────

func register_dungeon_map(map_id: String, floor_n: int) -> void:
	registered_dungeon_maps[map_id] = {
		"map_id":       map_id,
		"floor_n":      floor_n,
		"deposited_by": GameState.character_name,
	}


func has_registered_map(map_id: String) -> bool:
	return registered_dungeon_maps.has(map_id)


func get_registered_map(map_id: String) -> Dictionary:
	var val: Variant = registered_dungeon_maps.get(map_id, {})
	return val if val is Dictionary else {}


# ── 11.2 Stazioni di posta (Compagnia Ponti) ─────────────────────────────────

func add_post_station(map_id: String, pos: Vector2i) -> bool:
	if has_post_station_near(map_id, pos, POST_STATION_MIN_DIST):
		return false
	var uid: String = "pstation_%s_%d_%d" % [map_id, pos.x, pos.y]
	built_post_stations.append({"map_id": map_id, "x": pos.x, "y": pos.y, "uid": uid})
	return true


func get_post_stations_for_map(map_id: String) -> Array:
	var result: Array = []
	for s_v: Variant in built_post_stations:
		var s: Dictionary = s_v as Dictionary
		if str(s.get("map_id", "")) == map_id:
			result.append(s)
	return result


func has_post_station_near(map_id: String, pos: Vector2i, radius: int) -> bool:
	for s_v: Variant in built_post_stations:
		var s: Dictionary = s_v as Dictionary
		if str(s.get("map_id", "")) != map_id:
			continue
		var dist: float = Vector2(float(pos.x), float(pos.y)).distance_to(
				Vector2(float(int(s.get("x", 0))), float(int(s.get("y", 0)))))
		if dist <= float(radius):
			return true
	return false


# ── 11.3 Ambulatorio convenzionato (Congregazione Officine) ──────────────────

func open_service(location_id: String, service_type: String, service_data: Dictionary) -> bool:
	if has_service(location_id, service_type):
		return false
	var loc_v: Variant = opened_player_services.get(location_id, null)
	var loc_dict: Dictionary = loc_v as Dictionary if loc_v is Dictionary else {}
	loc_dict[service_type] = service_data
	opened_player_services[location_id] = loc_dict
	return true


func has_service(location_id: String, service_type: String) -> bool:
	var loc_v: Variant = opened_player_services.get(location_id, null)
	if not loc_v is Dictionary:
		return false
	return (loc_v as Dictionary).has(service_type)


func get_service(location_id: String, service_type: String) -> Dictionary:
	var loc_v: Variant = opened_player_services.get(location_id, null)
	if not loc_v is Dictionary:
		return {}
	var svc_v: Variant = (loc_v as Dictionary).get(service_type, null)
	return svc_v as Dictionary if svc_v is Dictionary else {}


# ── 11.4 Safe house (Tavola Senza Nome) ───────────────────────────────────────

func register_safe_house(map_id: String, pos: Vector2i) -> void:
	for sh_v: Variant in discovered_safe_houses:
		var sh: Dictionary = sh_v as Dictionary
		if str(sh.get("map_id", "")) == map_id \
				and int(sh.get("x", -1)) == pos.x \
				and int(sh.get("y", -1)) == pos.y:
			return
	discovered_safe_houses.append({"map_id": map_id, "x": pos.x, "y": pos.y})
	EventBus.notification_shown.emit(Notification.faction_action(
		LocaleManager.t_or("UI_FACTION_SAFE_HOUSE_FOUND", "Safe house scoperta.")))


func get_safe_houses_for_map(map_id: String) -> Array:
	var result: Array = []
	for sh_v: Variant in discovered_safe_houses:
		var sh: Dictionary = sh_v as Dictionary
		if str(sh.get("map_id", "")) == map_id:
			result.append(sh)
	return result


func is_safe_house_location(map_id: String) -> bool:
	for sh_v: Variant in discovered_safe_houses:
		if str((sh_v as Dictionary).get("map_id", "")) == map_id:
			return true
	return false


# ── 13 Tasse — helper compagnia_ponti ─────────────────────────────────────────

func has_any_post_station() -> bool:
	return built_post_stations.size() > 0
