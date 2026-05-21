extends ClassSpecial
# Lama Incantata: i prossimi 3 attacchi fisici aggiungono INT come danno bonus.
# Costo: 12 MP. Non ha limite per piano, ma le cariche si esauriscono dopo 3 attacchi.

const MP_COST:   int = 12
const CHARGES:   int = 3

var _charges: int = 0


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	if _charges > 0:
		_notify("Lama già incantata (%d cariche rimaste)" % _charges)
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d MP richiesti)" % MP_COST)
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	_charges = CHARGES
	_notify("Lama Incantata: +INT danno per i prossimi %d attacchi!" % CHARGES)
	_combat_log("Lo Spellblade incanta la lama! (%d cariche)" % CHARGES)


func on_before_player_attack(ctx) -> void:
	if _charges <= 0:
		return
	var gs: Node = _gs()
	if not gs:
		return
	var int_stat: int = int(gs.get("effective_attributes").get("int", 0))
	ctx.set("flat_bonus", int(ctx.get("flat_bonus")) + int_stat)


func on_after_player_attack(ctx) -> void:
	if _charges <= 0 or bool(ctx.get("cancelled")):
		return
	_charges -= 1
	_combat_log("Lama magica: carica consumata (%d rimaste)." % _charges)
	if _charges == 0:
		_combat_log("La Lama Incantata si esaurisce.")


func on_floor_changed() -> void:
	_charges = 0
