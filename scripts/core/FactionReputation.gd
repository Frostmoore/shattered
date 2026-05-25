extends Node

const REP_MIN := -100
const REP_MAX := 100

const THRESH_ENEMY_SWORN := -75
const THRESH_HOSTILE     := -30
const THRESH_FRIENDLY    := 30
const THRESH_ALLIED      := 50
const THRESH_TRUSTED     := 75

const PROP_HIERARCHICAL   := 0.10  # parent and direct children
const PROP_LATERAL        := 0.30  # relations-matrix entries
const LATERAL_THRESHOLD   := 20    # |rel_value| must reach this to trigger
const DEBUG_PROPAGATION   := false # set true to log propagation traces


func get_rep(faction_id: String) -> int:
	return int(GameState.character_faction_rep.get(faction_id, _get_default_rep(faction_id)))


func set_rep(faction_id: String, value: int) -> void:
	var old_val: int = get_rep(faction_id)
	var new_val: int = clampi(value, REP_MIN, REP_MAX)
	if old_val == new_val:
		return

	var old_state: String    = get_state_id(faction_id)
	var old_supporter: bool  = FactionMembership.is_supporter(faction_id)

	GameState.character_faction_rep[faction_id] = new_val
	EventBus.faction_rep_changed.emit(faction_id, old_val, new_val)

	var new_state: String = get_state_id(faction_id)
	if old_state != new_state:
		EventBus.faction_state_changed.emit(faction_id, old_state, new_state)
		var faction_name: String = FactionDisplay.get_display_name(faction_id)
		var state_label: String  = FactionDisplay.get_display_state(faction_id)
		var is_positive: bool    = _state_rank(new_state) > _state_rank(old_state)
		EventBus.notification_shown.emit(Notification.faction_state(faction_name, state_label, is_positive))

	var new_supporter: bool = FactionMembership.is_supporter(faction_id)
	if not old_supporter and new_supporter:
		EventBus.faction_supporter_gained.emit(faction_id)
		EventBus.notification_shown.emit(
			Notification.faction_supporter_gained(FactionDisplay.get_display_name(faction_id))
		)
	elif old_supporter and not new_supporter:
		EventBus.faction_supporter_lost.emit(faction_id)
		EventBus.notification_shown.emit(
			Notification.faction_supporter_lost(FactionDisplay.get_display_name(faction_id))
		)

	if old_state == new_state and old_supporter == new_supporter and abs(new_val - old_val) >= 5:
		EventBus.notification_shown.emit(
			Notification.faction_rep_delta(FactionDisplay.get_display_name(faction_id), new_val - old_val)
		)


func add_rep(faction_id: String, delta: int, reason: String = "", propagate: bool = true) -> void:
	set_rep(faction_id, get_rep(faction_id) + delta)

	if not propagate or delta == 0:
		return

	# Propagated deltas collected first — applied all at once via set_rep (no cascade).
	var propagated: Dictionary = {}

	# ── 9.1 Hierarchical propagation (10%) ───────────────────────────────────
	var data: Dictionary = FactionRegistry.get_faction(faction_id)

	var parent_id: String = str(data.get("parent", ""))
	if parent_id != "":
		var d: int = roundi(float(delta) * PROP_HIERARCHICAL)
		if abs(d) >= 1:
			propagated[parent_id] = int(propagated.get(parent_id, 0)) + d

	for child: Dictionary in FactionRegistry.get_faction_children(faction_id):
		var child_id: String = str(child.get("id", ""))
		if child_id == "":
			continue
		var d: int = roundi(float(delta) * PROP_HIERARCHICAL)
		if abs(d) >= 1:
			propagated[child_id] = int(propagated.get(child_id, 0)) + d

	# ── 9.2 Lateral propagation via relations matrix (30% × sign) ────────────
	var all_rels: Dictionary = FactionRegistry.get_relations()
	var faction_rels: Variant = all_rels.get(faction_id, {})
	if faction_rels is Dictionary:
		for rel_id: String in (faction_rels as Dictionary):
			var rel_val: int = int((faction_rels as Dictionary)[rel_id])
			if abs(rel_val) < LATERAL_THRESHOLD:
				continue
			var d: int = roundi(float(delta) * PROP_LATERAL * signf(float(rel_val)))
			if abs(d) >= 1:
				propagated[rel_id] = int(propagated.get(rel_id, 0)) + d

	# ── Apply & log ───────────────────────────────────────────────────────────
	for prop_id: String in propagated:
		var prop_delta: int = int(propagated[prop_id])
		if prop_delta == 0:
			continue
		if DEBUG_PROPAGATION:
			print("FactionRep [%s +%d '%s'] → %s %+d" % [faction_id, delta, reason, prop_id, prop_delta])
		set_rep(prop_id, get_rep(prop_id) + prop_delta)


func get_state_id(faction_id: String) -> String:
	var rep: int = get_rep(faction_id)
	if rep <= THRESH_ENEMY_SWORN:
		return "enemy_sworn"
	if rep <= THRESH_HOSTILE:
		return "hostile"
	if rep < THRESH_FRIENDLY:
		return "neutral"
	if rep < THRESH_ALLIED:
		return "friendly"
	if rep < THRESH_TRUSTED:
		return "allied"
	return "trusted"


func initialize_for_new_game() -> void:
	GameState.character_faction_rep = {}
	for data: Dictionary in FactionRegistry.get_all_factions():
		var id: String = str(data.get("id", ""))
		if id != "":
			GameState.character_faction_rep[id] = int(data.get("default_rep", 0))


func _state_rank(state_id: String) -> int:
	match state_id:
		"enemy_sworn": return 0
		"hostile":     return 1
		"neutral":     return 2
		"friendly":    return 3
		"allied":      return 4
		"trusted":     return 5
	return 2


func _get_default_rep(faction_id: String) -> int:
	var data: Dictionary = FactionRegistry.get_faction(faction_id)
	return int(data.get("default_rep", 0))
