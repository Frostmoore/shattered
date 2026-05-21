extends ClassSpecial
# passive_and_active.
# Passiva: su movimento, logga HP dei nemici in raggio 6.
# Attiva Q: prepara schivata automatica del prossimo attacco (1 volta per combattimento).

const SCAN_RANGE: int = 6

var _primed:            bool = false
var _used_this_combat:  bool = false


func get_usage_config() -> Dictionary:
	return {}


func on_player_moved() -> void:
	var map: Node = _get_map()
	if not map:
		return
	var pp: Vector2i = _player_pos()
	var wm: Node = _runtime.get_node_or_null("/root/WorldManager") if _runtime else null
	if not wm:
		return
	var enemies: Array = _runtime.get_node_or_null("/root/TurnManager").get("_enemies") \
		if _runtime else []
	if not enemies:
		return
	var lines: Array[String] = []
	for e: Variant in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node = e as Node
		if bool(en.get("is_dead")):
			continue
		var ep: Vector2i = en.get("grid_position") as Vector2i
		if _manhattan(pp, ep) <= SCAN_RANGE:
			lines.append("%s: %d/%d HP" % [
				str(en.get("display_name")),
				int(en.get("hp")),
				int(en.get("max_hp")),
			])
	if not lines.is_empty():
		_combat_log("Presagio — " + ", ".join(lines))


func use_active() -> void:
	if _used_this_combat:
		_notify("Presagio già usato in questo combattimento.")
		return
	_primed           = true
	_used_this_combat = true
	_notify("Schivata prossimo attacco preparata!")


func on_before_player_damaged(ctx) -> void:
	if not _primed:
		return
	_primed = false
	ctx.set("cancelled", true)
	_combat_log("L'Oracolo aveva previsto l'attacco — schivato!")


func on_combat_start() -> void:
	_used_this_combat = false
	_primed           = false
