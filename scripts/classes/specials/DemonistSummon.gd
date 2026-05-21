extends ClassSpecial
# Servo Demoniaco: evoca demone temporaneo (ATK×1.5) per WIL/2 turni. 20 MP.

const MP_COST:   int = 20
const DEMON_TYPE: String = "demon"


func get_usage_config() -> Dictionary:
	return {}


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)" % MP_COST)
		return
	var am: Node = _runtime.get_node_or_null("/root/AllyManager") if _runtime else null
	if not am:
		return
	if bool(am.call("has_ally_type", DEMON_TYPE)):
		_notify("Hai già un Servo Demoniaco attivo.")
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()

	var wil: int = int(gs.get("effective_attributes").get("wil", 0))
	var dur: int = maxi(3, wil / 2)
	am.call("add_ally", {
		"type":         DEMON_TYPE,
		"display_name": "Servo Demoniaco",
		"hp":           6,
		"max_hp":       6,
		"atk_mult":     1.5,
		"permanent":    false,
		"turns_left":   dur
	})
