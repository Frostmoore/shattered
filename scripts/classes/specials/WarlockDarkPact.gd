extends ClassSpecial
# Patto Oscuro: consuma 5 HP → 5 MP.
# Passivo: +5% ATK per ogni 10% HP mancante (sempre attivo, calcolato ad ogni attacco).

const HP_COST: int = 5
const MP_GAIN: int = 5


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	var hp: int = int(stats.get("hp", 0))
	if hp <= HP_COST:
		_notify("HP insufficienti per il Patto (min %d HP)" % (HP_COST + 1))
		return
	stats["hp"] = hp - HP_COST
	var mp: int     = int(stats.get("mp", 0))
	var max_mp: int = int(stats.get("max_mp", 1))
	stats["mp"] = mini(mp + MP_GAIN, max_mp)
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	var max_hp: int = int(stats.get("max_hp", 1))
	var miss_pct: float = 1.0 - float(int(stats["hp"])) / float(max_hp)
	var bonus_pct: float = int(miss_pct * 10.0) * 5.0
	_notify("Patto Oscuro: -%d HP +%d MP. ATK +%.0f%%" % [HP_COST, MP_GAIN, bonus_pct])
	_combat_log("Lo Stregone attiva il Patto Oscuro.")


func on_before_player_attack(ctx) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	var hp: int     = int(stats.get("hp",     1))
	var max_hp: int = int(stats.get("max_hp", 1))
	if max_hp <= 0:
		return
	var miss_pct: float  = 1.0 - float(hp) / float(max_hp)
	var bonus_pct: float = int(miss_pct * 10.0) * 0.05   # 5% per 10% HP mancante
	if bonus_pct > 0.0:
		ctx.set("attack_multiplier", float(ctx.get("attack_multiplier")) * (1.0 + bonus_pct))
