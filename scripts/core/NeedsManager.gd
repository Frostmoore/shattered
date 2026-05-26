extends Node

# ── Accumulatori danno ───────────────────────────────────────────────────────

var _food_zero_acc:         float = 0.0   # minuti con food = 0 (trigger malnutrizione dopo 120 min)
var _water_zero_acc:        float = 0.0   # minuti con water = 0 (trigger disidratazione dopo 60 min)
var _exh_dmg_acc:           float = 0.0   # accumulo danno exhaustion grave (5 HP ogni 30 min)
var _disease_dmg_acc:       Dictionary = {}  # disease_id → accumulated minutes
var _cure_time_acc:         Dictionary = {}  # disease_id → accumulated minutes for time_elapsed cure
var _nat_recovery_acc:      Dictionary = {}  # disease_id → accumulated minutes for natural recovery

# ── Tracker insonnia_cronica ─────────────────────────────────────────────────

var _high_exhaustion_count: int  = 0      # volte che exhaustion ha superato 90 (edge)
var _was_above_90:          bool = false  # edge detection

# ── Tracker notifiche ────────────────────────────────────────────────────────

var _prev_states: Dictionary = { "food": "ok", "water": "ok", "exhaustion": "ok" }
var _prev_temp_zone:      int    = 0      # zona temperatura precedente (0–3)
var _prev_temp_direction: String = "none" # "none" | "cold" | "hot"
var _last_meal_hint:      int    = -1     # −1=nessuno, 0=colazione, 1=pranzo, 2=cena

# ── Debug ────────────────────────────────────────────────────────────────────

var _debug_biome_target: float = 0.0  # override target temperatura per test (0 = disattivo)


# ── API pubblica ─────────────────────────────────────────────────────────────

func tick(minutes: int, context: Dictionary = {}) -> void:
	var remaining := float(minutes)
	while remaining > 0.0:
		var step := minf(remaining, 60.0)
		_tick_step(step, context)
		remaining -= step
	_update_modifiers()
	_check_collapse()
	_check_state_transitions()
	_check_meal_hints()
	EventBus.needs_changed.emit()
	EventBus.player_stats_changed.emit()


func consume(changes: Dictionary) -> void:
	# changes: { "food": +30, "water": +20, "exhaustion": -10, "temperature": +15 }
	if changes.has("food"):
		GameState.food        = clampf(GameState.food        + float(changes["food"]),        0.0, 100.0)
	if changes.has("water"):
		GameState.water       = clampf(GameState.water       + float(changes["water"]),       0.0, 100.0)
	if changes.has("exhaustion"):
		GameState.exhaustion  = clampf(GameState.exhaustion  + float(changes["exhaustion"]),  0.0, 100.0)
	if changes.has("temperature"):
		GameState.temperature = clampf(GameState.temperature + float(changes["temperature"]), -100.0, 100.0)
	_update_modifiers()
	_check_state_transitions()
	EventBus.needs_changed.emit()


func rest(rest_type: String) -> void:
	match rest_type:
		"save_point":
			GameState.exhaustion = maxf(0.0, GameState.exhaustion - 30.0)
		"inn":
			GameState.exhaustion  = 0.0
			GameState.temperature = 0.0
		"camp":
			GameState.exhaustion  = maxf(0.0, GameState.exhaustion - 50.0)
			GameState.temperature = 0.0
	_check_rest_cures(rest_type)
	_update_modifiers()
	EventBus.needs_changed.emit()


func add_disease(disease_id: String) -> void:
	for d: Variant in GameState.active_diseases:
		if (d as Dictionary).get("id") == disease_id:
			return
	GameState.active_diseases.append({ "id": disease_id, "stage_index": 0, "elapsed_minutes": 0.0 })
	var def: Dictionary = DiseaseRegistry.get_def(disease_id)
	EventBus.disease_acquired.emit(disease_id, str(def.get("name", disease_id)))
	_update_modifiers()
	EventBus.needs_changed.emit()


