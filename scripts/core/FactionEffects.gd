extends Node


func apply_join_passive(faction_id: String) -> void:
	var rank: int = FactionMembership.get_rank(faction_id)
	match faction_id:
		"corporazione_camere":   _apply_patente_di_condotta(rank)
		"cacciatori_rogna":      _apply_bestiari_della_rogna(rank)
		"collegio_cartografi":   _apply_senso_cartografico(rank)
		"compagnia_ponti":       _apply_diritto_di_strada(rank)
		"corrieri_sigillo":      _apply_portatore_di_sigillo(rank)
		"congregazione_officine": _apply_arte_della_guarigione(rank)
		"tavola_senza_nome":     _apply_rete_oscura(rank)


func remove_join_passive(faction_id: String) -> void:
	match faction_id:
		"corporazione_camere":   _remove_patente_di_condotta()
		"cacciatori_rogna":      _remove_bestiari_della_rogna()
		"collegio_cartografi":   _remove_senso_cartografico()
		"compagnia_ponti":       _remove_diritto_di_strada()
		"corrieri_sigillo":      _remove_portatore_di_sigillo()
		"congregazione_officine": _remove_arte_della_guarigione()
		"tavola_senza_nome":     _remove_rete_oscura()


func has_active_passive(faction_id: String) -> bool:
	match faction_id:
		"corporazione_camere":   return bool(GameState.faction_passive_flags.get("contract_access", false))
		"cacciatori_rogna":      return bool(GameState.faction_passive_flags.get("rogna_monster_auto_id", false))
		"collegio_cartografi":   return GameState.faction_passive_flags.has("carto_fov_bonus")
		"compagnia_ponti":       return GameState.faction_passive_flags.has("ponti_speed_bonus")
		"corrieri_sigillo":      return GameState.faction_passive_flags.has("corrieri_quest_gold_bonus")
		"congregazione_officine": return GameState.faction_passive_flags.has("officine_potion_discount")
		"tavola_senza_nome":     return bool(GameState.faction_passive_flags.get("tsn_black_market", false))
	return false


# XP multiplier for quest rewards — corporazione_camere Rank 2+.
# Rank 2→+10%, Rank 3→+15%, Rank 4→+20%, Rank 5→+25%
func get_xp_multiplier(context: String = "") -> float:
	if context != "quest":
		return 1.0
	var rank: int = FactionMembership.get_rank("corporazione_camere")
	if rank < 2:
		return 1.0
	return 1.0 + float(rank - 1) * 0.05


# Gold multiplier for quest rewards — corrieri_sigillo Rank 0+.
# +25% on all quest gold rewards (future: scoped to delivery quests only).
func get_gold_multiplier(context: String = "") -> float:
	if context != "quest":
		return 1.0
	if not FactionMembership.is_member("corrieri_sigillo"):
		return 1.0
	return 1.25


# Attack multiplier against enemies of low tier — cacciatori_rogna Rank 2+.
# Returns 1.0 if no bonus applies (no membership, defender not an enemy, tier too high).
func get_attack_mult(defender: Object) -> float:
	var bonus_pct: int = int(GameState.faction_passive_flags.get("rogna_dmg_bonus_pct", 0))
	if bonus_pct <= 0:
		return 1.0
	var raw_id: Variant    = defender.get("enemy_data_id")
	var defender_id: String = str(raw_id) if raw_id != null else ""
	if defender_id == "":
		return 1.0
	var enemy_data: Dictionary = EnemyRegistry.get_enemy_data(defender_id)
	if enemy_data.is_empty():
		return 1.0
	var enemy_tier: int = int(enemy_data.get("tier", 99))
	var max_tier: int   = int(GameState.faction_passive_flags.get("rogna_dmg_max_tier", 0))
	if enemy_tier > max_tier:
		return 1.0
	return 1.0 + float(bonus_pct) / 100.0


func apply_faction_quirk_hooks(_faction_id: String) -> void:
	pass


# ── corporazione_camere ───────────────────────────────────────────────────────

