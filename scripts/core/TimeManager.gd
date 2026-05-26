extends Node

const WORLD_TICK_INTERVAL: int = 30

const BASE_YEAR:      int = 472
const DAYS_PER_MONTH: int = 30
const DAYS_PER_YEAR:  int = 360
const MONTH_KEYS: Array[String] = [
	"TIME_MONTH_1",  "TIME_MONTH_2",  "TIME_MONTH_3",  "TIME_MONTH_4",
	"TIME_MONTH_5",  "TIME_MONTH_6",  "TIME_MONTH_7",  "TIME_MONTH_8",
	"TIME_MONTH_9",  "TIME_MONTH_10", "TIME_MONTH_11", "TIME_MONTH_12",
]


func advance(minutes: int) -> void:
	var prev_slot:    String = get_slot()
	var prev_abs_day: int    = get_absolute_day()

	GameState.total_minutes += minutes

	if get_absolute_day() != prev_abs_day:
		EventBus.day_changed.emit(get_absolute_day())

	EventBus.time_advanced.emit(minutes)

	if get_slot() != prev_slot:
		EventBus.day_slot_changed.emit(get_slot())

	var ticks: int = minutes / WORLD_TICK_INTERVAL
	if ticks > 0:
		EventBus.world_ticked.emit(ticks, WORLD_TICK_INTERVAL)


func get_hour() -> int:   return GameState.world_time / 60
func get_minute() -> int: return GameState.world_time % 60


func get_absolute_day() -> int:  return GameState.total_minutes / 1440
func get_year() -> int:          return BASE_YEAR + get_absolute_day() / DAYS_PER_YEAR
func get_month_index() -> int:   return (get_absolute_day() % DAYS_PER_YEAR) / DAYS_PER_MONTH
func get_day_of_month() -> int:  return (get_absolute_day() % DAYS_PER_MONTH) + 1
func get_month_name() -> String: return LocaleManager.t(MONTH_KEYS[get_month_index()])


func format_date() -> String:
	return LocaleManager.t("TIME_FORMAT_DATE", {
		"day":   str(get_day_of_month()),
		"month": get_month_name(),
		"year":  str(get_year()),
	})


func format_time() -> String:
	return LocaleManager.t("TIME_FORMAT_FULL", {
		"date":  format_date(),
		"phase": _display_phase(),
	})


func format_date_from(minutes: int) -> String:
	var abs_day: int = minutes / 1440
	var year: int    = BASE_YEAR + abs_day / DAYS_PER_YEAR
	var m_idx: int   = (abs_day % DAYS_PER_YEAR) / DAYS_PER_MONTH
	var day_m: int   = (abs_day % DAYS_PER_MONTH) + 1
	return LocaleManager.t("TIME_FORMAT_DATE", {
		"day":   str(day_m),
		"month": LocaleManager.t(MONTH_KEYS[m_idx]),
		"year":  str(year),
	})


func format_time_from(minutes: int) -> String:
	var h: int = (minutes % 1440) / 60
	var slot: String
	if   h >= 5  and h < 8:  slot = "alba"
	elif h >= 8  and h < 12: slot = "mattina"
	elif h >= 12 and h < 18: slot = "pomeriggio"
	elif h >= 18 and h < 21: slot = "sera"
	else:                     slot = "notte"
	var phase: String
	match slot:
		"alba":                  phase = LocaleManager.t("TIME_PHASE_ALBA")
		"mattina", "pomeriggio": phase = LocaleManager.t("TIME_PHASE_GIORNO")
		"sera":                  phase = LocaleManager.t("TIME_PHASE_TRAMONTO")
		_:                       phase = LocaleManager.t("TIME_PHASE_NOTTE")
	return LocaleManager.t("TIME_FORMAT_FULL", {
		"date":  format_date_from(minutes),
		"phase": phase,
	})


func get_slot() -> String:
	var h: int = get_hour()
	if h >= 5  and h < 8:  return "alba"
	if h >= 8  and h < 12: return "mattina"
	if h >= 12 and h < 18: return "pomeriggio"
	if h >= 18 and h < 21: return "sera"
	return "notte"


func is_night() -> bool: return get_slot() == "notte"


func _display_phase() -> String:
	match get_slot():
		"alba":                  return LocaleManager.t("TIME_PHASE_ALBA")
		"mattina", "pomeriggio": return LocaleManager.t("TIME_PHASE_GIORNO")
		"sera":                  return LocaleManager.t("TIME_PHASE_TRAMONTO")
		_:                       return LocaleManager.t("TIME_PHASE_NOTTE")


func get_vision_modifier(map_type: String) -> float:
	if is_night() and map_type in ["village", "city", "overworld"]:
		return 0.6
	return 1.0


func get_action_cost(map_type: String, action: int) -> int:
	# action: 0=MOVE 1=ATTACK 2=USE_ITEM 3=INTERACT 4=WAIT
	var table: Dictionary = {
		"building": [1, 1, 1, 1, 60],
		"village":  [1, 1, 1, 1, 60],
		"city":     [2, 2, 1, 1, 60],
		"dungeon":  [3, 3, 2, 0, 30],
		"ruin":     [3, 3, 2, 0, 30],
		"overworld":[0, 5, 5, 5, 60],
	}
	var costs: Array = table.get(map_type, [2, 2, 1, 1, 60])
	return costs[action] if action < costs.size() else 2
