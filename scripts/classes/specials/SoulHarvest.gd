extends ClassSpecial
# passive_and_active: accumula anime per kill (max INT/2). Q: spendi 1 anima per cura o ATK boost.

const ATK_BOOST_TURNS: int = 3

var _souls:     int = 0
var _atk_boost: int = 0   # turni rimasti di ATK +5


func on_enemy_killed(_ctx) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var attrs: Dictionary = gs.get("effective_attributes")
	var max_souls: int = maxi(1, int(attrs.get("int", 0)) / 2)
	if _souls < max_souls:
		_souls += 1
		_combat_log("Anima raccolta. Totale: %d/%d." % [_souls, max_souls])


func use_active() -> void:
	if _souls <= 0:
		_notify("Nessuna anima disponibile.")
		return
	var gs: Node = _gs()
	if not gs:
		return
	_souls -= 1
	var attrs: Dictionary = gs.get("effective_attributes")
	var wil: int = int(attrs.get("wil", 0))
	var stats: Dictionary = gs.get("player_stats")
	if int(stats.get("hp", 0)) < int(stats.get("max_hp", 0)):
		var heal_amt: int = maxi(1, wil)
		GameState.heal_player(heal_amt)
		_notify("Anima consumata: +%d HP." % heal_amt)
	else:
		_atk_boost = ATK_BOOST_TURNS
		_notify("Anima consumata: ATK +5 per %d turni!" % ATK_BOOST_TURNS)


func on_before_player_attack(ctx) -> void:
	if _atk_boost > 0:
		ctx.set("flat_bonus", int(ctx.get("flat_bonus")) + 5)


func on_turn_end() -> void:
	if _atk_boost > 0:
		_atk_boost -= 1


func get_soul_count() -> int:
	return _souls
