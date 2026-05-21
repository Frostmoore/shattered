class_name AbilityUseTracker
extends RefCounted

# Traccia cooldown e usi per periodo per l'abilità attiva del player.
# Configurazione da ClassSpecial.get_usage_config():
#   {"limit": 1, "reset": "floor"}      → max N usi per piano
#   {"cooldown_turns": 5}               → cooldown in turni
#   {}                                  → nessun limite

var _limit:        int    = -1   # -1 = illimitato
var _reset:        String = ""   # "floor" | "combat" | "run"
var _cooldown_max: int    = 0
var _uses:         int    = 0
var _cooldown:     int    = 0


func setup(config: Dictionary) -> void:
	_limit        = int(config.get("limit", -1))
	_reset        = str(config.get("reset", ""))
	_cooldown_max = int(config.get("cooldown_turns", 0))


func can_use() -> bool:
	if _cooldown > 0:
		return false
	if _limit >= 0 and _uses >= _limit:
		return false
	return true


func record_use() -> void:
	_uses    += 1
	_cooldown = _cooldown_max


func on_floor_changed() -> void:
	if _reset == "floor":
		_uses = 0
	_cooldown = 0


func on_turn_end() -> void:
	if _cooldown > 0:
		_cooldown -= 1


func get_uses_remaining() -> int:
	if _limit < 0:
		return 999
	return maxi(0, _limit - _uses)


func get_cooldown_remaining() -> int:
	return _cooldown


func describe() -> String:
	if _limit >= 0:
		return "%d/%d usi  (reset: %s)" % [_uses, _limit, _reset]
	if _cooldown_max > 0:
		return "cooldown: %dt rimanenti" % _cooldown
	return "illimitato"
