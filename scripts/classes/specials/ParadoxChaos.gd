extends ClassSpecial
# passive: ogni turno, un effetto casuale dal pool.

const EFFECTS: Array = [
	"atk_triple", "hp_half", "hp_plus50", "mp_minus30",
	"mp_plus20",  "attr_bump", "aoe_damage", "dodge_prime",
]

var _primed_dodge: bool = false


func on_turn_end() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var effect: String = EFFECTS[randi() % EFFECTS.size()]
	_apply_effect(effect, gs)


func _apply_effect(effect: String, gs: Node) -> void:
	var stats: Dictionary = gs.get("player_stats")
	match effect:
		"atk_triple":
			stats["attack"] = int(stats.get("attack", 0)) * 3
			_combat_log("Paradosso: ATK triplicato questo turno!")
		"hp_half":
			var loss: int = maxi(1, int(stats.get("hp", 0)) / 2)
			GameState.damage_player(loss)
			_combat_log("Paradosso: HP dimezzati!")
		"hp_plus50":
			GameState.heal_player(50)
			_combat_log("Paradosso: +50 HP!")
		"mp_minus30":
			stats["mp"] = maxi(0, int(stats.get("mp", 0)) - 30)
			var eb: Node = _eb()
			if eb:
				eb.player_stats_changed.emit()
			_combat_log("Paradosso: -30 MP!")
		"mp_plus20":
			stats["mp"] = mini(int(stats.get("mp", 0)) + 20, int(stats.get("max_mp", 0)))
			var eb: Node = _eb()
			if eb:
				eb.player_stats_changed.emit()
			_combat_log("Paradosso: +20 MP!")
		"attr_bump":
			var keys: Array = ["str", "dex", "int", "vit", "wil"]
			var key: String = keys[randi() % keys.size()]
			gs.base_attributes[key] = int(gs.base_attributes[key]) + 1
			gs.call("recalculate_derived_stats")
			var eb: Node = _eb()
			if eb:
				eb.player_stats_changed.emit()
			_combat_log("Paradosso: +1 %s!" % key.to_upper())
		"aoe_damage":
			var player: Node = _get_player()
			var tm: Node = _runtime.get_node_or_null("/root/TurnManager") if _runtime else null
			if tm:
				var enemies: Array = tm.get("_enemies") if tm else []
				for e: Variant in enemies:
					if is_instance_valid(e) and not bool((e as Node).get("is_dead")):
						_deal_damage(player, e as Node, 8, true, "magic")
			_combat_log("Paradosso: esplosione caotica — 8 danni a tutti!")
		"dodge_prime":
			_primed_dodge = true
			_combat_log("Paradosso: prossimo attacco schivato automaticamente!")


func on_before_player_damaged(ctx) -> void:
	if _primed_dodge:
		_primed_dodge = false
		ctx.set("cancelled", true)
		_combat_log("Paradosso: attacco schivato!")
