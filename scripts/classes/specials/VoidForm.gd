extends ClassSpecial
# passive_and_active.
# Passiva: alla morte rinasce con 1 HP (1/run). Ogni combattimento vinto: +1 WIL permanente (max +20).
# Q: intangibile per 3 turni (immune a tutto, non può attaccare). Costo: 20 MP.

const MP_COST:          int = 20
const INTANGIBLE_TURNS: int = 3
const MAX_WIL_BONUS:    int = 20

var _resurrection_available: bool = true
var _intangible_turns:        int  = 0
var _wil_bonus_accumulated:   int  = 0


func on_before_damage_apply(ctx) -> void:
	if not _resurrection_available:
		return
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("hp", 0)) - int(ctx.get("final_damage")) > 0:
		return
	_resurrection_available = false
	ctx.set("final_damage", 0)
	stats["hp"] = 1
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	_notify("Forma del Vuoto: rinato con 1 HP!")


func on_before_player_damaged(ctx) -> void:
	if _intangible_turns > 0:
		ctx.set("cancelled", true)
		_combat_log("Intangibilità: l'attacco attraversa il Vuoto.")


func on_before_player_attack(ctx) -> void:
	if _intangible_turns > 0:
		ctx.set("cancelled", true)


func use_active() -> void:
	if _intangible_turns > 0:
		_notify("Sei già intangibile.")
		return
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)." % MP_COST)
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	_intangible_turns = INTANGIBLE_TURNS
	_notify("Intangibilità: immune per %d turni!" % INTANGIBLE_TURNS)
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()


func on_turn_end() -> void:
	if _intangible_turns > 0:
		_intangible_turns -= 1
		if _intangible_turns == 0:
			_notify("Intangibilità terminata.")


func on_enemy_killed(_ctx) -> void:
	if _wil_bonus_accumulated >= MAX_WIL_BONUS:
		return
	var gs: Node = _gs()
	if not gs:
		return
	_wil_bonus_accumulated += 1
	gs.base_attributes["wil"] = int(gs.base_attributes["wil"]) + 1
	gs.call("recalculate_derived_stats")
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	_combat_log("Vuoto: +1 WIL permanente (%d/%d)." % [_wil_bonus_accumulated, MAX_WIL_BONUS])
