extends Node

const MAP_DEPOSIT_GOLD_PER_FLOOR: int = 50
const POST_STATION_BUILD_COST:    int = 100
const AMBULATORIO_OPEN_COST:      int = 200
const BOUNTY_REDUCE_COST:         int = 200


# ── 11.1 Mappe depositate ──────────────────────────────────────────────────────

func try_deposit_map() -> bool:
	if not bool(GameState.faction_passive_flags.get("carto_map_sellable", false)):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_ACTION_NOT_ELIGIBLE",
				"Rango Cartografi insufficiente (richiesto Rank 3).")))
		return false
	var map_id: String = GameState.current_map_id
	if not map_id.contains("_floor_"):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_DEPOSIT_NOT_DUNGEON",
				"Deposita la mappa solo in un dungeon.")))
		return false
	if WorldState.has_registered_map(map_id):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_MAP_ALREADY_DEPOSITED",
				"Mappa già depositata.")))
		return false
	var parts: PackedStringArray = map_id.split("_")
	var floor_n: int = 1
	if parts.size() > 0:
		var last: String = str(parts[parts.size() - 1])
		if last.is_valid_int():
			floor_n = int(last)
	WorldState.register_dungeon_map(map_id, floor_n)
	var gold: int = MAP_DEPOSIT_GOLD_PER_FLOOR * floor_n
	GameState.modify_gold(gold)
	FactionEconomy.collect_deposit_tax(gold)
	EventBus.faction_world_action_completed.emit("deposit_map",
		{"map_id": map_id, "floor_n": floor_n, "gold": gold})
	EventBus.notification_shown.emit(Notification.faction_action(
		LocaleManager.t_or("UI_FACTION_MAP_DEPOSITED",
			"Mappa depositata. +{gold} monete.", {"gold": str(gold)})))
	return true


# ── 11.2 Stazioni di posta ─────────────────────────────────────────────────────

func try_build_post_station() -> bool:
	if not bool(GameState.faction_passive_flags.get("ponti_speed_bonus", false)):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_ACTION_NOT_ELIGIBLE",
				"Rango Compagnia Ponti insufficiente.")))
		return false
	if int(GameState.player_stats.get("gold", 0)) < POST_STATION_BUILD_COST:
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_ACTION_NO_GOLD",
				"Oro insufficiente (servono {amount} monete).", {"amount": str(POST_STATION_BUILD_COST)})))
		return false
	var map_id: String = GameState.current_map_id
	var pos: Vector2i  = GameState.player_position
	if not WorldState.add_post_station(map_id, pos):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_POST_STATION_TOO_CLOSE",
				"Troppo vicino a un'altra stazione di posta.")))
		return false
	GameState.modify_gold(-POST_STATION_BUILD_COST)
	EventBus.faction_world_action_completed.emit("post_station_built",
		{"map_id": map_id, "x": pos.x, "y": pos.y})
	EventBus.notification_shown.emit(Notification.faction_action(
		LocaleManager.t_or("UI_FACTION_POST_STATION_BUILT", "Stazione di Posta costruita.")))
	return true


# ── 11.3 Ambulatorio convenzionato ────────────────────────────────────────────

func try_open_ambulatorio() -> bool:
	if not bool(GameState.faction_passive_flags.get("officine_advanced_care", false)):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_ACTION_NOT_ELIGIBLE",
				"Rango Officine insufficiente (richiesto Rank 4).")))
		return false
	var map_id: String = GameState.current_map_id
	if map_id.contains("_floor_") or map_id == "overworld":
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_AMBUL_ONLY_CITY",
				"Puoi aprire un ambulatorio solo in una città o villaggio.")))
		return false
	if int(GameState.player_stats.get("gold", 0)) < AMBULATORIO_OPEN_COST:
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_ACTION_NO_GOLD",
				"Oro insufficiente (servono {amount} monete).", {"amount": str(AMBULATORIO_OPEN_COST)})))
		return false
	if WorldState.has_service(map_id, "ambulatorio"):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_AMBUL_ALREADY_OPEN",
				"Un ambulatorio è già aperto in questa città.")))
		return false
	var pos: Vector2i = GameState.player_position
	GameState.modify_gold(-AMBULATORIO_OPEN_COST)
	WorldState.open_service(map_id, "ambulatorio", {
		"x": pos.x, "y": pos.y,
		"opened_by": GameState.character_name,
	})
	EventBus.faction_world_action_completed.emit("ambulatorio_opened",
		{"map_id": map_id, "x": pos.x, "y": pos.y})
	EventBus.notification_shown.emit(Notification.faction_action(
		LocaleManager.t_or("UI_FACTION_AMBUL_OPENED", "Ambulatorio aperto.")))
	return true


# ── 11.4 Riduzione taglia (Tavola senza Nome) ────────────────────────────────

func try_reduce_bounty_tsn() -> bool:
	if not bool(GameState.faction_passive_flags.get("tsn_bounty_reduction", false)):
		return false
	var city_id: String = GameState.current_city_id
	if city_id == "" or not CrimeSystem.is_crime_active(city_id):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_NO_BOUNTY", "Non hai taglie attive in questa città.")))
		return false
	if int(GameState.player_stats.get("gold", 0)) < BOUNTY_REDUCE_COST:
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("UI_FACTION_ACTION_NO_GOLD",
				"Oro insufficiente (servono {amount} monete).", {"amount": str(BOUNTY_REDUCE_COST)})))
		return false
	GameState.modify_gold(-BOUNTY_REDUCE_COST)
	CrimeSystem.clear_crime(city_id)
	return true
