extends ClassSpecial
# Evocatore: apre mini-menu per scegliere il tipo di elementale.
# Fuoco: ATK×1.5 | Acqua: cura +3 HP/turno al player | Terra: HP×3, ATK×0.2.
# Costo: 18 MP. Durata: 5 turni. Max 1 elementale alla volta.

const MP_COST:    int = 18
const ELEM_TURNS: int = 5

const ELEM_DATA: Dictionary = {
	"elemental_fire":  { "display_name": "Elementale di Fuoco",  "hp": 10, "atk_mult": 1.5 },
	"elemental_water": { "display_name": "Elementale d'Acqua",    "hp": 8,  "atk_mult": 0.4 },
	"elemental_earth": { "display_name": "Elementale di Terra",   "hp": 25, "atk_mult": 0.2 },
}


func uses_menu() -> bool:
	return true


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)" % MP_COST)
		var rt: Node = _runtime
		if rt:
			rt.call("cancel_menu")
		return

	var am: Node = _runtime.get_node_or_null("/root/AllyManager") if _runtime else null
	if am:
		for type_id: String in ELEM_DATA:
			if bool(am.call("has_ally_type", type_id)):
				_notify("Hai già un Elementale attivo.")
				var rt: Node = _runtime
				if rt:
					rt.call("cancel_menu")
				return

	var menu: Node = load("res://scripts/ui/SummonerMenuPanel.gd").new()
	menu.call("setup", Callable(self, "_on_menu_choice"))
	if _runtime:
		_runtime.add_child(menu)


func _on_menu_choice(type_id: String) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var data: Dictionary = ELEM_DATA.get(type_id, {}) as Dictionary
	if data.is_empty():
		return
	var stats: Dictionary = gs.get("player_stats")
	stats["mp"] = int(stats["mp"]) - MP_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()

	var am: Node = _runtime.get_node_or_null("/root/AllyManager") if _runtime else null
	if not am:
		return
	am.call("add_ally", {
		"type":         type_id,
		"display_name": str(data["display_name"]),
		"hp":           int(data["hp"]),
		"max_hp":       int(data["hp"]),
		"atk_mult":     float(data["atk_mult"]),
		"permanent":    false,
		"turns_left":   ELEM_TURNS,
	})
	_notify("%s evocato per %d turni!" % [str(data["display_name"]), ELEM_TURNS])


func on_turn_end() -> void:
	var am: Node = _runtime.get_node_or_null("/root/AllyManager") if _runtime else null
	if not am:
		return
	if not bool(am.call("has_ally_type", "elemental_water")):
		return
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("hp", 0)) < int(stats.get("max_hp", 0)):
		GameState.heal_player(3)
		_combat_log("L'Elementale d'Acqua cura 3 HP.")
