extends ClassSpecial
# passive: esecuzione su nemici HP < 33% player max_hp. Aura: 5 danni/turno ai nemici adiacenti.

const AURA_RANGE:  int = 1
const AURA_DAMAGE: int = 5


func on_before_player_attack(ctx) -> void:
	var defender: Node = ctx.get("defender") as Node
	if not is_instance_valid(defender):
		return
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")
	var threshold: int = int(int(stats.get("max_hp", 0)) * 0.33)
	if int(defender.get("hp")) < threshold:
		ctx.set("instant_kill", true)
		_combat_log("Falce della Morte: esecuzione istantanea!")


func on_turn_end() -> void:
	var map: Node = _get_map()
	if not map:
		return
	var pp: Vector2i = _player_pos()
	var player: Node = _get_player()
	var tm: Node = _runtime.get_node_or_null("/root/TurnManager") if _runtime else null
	if not tm:
		return
	var enemies: Array = tm.get("_enemies") if tm else []
	var hit_count: int = 0
	for e: Variant in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node = e as Node
		if bool(en.get("is_dead")):
			continue
		var ep: Vector2i = en.get("grid_position") as Vector2i
		if _manhattan(pp, ep) <= AURA_RANGE:
			_deal_damage(player, en, AURA_DAMAGE, true, "magic")
			hit_count += 1
	if hit_count > 0:
		_combat_log("Aura Mortale: %d nemici colpiti per %d." % [hit_count, AURA_DAMAGE])
