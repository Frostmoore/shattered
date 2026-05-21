extends Node

# Ordine: before-hook → effetti stato attaccante → calcolo → pre-apply → applica → after-hook → on_kill


func execute(ctx: Object) -> void:
	var runtime: Node = get_node_or_null("/root/ClassRuntime")
	var sem: Node     = get_node_or_null("/root/StatusEffectManager")

	var player_attacks: bool = (ctx.attacker != null and ctx.attacker.faction == "player")
	var player_defends: bool = (ctx.defender != null and ctx.defender.faction == "player")

	# ── Step 1: hook pre-azione ───────────────────────────────────────────────
	if player_attacks and runtime:
		runtime.on_before_player_attack(ctx)
	elif player_defends and runtime:
		runtime.on_before_player_damaged(ctx)

	if bool(ctx.get("cancelled")):
		return

	# ── Step 2: calcolo danno ─────────────────────────────────────────────────
	# Applica debuff ATK dell'attaccante (es. barbarian_warcry su nemico)
	if not player_attacks and sem:
		for effect: Variant in sem.call("get_effects", ctx.attacker):
			if effect is Dictionary:
				var edata: Dictionary = (effect as Dictionary).get("data", {})
				if edata.has("atk_mult"):
					ctx.set("attack_multiplier",
						float(ctx.get("attack_multiplier")) * float(edata["atk_mult"]))

	# Applica moltiplicatori danno ricevuto sul difensore (es. bounty_hunter_mark)
	if sem:
		for effect: Variant in sem.call("get_effects", ctx.defender):
			if effect is Dictionary:
				var edata: Dictionary = (effect as Dictionary).get("data", {})
				if edata.has("dmg_taken_mult"):
					ctx.set("target_multiplier",
						float(ctx.get("target_multiplier")) * float(edata["dmg_taken_mult"]))

	if bool(ctx.get("instant_kill")):
		ctx.set("final_damage", ctx.defender.max_hp)
	else:
		var atk_level: int  = maxi(1, int(ctx.attacker.get("level"))) if ctx.attacker != null else 1
		var lf: float       = BalanceCombat.level_factor(atk_level)
		var out_mult: float = BalanceCombat.output_multiplier(atk_level)
		var base: float = float(int(ctx.get("base_damage")) + int(ctx.get("flat_bonus"))) \
				* float(ctx.get("attack_multiplier")) * float(ctx.get("target_multiplier"))
		var raw: float
		if bool(ctx.get("ignore_defense")):
			raw = lf * base / GameBalance.DAMAGE_K
		else:
			var eff_def: float = maxf(1.0, float(ctx.defender.defense + int(ctx.get("defense_bonus"))))
			raw = lf * base / eff_def / GameBalance.DAMAGE_K
		raw *= out_mult
		ctx.set("final_damage", maxi(GameBalance.DAMAGE_MIN, floori(raw)))

	# Divinità: override a 1 DOPO tutti i moltiplicatori, solo quando attacca
	if player_attacks and GameState.current_class == "divinita":
		ctx.set("final_damage", 1)

	# ── Step 2.5: hook post-calcolo, pre-applicazione (es. scudo) ────────────
	if player_defends and runtime:
		runtime.on_before_damage_apply(ctx)
	if bool(ctx.get("cancelled")):
		return

	# ── Step 3: applica danno ─────────────────────────────────────────────────
	ctx.defender.take_damage(int(ctx.get("final_damage")))

	# ── Step 4: hook post-azione ──────────────────────────────────────────────
	if player_attacks:
		if runtime:
			runtime.on_after_player_attack(ctx)
		if ctx.defender.is_dead and runtime:
			runtime.on_enemy_killed(ctx)
	elif player_defends and runtime:
		runtime.on_after_player_damaged(ctx)
