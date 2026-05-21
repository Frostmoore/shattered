extends ClassSpecial
# active_key: salva uno snapshot all'inizio del combattimento.
# Q: ripristina snapshot (1 volta per piano). Costo: 25 MP.

const MP_COST: int = 25

var _snapshot:      Dictionary = {}
var _used_this_floor: bool     = false


func on_combat_start() -> void:
	_save_snapshot()


func _save_snapshot() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	_snapshot = {
		"hp":       int(stats.get("hp", 0)),
		"mp":       int(stats.get("mp", 0)),
		"stamina":  int(stats.get("stamina", 0)),
		"position": gs.get("player_position"),
	}


func use_active() -> void:
	if _used_this_floor:
		_notify("Riavvolgimento già usato in questo piano.")
		return
	if _snapshot.is_empty():
		_notify("Nessuno snapshot disponibile.")
		return
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)." % MP_COST)
		return
	_used_this_floor = true
	stats["hp"]      = int(_snapshot.get("hp",      int(stats["hp"])))
	stats["mp"]      = int(_snapshot.get("mp",      int(stats["mp"]))) - MP_COST
	stats["stamina"] = int(_snapshot.get("stamina", int(stats["stamina"])))
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	_notify("Tempo riavvolto! HP/MP/Stamina ripristinati.")


func on_floor_changed() -> void:
	_used_this_floor = false
	_snapshot        = {}
