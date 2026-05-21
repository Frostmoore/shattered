extends ClassSpecial
# passive: riflette il 100% dei danni subiti su tutti i nemici in vista.
# Non può morire per il riflesso. Immune ai critici.

func on_after_player_damaged(ctx) -> void:
	var dmg: int = int(ctx.get("final_damage"))
	if dmg <= 0:
		return
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
		_deal_damage(player, en, dmg, true, "magic")
		hit_count += 1
	if hit_count > 0:
		_combat_log("Specchio dell'Abisso: %d riflesso su %d nemici." % [dmg, hit_count])


func on_before_player_damaged(ctx) -> void:
	# Blocca i colpi critici (se il pipeline supporta il flag "critical")
	ctx.set("critical", false)
