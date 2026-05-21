extends ClassSpecial
# active_toggle: Q cicla None → Orso → Lupo → None.
# Orso: ATK×1.5 per 5 turni (10 MP).  Lupo: schivata +20% per 5 turni (10 MP).

enum Form { NONE, BEAR, WOLF }

const MP_COST:    int = 10
const FORM_TURNS: int = 5

var _form:       Form = Form.NONE
var _turns_left: int  = 0


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var stats: Dictionary = gs.get("player_stats")

	match _form:
		Form.NONE:
			if int(stats.get("mp", 0)) < MP_COST:
				_notify("MP insufficienti (%d richiesti)" % MP_COST)
				return
			stats["mp"] = int(stats["mp"]) - MP_COST
			_form       = Form.BEAR
			_turns_left = FORM_TURNS
			_notify("Forma Orso: ATK ×1.5 per %d turni!" % FORM_TURNS)
			_combat_log("Il Druido assume la Forma dell'Orso.")
		Form.BEAR:
			if int(stats.get("mp", 0)) < MP_COST:
				_notify("MP insufficienti (%d richiesti)" % MP_COST)
				return
			stats["mp"] = int(stats["mp"]) - MP_COST
			_form       = Form.WOLF
			_turns_left = FORM_TURNS
			_notify("Forma Lupo: schivata +20%% per %d turni!" % FORM_TURNS)
			_combat_log("Il Druido assume la Forma del Lupo.")
		Form.WOLF:
			_form       = Form.NONE
			_turns_left = 0
			_notify("Forma normale ripristinata.")
			_combat_log("Il Druido ritorna alla forma umana.")

	var eb: Node = _eb()
	if eb:
		eb.player_stats_changed.emit()


func on_before_player_attack(ctx) -> void:
	if _form == Form.BEAR:
		ctx.set("attack_multiplier", float(ctx.get("attack_multiplier")) * 1.5)


func on_before_player_damaged(ctx) -> void:
	if _form == Form.WOLF:
		if randf() < 0.20:
			ctx.set("cancelled", true)
			_combat_log("Il Lupo schiva l'attacco!")


func on_turn_end() -> void:
	if _form == Form.NONE:
		return
	_turns_left -= 1
	if _turns_left <= 0:
		_form       = Form.NONE
		_turns_left = 0
		_notify("La forma animale è terminata.")
		var eb: Node = _eb()
		if eb:
			eb.player_stats_changed.emit()


func on_floor_changed() -> void:
	_form       = Form.NONE
	_turns_left = 0


# Compatibilità con DebugScreen
func get_wolf_form() -> bool:
	return _form == Form.WOLF


func get_bear_form() -> bool:
	return _form == Form.BEAR


func get_form_turns_left() -> int:
	return _turns_left