func _apply_patente_di_condotta(rank: int) -> void:
	GameState.faction_passive_flags["contract_access"]        = true
	GameState.faction_passive_flags["dungeon_archive_access"] = true
	if rank >= 2:
		GameState.faction_passive_flags["camere_xp_bonus_pct"] = (rank - 1) * 5
	else:
		GameState.faction_passive_flags.erase("camere_xp_bonus_pct")
	if rank >= 5:
		GameState.faction_passive_flags["elite_contract_access"] = true
	else:
		GameState.faction_passive_flags.erase("elite_contract_access")


func _remove_patente_di_condotta() -> void:
	GameState.faction_passive_flags.erase("contract_access")
	GameState.faction_passive_flags.erase("dungeon_archive_access")
	GameState.faction_passive_flags.erase("camere_xp_bonus_pct")
	GameState.faction_passive_flags.erase("elite_contract_access")


# ── cacciatori_rogna ──────────────────────────────────────────────────────────
# Rank 0-1: auto-id flag only
# Rank 2: +10% dmg vs tier 1        Rank 3: +15% dmg vs tier 1-2
# Rank 4: +20% dmg vs tier 1-2 + improved loot quality
# Rank 5: +25% dmg vs tier 1-2 + improved rewards + advanced infestation id

func _apply_bestiari_della_rogna(rank: int) -> void:
	GameState.faction_passive_flags["rogna_monster_auto_id"] = true
	if rank >= 2:
		var bonus_pct: int = 10 + (rank - 2) * 5
		GameState.faction_passive_flags["rogna_dmg_bonus_pct"] = bonus_pct
		GameState.faction_passive_flags["rogna_dmg_max_tier"]   = 1 if rank == 2 else 2
	else:
		GameState.faction_passive_flags.erase("rogna_dmg_bonus_pct")
		GameState.faction_passive_flags.erase("rogna_dmg_max_tier")
	if rank >= 4:
		GameState.faction_passive_flags["rogna_improved_rewards"] = true
	else:
		GameState.faction_passive_flags.erase("rogna_improved_rewards")
	if rank >= 5:
		GameState.faction_passive_flags["rogna_advanced_id"] = true
	else:
		GameState.faction_passive_flags.erase("rogna_advanced_id")


func _remove_bestiari_della_rogna() -> void:
	GameState.faction_passive_flags.erase("rogna_monster_auto_id")
	GameState.faction_passive_flags.erase("rogna_dmg_bonus_pct")
	GameState.faction_passive_flags.erase("rogna_dmg_max_tier")
	GameState.faction_passive_flags.erase("rogna_improved_rewards")
	GameState.faction_passive_flags.erase("rogna_advanced_id")


# ── collegio_cartografi ───────────────────────────────────────────────────────
# Rank 0: FOV +1 (hook in visibility system — Fase 10)
# Rank 2: map purchase unlocked
# Rank 3: map selling unlocked
# Rank 4: deposited maps become world-persistent (Fase 10)
# Rank 5: advanced maps show known hazards

func _apply_senso_cartografico(rank: int) -> void:
	GameState.faction_passive_flags["carto_fov_bonus"] = 1
	if rank >= 2:
		GameState.faction_passive_flags["carto_map_purchase"] = true
	else:
		GameState.faction_passive_flags.erase("carto_map_purchase")
	if rank >= 3:
		GameState.faction_passive_flags["carto_map_sellable"] = true
	else:
		GameState.faction_passive_flags.erase("carto_map_sellable")
	if rank >= 4:
		GameState.faction_passive_flags["carto_world_persistent"] = true
	else:
		GameState.faction_passive_flags.erase("carto_world_persistent")
	if rank >= 5:
		GameState.faction_passive_flags["carto_advanced_maps"] = true
	else:
		GameState.faction_passive_flags.erase("carto_advanced_maps")


func _remove_senso_cartografico() -> void:
	GameState.faction_passive_flags.erase("carto_fov_bonus")
	GameState.faction_passive_flags.erase("carto_map_purchase")
	GameState.faction_passive_flags.erase("carto_map_sellable")
	GameState.faction_passive_flags.erase("carto_world_persistent")
	GameState.faction_passive_flags.erase("carto_advanced_maps")


# ── compagnia_ponti ───────────────────────────────────────────────────────────
# Rank 0: overworld speed +1 on roads + tolls/ferries -50% (hooks: movement + economy)
# Rank 3: shortcut registry access
# Rank 5: early access to new roads under construction

