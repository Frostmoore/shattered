extends ClassSpecial
# Imposizione delle Mani: cura VIT×3 HP. Una volta per piano.

func get_usage_config() -> Dictionary:
	return {"limit": 1, "reset": "floor"}


func use_active() -> void:
	var gs: Node = _gs()
	if not gs:
		return
	var vit:  int = int(gs.get("effective_attributes").get("vit", 0))
	var heal: int = vit * 3
	gs.call("heal_player", heal)
	_notify("Imposizione delle Mani: +%d HP" % heal)
	_combat_log("Il Paladino recupera %d HP." % heal)
