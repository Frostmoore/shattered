extends ClassSpecial
# passive_and_active.
# Passiva: resurrezione 1/run alla morte con 50% HP.
# Q: ATK e DEF ×1.5 per 5 turni. Costo: 20 MP.

const MP_COST:    int = 20
const BLESS_TURNS: int = 5

var _resurrect_available: bool = true
var _bless_turns: int          = 0


func on_before_damage_apply(ctx) -> void:
	if not _resurrect_available:
		return
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	var final_dmg: int = int(ctx.get("final_damage"))
	if int(stats.get("hp", 0)) - final_dmg > 0:
		return
	# Il colpo sarebbe fatale
	_resurrect_available = false
	ctx.set("final_damage", 0)
	var half_hp: int = maxi(1, int(stats.get("max_hp", 0)) / 2)
	stats["hp"] = half_hp
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()
	_notify("Grazia Divina: resuscitato con %d HP!" % half_hp)


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("mp", 0)) < MP_COST:
		_notify("MP insufficienti (%d richiesti)." % MP_COST)
		return
	stats["mp"] = int(stats["mp"]) - MP_COST
	_bless_turns = BLESS_TURNS
	_notify("Benedizione Divina: ATK e DEF ×1.5 per %d turni!" % BLESS_TURNS)
	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()


func on_before_player_attack(ctx) -> void:
	if _bless_turns > 0:
		ctx.set("attack_multiplier", float(ctx.get("attack_multiplier")) * 1.5)


func on_before_player_damaged(ctx) -> void:
	if _bless_turns > 0:
		var incoming: int = int(ctx.get("base_damage"))
		ctx.set("base_damage", maxi(0, incoming - _get_def_bonus()))


func on_turn_end() -> void:
	if _bless_turns > 0:
		_bless_turns -= 1


func on_floor_changed() -> void:
	_resurrect_available = true
	_bless_turns = 0


func _get_def_bonus() -> int:
	var gs: Node = _gs()
	if not gs:
		return 0
	var stats: Dictionary = gs.get("player_stats")
	var base_def: int = int(stats.get("defense", 0))
	return int(base_def * 0.5)  # il 50% extra di DEF