func cure_disease(disease_id: String) -> void:
	GameState.active_diseases = GameState.active_diseases.filter(
		func(d: Variant) -> bool: return (d as Dictionary).get("id") != disease_id
	)
	_disease_dmg_acc.erase(disease_id)
	_cure_time_acc.erase(disease_id)
	_nat_recovery_acc.erase(disease_id)
	_update_modifiers()
	EventBus.disease_cured.emit(disease_id)
	EventBus.needs_changed.emit()


func cure_all_diseases() -> void:
	var ids: Array[String] = []
	for d: Variant in GameState.active_diseases:
		ids.append(str((d as Dictionary).get("id", "")))
	GameState.active_diseases.clear()
	_disease_dmg_acc.clear()
	_cure_time_acc.clear()
	_nat_recovery_acc.clear()
	_update_modifiers()
	for id: String in ids:
		EventBus.disease_cured.emit(id)
	EventBus.needs_changed.emit()


func cure_diseases_matching_item(item_id: String) -> void:
	var item_data: Dictionary = ItemDB.get_item(item_id)
	var item_tags: Array = item_data.get("tags", []) as Array
	var to_cure: Array[String] = []
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary = d as Dictionary
		var did: String = str(entry.get("id", ""))
		var def: Dictionary = DiseaseRegistry.get_def(did)
		if def.is_empty():
			continue
		for trigger: Variant in def.get("cure_triggers", []) as Array:
			var trig: Dictionary = trigger as Dictionary
			match str(trig.get("type", "")):
				"item_use":
					if str(trig.get("item_id", "")) == item_id and did not in to_cure:
						to_cure.append(did)
				"item_tag":
					if str(trig.get("item_tag", "")) in item_tags and did not in to_cure:
						to_cure.append(did)
	for did: String in to_cure:
		cure_disease(did)


func rebuild_modifiers() -> void:
	_update_modifiers()
	_check_state_transitions()
	EventBus.needs_changed.emit()


# ── Tick interno ─────────────────────────────────────────────────────────────

func _tick_step(minutes: float, context: Dictionary) -> void:
	var rates := _calculate_rates(context)
	GameState.food       = maxf(0.0,   GameState.food       - rates["food"]       * minutes)
	GameState.water      = maxf(0.0,   GameState.water      - rates["water"]      * minutes)
	GameState.exhaustion = minf(100.0, GameState.exhaustion + rates["exhaustion"] * minutes)

	# Temperatura: modello a equilibrio — si avvicina al target, non varia a rate fisso.
	# In FASE 1 il target è sempre 0; testabile via debug con _debug_biome_target.
	var target: float = _get_temperature_target(context)
	var k:      float = _get_approach_rate(context)
	GameState.temperature = lerpf(GameState.temperature, target, k * minutes)
	GameState.temperature = clampf(GameState.temperature, -100.0, 100.0)

	_tick_diseases(minutes)
	_check_disease_triggers(minutes)


func _calculate_rates(context: Dictionary) -> Dictionary:
	var map_type: String = str(context.get("map_type", "building"))
	var activity: String = str(context.get("activity", "explore"))

	var base: Dictionary
	if activity == "sleep":
		base = { "food": 0.003, "water": 0.005, "exhaustion": 0.0 }
	else:
		match map_type:
			"overworld":          base = { "food": 0.070, "water": 0.110, "exhaustion": 0.030 }
			"dungeon", "ruin", \
			"encounter":          base = { "food": 0.030, "water": 0.045, "exhaustion": 0.025 }
			"village", "city":    base = { "food": 0.008, "water": 0.012, "exhaustion": 0.010 }
			_:                    base = { "food": 0.004, "water": 0.006, "exhaustion": 0.005 }

	var fd: float = GameState.needs_modifiers.get("food_drain_mult_sum", 0.0)
	var eg: float = GameState.needs_modifiers.get("exhaustion_gain_mult_sum", 0.0)
	return {
		"food":       float(base["food"])       * (1.0 + fd),
		"water":      float(base["water"]),
		"exhaustion": float(base["exhaustion"]) * (1.0 + eg),
	}


