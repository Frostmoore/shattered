extends ClassSpecial
# Grido di Guerra: tutti i nemici in combattimento ATK -30% per 4 turni.
# Costo: 10 stamina.

const ST_COST:    int = 10
const DURATION:   int = 4
const ATK_MULT: float = 0.70   # -30%


func get_usage_config() -> Dictionary:
	return {}   # nessun limite per piano, costo è la stamina


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("stamina", 0)) < ST_COST:
		_notify("Stamina insufficiente (%d ST richiesti)" % ST_COST)
		return
	stats["stamina"] = int(stats["stamina"]) - ST_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()

	var sem: Node = _runtime.get_node_or_null("/root/StatusEffectManager")
	var tm: Node  = _runtime.get_node_or_null("/root/TurnManager")
	if not sem or not tm:
		return

	var enemies: Array = tm.get("_enemies")
	var count: int = 0
	for enemy: Variant in enemies:
		if is_instance_valid(enemy) and not bool(enemy.get("is_dead")):
			sem.call("apply", enemy, {
				"id": "atk_down", "source": "barbaro",
				"duration_turns": DURATION, "stacking": "refresh",
				"data": {"atk_mult": ATK_MULT}
			})
			count += 1

	_notify("Grido di Guerra: ATK -30%% su %d nemici per %d turni!" % [count, DURATION])
	_combat_log("Il Barbaro lancia il Grido di Guerra!")