func _apply_diritto_di_strada(rank: int) -> void:
	GameState.faction_passive_flags["ponti_speed_bonus"]   = 1
	GameState.faction_passive_flags["ponti_toll_discount"] = 50
	if rank >= 3:
		GameState.faction_passive_flags["ponti_shortcuts"] = true
	else:
		GameState.faction_passive_flags.erase("ponti_shortcuts")
	if rank >= 5:
		GameState.faction_passive_flags["ponti_new_roads"] = true
	else:
		GameState.faction_passive_flags.erase("ponti_new_roads")


func _remove_diritto_di_strada() -> void:
	GameState.faction_passive_flags.erase("ponti_speed_bonus")
	GameState.faction_passive_flags.erase("ponti_toll_discount")
	GameState.faction_passive_flags.erase("ponti_shortcuts")
	GameState.faction_passive_flags.erase("ponti_new_roads")


# ── corrieri_sigillo ──────────────────────────────────────────────────────────
# Rank 0: +25% gold on quest rewards (future: scoped to delivery quests)
# Rank 2: passive contracts on entering new locations
# Rank 4: courier mount (speed flag)
# Rank 5: advance world event intelligence

func _apply_portatore_di_sigillo(rank: int) -> void:
	GameState.faction_passive_flags["corrieri_quest_gold_bonus"] = 25
	if rank >= 2:
		GameState.faction_passive_flags["corrieri_passive_contracts"] = true
	else:
		GameState.faction_passive_flags.erase("corrieri_passive_contracts")
	if rank >= 4:
		GameState.faction_passive_flags["corrieri_mount"] = true
	else:
		GameState.faction_passive_flags.erase("corrieri_mount")
	if rank >= 5:
		GameState.faction_passive_flags["corrieri_world_events"] = true
	else:
		GameState.faction_passive_flags.erase("corrieri_world_events")


func _remove_portatore_di_sigillo() -> void:
	GameState.faction_passive_flags.erase("corrieri_quest_gold_bonus")
	GameState.faction_passive_flags.erase("corrieri_passive_contracts")
	GameState.faction_passive_flags.erase("corrieri_mount")
	GameState.faction_passive_flags.erase("corrieri_world_events")


# ── congregazione_officine ────────────────────────────────────────────────────
# Rank 0: -25% on potions/cures from Officine/Sorelle NPC (hook: FactionEconomy Fase 12)
# Rank 2: HP regen +1 efficiency out of combat (hook: rest/turn system)
# Rank 4: access to advanced treatments and diagnosis

func _apply_arte_della_guarigione(rank: int) -> void:
	GameState.faction_passive_flags["officine_potion_discount"] = 25
	if rank >= 2:
		GameState.faction_passive_flags["officine_hp_regen_bonus"] = 1
	else:
		GameState.faction_passive_flags.erase("officine_hp_regen_bonus")
	if rank >= 4:
		GameState.faction_passive_flags["officine_advanced_care"] = true
	else:
		GameState.faction_passive_flags.erase("officine_advanced_care")


func _remove_arte_della_guarigione() -> void:
	GameState.faction_passive_flags.erase("officine_potion_discount")
	GameState.faction_passive_flags.erase("officine_hp_regen_bonus")
	GameState.faction_passive_flags.erase("officine_advanced_care")


# ── tavola_senza_nome ─────────────────────────────────────────────────────────
# Rank 0: black market vendor access
# Rank 2: can pay to reduce active bounty (hook: crime system Fase 11)
# Rank 4: access to high-profile contracts

func _apply_rete_oscura(rank: int) -> void:
	GameState.faction_passive_flags["tsn_black_market"] = true
	if rank >= 2:
		GameState.faction_passive_flags["tsn_bounty_reduction"] = true
	else:
		GameState.faction_passive_flags.erase("tsn_bounty_reduction")
	if rank >= 4:
		GameState.faction_passive_flags["tsn_elite_contracts"] = true
	else:
		GameState.faction_passive_flags.erase("tsn_elite_contracts")


func _remove_rete_oscura() -> void:
	GameState.faction_passive_flags.erase("tsn_black_market")
	GameState.faction_passive_flags.erase("tsn_bounty_reduction")
	GameState.faction_passive_flags.erase("tsn_elite_contracts")
