extends ClassSpecial
# Compagno Lupo: alleato permanente. Spawna a inizio dungeon, respawna al piano.

const WOLF_TYPE:  String = "wolf"
const WOLF_HP:    int    = 12
const WOLF_MULT:  float  = 0.5   # 50% dell'ATK del player


func on_floor_changed() -> void:
	var map: Node = _get_map()
	if not map or str(map.get("map_type")) != "dungeon":
		return
	_ensure_wolf()


func on_combat_start() -> void:
	_ensure_wolf()


func _ensure_wolf() -> void:
	var am: Node = _runtime.get_node_or_null("/root/AllyManager") if _runtime else null
	if not am:
		return
	if bool(am.call("has_ally_type", WOLF_TYPE)):
		return   # già presente
	am.call("add_ally", {
		"type":         WOLF_TYPE,
		"display_name": "Lupo del Ranger",
		"hp":           WOLF_HP,
		"max_hp":       WOLF_HP,
		"atk_mult":     WOLF_MULT,
		"permanent":    true,
		"turns_left":   -1
	})
