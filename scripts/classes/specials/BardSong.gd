extends ClassSpecial
# Ballata Ispiratrice: ATK ×1.2 per 5 turni del player. 1×/piano. Costo: 15 MP.
# DEF e DEX boost richiedono StatusEffectManager (Fase F).

const MP_COST:     int = 15
const DURATION:    int = 5

var _turns_left: int = 0


func get_usage_config() -> Dictionary:
	return {"limit": 1, "reset": "floor"}


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d MP richiesti)" % MP_COST)
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	_turns_left = DURATION
	_notify("Ballata Ispiratrice: ATK ×1.2 per %d turni!" % DURATION)
	_combat_log("Il Bardo intona la Ballata Ispiratrice!")


func on_before_player_attack(ctx) -> void:
	if _turns_left <= 0:
		return
	ctx.set("attack_multiplier", float(ctx.get("attack_multiplier")) * 1.2)


func on_turn_end() -> void:
	if _turns_left <= 0:
		return
	_turns_left -= 1
	if _turns_left == 0:
		_combat_log("La Ballata Ispiratrice è finita.")


func on_floor_changed() -> void:
	_turns_left = 0