func _get_temperature_target(context: Dictionary) -> float:
	if _debug_biome_target != 0.0:
		return _debug_biome_target
	# FASE 1: temperatura non cambia automaticamente — target sempre 0.
	# FASE 2: leggerà context["biome"] dall'Overworld System.
	return 0.0


func _get_approach_rate(context: Dictionary) -> float:
	var map_type: String = str(context.get("map_type", "building"))
	match map_type:
		"building":             return 0.012
		"village", "city":      return 0.010
		"dungeon", "ruin":      return 0.008
		"overworld":            return 0.005
		_:                      return 0.010


# ── Malattie ─────────────────────────────────────────────────────────────────

func _tick_diseases(minutes: float) -> void:
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary = d as Dictionary
		var elapsed: float = float(entry.get("elapsed_minutes", 0.0)) + minutes
		entry["elapsed_minutes"] = elapsed

		var did: String    = str(entry.get("id", ""))
		var stage_idx: int = int(entry.get("stage_index", 0))
		var def: Dictionary = DiseaseRegistry.get_def(did)   # {} in FASE 1
		var stages: Array   = def.get("stages", []) as Array
		if stage_idx >= stages.size():
			continue

		# Controlla advance_triggers per avanzare di stage
		var stage: Dictionary      = stages[stage_idx] as Dictionary
		var triggers: Array        = stage.get("advance_triggers", []) as Array
		var should_advance: bool   = false
		for tr: Variant in triggers:
			if _eval_advance_trigger(tr as Dictionary, elapsed):
				should_advance = true
				break
		if should_advance and stage_idx + 1 < stages.size():
			entry["stage_index"] = stage_idx + 1
			entry["elapsed_minutes"] = 0.0
			var next_stage: Dictionary = stages[stage_idx + 1] as Dictionary
			var label: String = str(next_stage.get("label", str(stage_idx + 1)))
			EventBus.disease_progressed.emit(did, str(def.get("name", did)), label)


func _check_rest_cures(rest_type: String) -> void:
	var to_cure: Array[String] = []
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary = d as Dictionary
		var did: String = str(entry.get("id", ""))
		var def: Dictionary = DiseaseRegistry.get_def(did)
		if def.is_empty():
			continue
		for trigger: Variant in def.get("cure_triggers", []) as Array:
			var trig: Dictionary = trigger as Dictionary
			if str(trig.get("type", "")) == "rest_type" and str(trig.get("rest_type", "")) == rest_type:
				if did not in to_cure:
					to_cure.append(did)
	for did: String in to_cure:
		cure_disease(did)


func _check_time_cure_triggers(minutes: float) -> void:
	var to_cure: Array[String] = []
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary = d as Dictionary
		var did: String = str(entry.get("id", ""))
		var def: Dictionary = DiseaseRegistry.get_def(did)
		if def.is_empty():
			continue
		for trigger: Variant in def.get("cure_triggers", []) as Array:
			var trig: Dictionary = trigger as Dictionary
			if str(trig.get("type", "")) != "time_elapsed":
				continue
			_cure_time_acc[did] = float(_cure_time_acc.get(did, 0.0)) + minutes
			if float(_cure_time_acc[did]) >= float(trig.get("minutes", 9999999)):
				_cure_time_acc.erase(did)
				if did not in to_cure:
					to_cure.append(did)
			break
	for did: String in to_cure:
		cure_disease(did)


func _check_need_cure_triggers() -> void:
	var to_cure: Array[String] = []
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary = d as Dictionary
		var did: String = str(entry.get("id", ""))
		var def: Dictionary = DiseaseRegistry.get_def(did)
		if def.is_empty():
			continue
		for trigger: Variant in def.get("cure_triggers", []) as Array:
			var trig: Dictionary = trigger as Dictionary
			if str(trig.get("type", "")) != "need_above":
				continue
			var need: String = str(trig.get("need", ""))
			var threshold: float = float(trig.get("threshold", 100.0))
			var val: float
			match need:
				"food":  val = GameState.food
				"water": val = GameState.water
				_: continue
			if val >= threshold and did not in to_cure:
				to_cure.append(did)
	for did: String in to_cure:
		cure_disease(did)


