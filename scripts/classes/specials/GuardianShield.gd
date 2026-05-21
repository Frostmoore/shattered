extends ClassSpecial
# Scudo Divino: assorbe VIT×2 danni. 1×/piano. Costo: 15 MP.

const MP_COST: int = 15

var _shield_hp: int = 0


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
	var vit: int = int(gs.get("effective_attributes").get("vit", 0))
	stats["mp"] = int(stats["mp"]) - MP_COST
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	_shield_hp = vit * 2
	_notify("Scudo Divino attivo: assorbe %d danni!" % _shield_hp)
	_combat_log("Il Custode evoca lo Scudo Divino (%d HP)." % _shield_hp)


func on_before_damage_apply(ctx) -> void:
	if _shield_hp <= 0:
		return
	var dmg: int      = int(ctx.get("final_damage"))
	var absorbed: int = mini(dmg, _shield_hp)
	_shield_hp       -= absorbed
	ctx.set("final_damage", dmg - absorbed)
	if dmg - absorbed <= 0:
		ctx.set("cancelled", true)
	if _shield_hp <= 0:
		_combat_log("Lo Scudo Divino si rompe!")
	else:
		_combat_log("Scudo assorbe %d danni (%d rimasti)." % [absorbed, _shield_hp])


func on_floor_changed() -> void:
	_shield_hp = 0
