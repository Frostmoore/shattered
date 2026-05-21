extends ClassSpecial
# passive: ogni kill crea uno scheletro alleato permanente (max INT/4).

func on_enemy_killed(_ctx) -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var attrs: Dictionary = gs.get("effective_attributes")
	var max_skeletons: int = maxi(1, int(attrs.get("int", 0)) / 4)
	var am: Node = _runtime.get_node_or_null("/root/AllyManager") if _runtime else null
	if not am:
		return
	var skeleton_count: int = 0
	for ally: Variant in am.call("get_allies"):
		if is_instance_valid(ally) and str(ally.get("ally_type")) == "skeleton":
			skeleton_count += 1
	if skeleton_count >= max_skeletons:
		return
	am.call("add_ally", {
		"type":         "skeleton",
		"display_name": "Scheletro",
		"hp":           1,
		"max_hp":       1,
		"atk_mult":     0.5,
		"permanent":    true,
		"turns_left":   -1,
	})
	_combat_log("Uno scheletro si unisce all'esercito del Lich!")
