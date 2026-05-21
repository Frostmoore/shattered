extends ClassSpecial
# active_key: cicla tra 3 incantesimi (Arcane/Fire/Frost) e lancia quello attivo.
# Ogni incantesimo colpisce il nemico più vicino nel raggio 5.

const SPELLS: Array = ["arcane", "fire", "frost"]
const SPELL_NAMES: Dictionary = {
	"arcane": "Proiettile Arcano",
	"fire":   "Bruciatura",
	"frost":  "Rallentamento",
}
const SPELL_RANGE: int = 5

var _current_spell_idx: int = 0


func use_active() -> void:
	var spell: String = SPELLS[_current_spell_idx]
	_current_spell_idx = (_current_spell_idx + 1) % SPELLS.size()
	var gs: Node = _gs()
	if not gs:
		return
	var attrs: Dictionary = gs.get("effective_attributes")
	var int_a: int = int(attrs.get("int", 0))
	var target: Node = _find_nearest_enemy()
	if not is_instance_valid(target):
		_notify("%s: nessun nemico nel raggio %d." % [SPELL_NAMES.get(spell, spell), SPELL_RANGE])
		return
	var player: Node = _get_player()
	match spell:
		"arcane":
			var dmg: int = 5 + int_a
			_deal_damage(player, target, dmg, true, "magic")
			_notify("%s: %d danni arcanici!" % [SPELL_NAMES[spell], dmg])
		"fire":
			var dmg: int = 3 + int_a / 2
			_deal_damage(player, target, dmg, true, "fire")
			var sem: Node = _runtime.get_node_or_null("/root/StatusEffectManager") if _runtime else null
			if sem:
				sem.call("apply", target, {
					"id": "burning", "source": "player",
					"duration_turns": 3, "stacking": "refresh",
					"data": {"damage_per_turn": 2}
				})
			_notify("%s: %d danni + bruciatura!" % [SPELL_NAMES[spell], dmg])
		"frost":
			var dmg: int = 2 + int_a / 3
			_deal_damage(player, target, dmg, true, "frost")
			var sem: Node = _runtime.get_node_or_null("/root/StatusEffectManager") if _runtime else null
			if sem:
				sem.call("apply", target, {
					"id": "slowed", "source": "player",
					"duration_turns": 2, "stacking": "refresh",
					"data": {}
				})
			_notify("%s: %d danni + rallentamento!" % [SPELL_NAMES[spell], dmg])
	var next_spell: String = SPELLS[_current_spell_idx]
	_combat_log("Prossimo incantesimo: %s." % SPELL_NAMES.get(next_spell, next_spell))


func _find_nearest_enemy() -> Node:
	var map: Node = _get_map()
	if not map:
		return null
	var pp: Vector2i = _player_pos()
	var tm: Node = _runtime.get_node_or_null("/root/TurnManager") if _runtime else null
	if not tm:
		return null
	var enemies: Array = tm.get("_enemies") if tm else []
	var best: Node     = null
	var best_dist: int = SPELL_RANGE + 1
	for e: Variant in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node = e as Node
		if bool(en.get("is_dead")):
			continue
		var ep: Vector2i = en.get("grid_position") as Vector2i
		var dist: int    = _manhattan(pp, ep)
		if dist <= SPELL_RANGE and dist < best_dist:
			best_dist = dist
			best      = en
	return best


func get_current_spell_name() -> String:
	return SPELL_NAMES.get(SPELLS[_current_spell_idx], "?")