func _check_natural_recovery(minutes: float) -> void:
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary = d as Dictionary
		var did: String = str(entry.get("id", ""))
		var stage_idx: int = int(entry.get("stage_index", 0))
		if stage_idx == 0:
			continue
		var def: Dictionary = DiseaseRegistry.get_def(did)
		if def.is_empty():
			continue
		var recovery: Dictionary = def.get("natural_recovery", {}) as Dictionary
		if recovery.is_empty():
			_nat_recovery_acc.erase(did)
			continue
		if not _eval_recovery_condition(recovery):
			_nat_recovery_acc.erase(did)
			continue
		_nat_recovery_acc[did] = float(_nat_recovery_acc.get(did, 0.0)) + minutes
		var needed: float = float(recovery.get("minutes_per_stage", 9999999.0))
		if float(_nat_recovery_acc[did]) >= needed:
			_nat_recovery_acc[did] = 0.0
			entry["stage_index"] = stage_idx - 1
			var stages_arr: Array = def.get("stages", []) as Array
			var new_label: String = str((stages_arr[stage_idx - 1] as Dictionary).get("label", str(stage_idx - 1)))
			EventBus.disease_regressed.emit(did, str(def.get("name", did)), new_label)


func _eval_recovery_condition(recovery: Dictionary) -> bool:
	match str(recovery.get("condition", "")):
		"need_above":
			var need: String = str(recovery.get("need", ""))
			var threshold: float = float(recovery.get("threshold", 100.0))
			match need:
				"food":  return GameState.food  >= threshold
				"water": return GameState.water >= threshold
		"exhaustion_below":
			return GameState.exhaustion <= float(recovery.get("threshold", 0.0))
		"always":
			return true
	return false


func _eval_advance_trigger(tr: Dictionary, elapsed: float) -> bool:
	match str(tr.get("type", "")):
		"time_elapsed":
			return elapsed >= float(tr.get("minutes", 0))
		"needs_zero":
			var need: String = str(tr.get("need", ""))
			var min_min: float = float(tr.get("min_minutes", 0))
			match need:
				"food":
					return GameState.food <= 0.0 and _food_zero_acc >= min_min
				"water":
					return GameState.water <= 0.0 and _water_zero_acc >= min_min
		"exhaustion_above":
			return GameState.exhaustion >= float(tr.get("threshold", 100))
	return false


