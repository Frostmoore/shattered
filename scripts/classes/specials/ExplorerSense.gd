extends ClassSpecial
# passive_and_active.
# Passiva: notifica ingresso piano + stub reveal mappa (FOV system futuro).
# Attiva Q: reveal manuale (stub).
# Passiva combattimento: +25% XP da ogni nemico ucciso nel dungeon.

const XP_BONUS_MULT: float = 0.25


func get_usage_config() -> Dictionary:
	return {}


func on_floor_changed() -> void:
	_reveal_floor()


func use_active() -> void:
	_reveal_floor()


func on_enemy_killed(ctx) -> void:
	var wm: Node = _runtime.get_node_or_null("/root/WorldManager") if _runtime else null
	if not wm:
		return
	var map: Node = wm.call("get_current_map")
	if not map or str(map.get("map_type")) != "dungeon":
		return
	var defender: Node = ctx.get("defender") as Node
	if not defender or not is_instance_valid(defender):
		return
	var base_xp: int = int(defender.get("xp_reward"))
	var bonus: int   = maxi(1, int(float(base_xp) * XP_BONUS_MULT))
	LevelSystem.add_xp(bonus)


func _reveal_floor() -> void:
	var wm: Node = _runtime.get_node_or_null("/root/WorldManager") if _runtime else null
	if not wm:
		return
	var map: Node = wm.call("get_current_map")
	if not map:
		return
	# Chiama reveal_all() se la mappa lo supporta (sistema FOV futuro)
	if map.has_method("reveal_all"):
		map.call("reveal_all")
	_notify("Mappa del piano rivelata!")
