extends ClassSpecial
# Risurrezione: rianima l'ultimo nemico ucciso come alleato per WIL/2 turni. 10 MP.

const MP_COST: int = 10

var _last_kill: Dictionary = {}   # dati dell'ultimo nemico ucciso


func on_enemy_killed(ctx) -> void:
	var defender: Node = ctx.get("defender") as Node
	if not is_instance_valid(defender):
		return
	_last_kill = {
		"name":    str(defender.get("display_name")),
		"attack":  int(defender.get("attack")),
	}


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	if _last_kill.is_empty():
		_notify("Nessun nemico da rianimare.")
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)" % MP_COST)
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()

	var wil: int  = int(gs.get("effective_attributes").get("wil", 0))
	var dur: int  = maxi(2, wil / 2)
	var am: Node  = _runtime.get_node_or_null("/root/AllyManager") if _runtime else null
	if not am:
		return
	var player_atk: int = int(stats.get("attack", 4))
	am.call("add_ally", {
		"type":         "undead",
		"display_name": "Non-Morto (%s)" % _last_kill.get("name", "?"),
		"hp":           8,
		"max_hp":       8,
		"atk_mult":     0.7,
		"permanent":    false,
		"turns_left":   dur
	})
	_last_kill = {}