func _check_disease_triggers(minutes: float) -> void:
	# ── food → malnutrizione dopo 120 min a zero ───────────────────────────
	if GameState.food <= 0.0:
		_food_zero_acc += minutes
		if _food_zero_acc >= 120.0:
			add_disease("malnutrizione")
	else:
		_food_zero_acc = 0.0

	# ── water → disidratazione_grave dopo 60 min a zero ────────────────────
	if GameState.water <= 0.0:
		_water_zero_acc += minutes
		if _water_zero_acc >= 60.0:
			add_disease("disidratazione_grave")
	else:
		_water_zero_acc = 0.0

	# ── exhaustion → insonnia_cronica (edge detection) ─────────────────────
	var over_90: bool = GameState.exhaustion >= 90.0
	if over_90 and not _was_above_90:
		_high_exhaustion_count += 1
		if _high_exhaustion_count >= 3:
			add_disease("insonnia_cronica")
	_was_above_90 = over_90 if GameState.exhaustion >= 70.0 else false

	# ── temperature → ipotermia / ipertermia ───────────────────────────────
	if GameState.temperature <= -75.0:
		add_disease("ipotermia")
	if GameState.temperature >= 85.0:
		add_disease("ipertermia")

	# ── danno periodico per ogni malattia attiva ────────────────────────────
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary  = d as Dictionary
		var did: String        = str(entry.get("id", ""))
		var stage_idx: int     = int(entry.get("stage_index", 0))
		var def: Dictionary    = DiseaseRegistry.get_def(did)
		var stages: Array      = def.get("stages", []) as Array
		if stage_idx >= stages.size():
			_disease_dmg_acc.erase(did)
			continue
		var dmg: int = int((stages[stage_idx] as Dictionary).get("damage_per_30min", 0))
		if dmg <= 0:
			_disease_dmg_acc.erase(did)
			continue
		_disease_dmg_acc[did] = float(_disease_dmg_acc.get(did, 0.0)) + minutes
		while float(_disease_dmg_acc[did]) >= 30.0:
			EventBus.player_took_needs_damage.emit(did, dmg)
			_disease_dmg_acc[did] = float(_disease_dmg_acc[did]) - 30.0

	# ── danno exhaustion grave (91+): −5 HP ogni 30 min ────────────────────
	if GameState.exhaustion >= 91.0:
		_exh_dmg_acc += minutes
		while _exh_dmg_acc >= 30.0:
			EventBus.player_took_needs_damage.emit("exhaustion", 5)
			_exh_dmg_acc -= 30.0
	else:
		_exh_dmg_acc = 0.0

	# ── cura automatica per tempo, bisogni e recupero naturale ─────────────
	_check_time_cure_triggers(minutes)
	_check_need_cure_triggers()
	_check_natural_recovery(minutes)


# ── Modificatori ─────────────────────────────────────────────────────────────

func _update_modifiers() -> void:
	var atk:    float = 0.0
	var dmg:    float = 0.0
	var cost:   float = 0.0
	var int_m:  float = 0.0
	var wil_m:  float = 0.0
	var fd_sum: float = 0.0
	var eg_sum: float = 0.0
	var acc:    float = 0.0   # accuracy_penalty flat
	var vis:    int   = 0     # vision_penalty

	# ── food ──────────────────────────────────────────────────────────────
	var f: float = GameState.food
	if f <= 24.0:
		wil_m += -0.10; atk += -0.10; dmg += 0.10
	elif f <= 49.0:
		wil_m += -0.05

	# ── water ─────────────────────────────────────────────────────────────
	var w: float = GameState.water
	if w <= 24.0:
		atk += -0.20; dmg += 0.15; cost += 0.5
	elif w <= 49.0:
		atk += -0.10; dmg += 0.10

	# ── exhaustion ────────────────────────────────────────────────────────
	var e: float = GameState.exhaustion
	if e >= 91.0:
		atk += -0.30; dmg += 0.20; cost += 0.5
	elif e >= 76.0:
		atk += -0.15; dmg += 0.15; int_m += -0.10; wil_m += -0.10
	elif e >= 56.0:
		atk += -0.05; dmg += 0.05; int_m += -0.10; wil_m += -0.10
	elif e >= 31.0:
		int_m += -0.05; wil_m += -0.05

	# ── temperatura (zone transiensi) ──────────────────────────────────────
	var t: float     = GameState.temperature
	var zone: int    = 0
	var direction: String = "none"
	if t < -25.0:
		direction = "cold"
		if   t <= -75.0:  zone = 3
		elif t <= -50.0:  zone = 2
		else:             zone = 1
	elif t > 25.0:
		direction = "hot"
		if   t >= 57.0:  zone = 3
		elif t >= 29.0:  zone = 2
		else:            zone = 1

	match zone:
		1: wil_m += -0.05; cost += 0.10
		2: atk   += -0.10; dmg  += 0.10; cost += 0.20
		3: atk   += -0.20; dmg  += 0.15; cost += 0.50

	if zone != _prev_temp_zone or (zone > 0 and direction != _prev_temp_direction):
		if zone > 0:
			EventBus.temperature_zone_changed.emit(zone, direction)
		_prev_temp_zone      = zone
		_prev_temp_direction = direction

	# ── malattie attive ────────────────────────────────────────────────────
	for d: Variant in GameState.active_diseases:
		var entry: Dictionary   = d as Dictionary
		var did: String         = str(entry.get("id", ""))
		var stage_idx: int      = int(entry.get("stage_index", 0))
		var def: Dictionary     = DiseaseRegistry.get_def(did)
		var stages: Array       = def.get("stages", []) as Array
		if stage_idx >= stages.size():
			continue
		var malus: Dictionary = (stages[stage_idx] as Dictionary).get("malus", {}) as Dictionary
		atk    += float(malus.get("atk_mult",            0.0))
		dmg    += float(malus.get("dmg_taken_mult",       0.0))
		cost   += float(malus.get("action_cost_mult",     0.0))
		int_m  += float(malus.get("int_mult",             0.0))
		wil_m  += float(malus.get("wil_mult",             0.0))
		fd_sum += float(malus.get("food_drain_mult",      0.0))
		eg_sum += float(malus.get("exhaustion_gain_mult", 0.0))
		acc    += float(malus.get("accuracy_penalty",     0.0))
		vis    += int(malus.get("vision_penalty",        0))

	# ── cap e scrittura ────────────────────────────────────────────────────
	GameState.needs_modifiers = {
		"atk_mult":                maxf(atk,   -0.65),
		"dmg_taken_mult":          minf(dmg,    0.65),
		"action_cost_mult":        minf(cost,   2.0),
		"int_mult":                int_m,
		"wil_mult":                wil_m,
		"accuracy_penalty":        acc,
		"vision_penalty":          vis,
		"food_drain_mult_sum":     minf(fd_sum, 2.0),
		"exhaustion_gain_mult_sum":minf(eg_sum, 1.5),
		"temp_zone":               zone,
		"temp_direction":          direction,
	}
	# Ricalcola max_mp con int_mult/wil_mult aggiornati
	GameState.recalculate_derived_stats()


# ── Notifiche e collasso ──────────────────────────────────────────────────────

func _check_state_transitions() -> void:
	_check_transition("food",       _get_need_state("food"))
	_check_transition("water",      _get_need_state("water"))
	_check_transition("exhaustion", _get_need_state("exhaustion"))


func _check_transition(need: String, new_state: String) -> void:
	var old: String = str(_prev_states.get(need, "ok"))
	if new_state == old:
		return
	_prev_states[need] = new_state
	match new_state:
		"warning":  EventBus.need_warning.emit(need)
		"critical": EventBus.need_critical.emit(need)
		"depleted": EventBus.need_depleted.emit(need)


func _get_need_state(need: String) -> String:
	match need:
		"food":
			if GameState.food <= 0.0:       return "depleted"
			if GameState.food <= 24.0:      return "critical"
			if GameState.food <= 49.0:      return "warning"
		"water":
			if GameState.water <= 0.0:      return "depleted"
			if GameState.water <= 24.0:     return "critical"
			if GameState.water <= 49.0:     return "warning"
		"exhaustion":
			if GameState.exhaustion >= 100.0: return "depleted"
			if GameState.exhaustion >= 76.0:  return "critical"
			if GameState.exhaustion >= 31.0:  return "warning"
	return "ok"


func _check_collapse() -> void:
	if GameState.exhaustion < 100.0:
		return
	GameState.exhaustion = 75.0
	_prev_states["exhaustion"] = "warning"  # evita re-emit warning spurio dopo il collasso
	EventBus.player_collapsed.emit()


func _check_meal_hints() -> void:
	var hour: int = TimeManager.get_hour()
	if hour >= 12 and hour < 13 and _last_meal_hint != 1:
		if GameState.food < 60.0:
			EventBus.meal_hint.emit("pranzo")
		_last_meal_hint = 1
	elif hour >= 19 and hour < 20 and _last_meal_hint != 2:
		if GameState.food < 60.0:
			EventBus.meal_hint.emit("cena")
		_last_meal_hint = 2
	elif hour >= 6 and hour < 7 and _last_meal_hint != 0:
		_last_meal_hint = 0  # reset giornaliero
