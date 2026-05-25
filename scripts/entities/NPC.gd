extends Entity
class_name NPC

var npc_id: String = ""
var dialogue_id: String = ""
var dialogue_id_quest_active: String = ""
var dialogue_id_quest_done: String = ""
var idle_dialogue_ids: Array[String] = []
var linked_quest_id: String = ""
var primary_faction_id: String = ""
var secondary_faction_ids: Array[String] = []
var vendor: bool = false
var love_interest: bool = false
var inventory: Array[Dictionary] = []
var conditional_dialogues: Array[Dictionary] = []
var black_market: bool = false
var safe_house:   bool = false
var faction_action_id: String = ""
var is_guard_npc: bool = false
var gender:       String = ""
var is_child:     bool = false


func setup(data: Dictionary) -> void:
	npc_id                    = data.get("id", "npc")
	var raw_name: String      = str(data.get("name", "NPC"))
	display_name              = LocaleManager.t_or("NPC_" + npc_id.to_upper() + "_NAME", raw_name)
	dialogue_id               = data.get("dialogue_id", "")
	dialogue_id_quest_active  = data.get("dialogue_id_quest_active", "")
	dialogue_id_quest_done    = data.get("dialogue_id_quest_done", "")
	linked_quest_id           = data.get("linked_quest_id", "")
	var raw_idle: Variant     = data.get("idle_dialogue_ids", [])
	if raw_idle is Array:
		for entry: Variant in (raw_idle as Array):
			idle_dialogue_ids.append(str(entry))

	primary_faction_id = str(data.get("faction_id", ""))
	if primary_faction_id == "":
		primary_faction_id = GameState.current_location_faction_id
	var raw_secondary: Variant = data.get("secondary_faction_ids", [])
	if raw_secondary is Array:
		for fid: Variant in (raw_secondary as Array):
			secondary_faction_ids.append(str(fid))

	vendor        = bool(data.get("vendor", false))
	love_interest = bool(data.get("love_interest", false))
	var raw_inv: Variant = data.get("inventory", [])
	if raw_inv is Array:
		for entry: Variant in (raw_inv as Array):
			if entry is Dictionary:
				inventory.append(entry as Dictionary)
	var raw_cond: Variant = data.get("conditional_dialogues", [])
	if raw_cond is Array:
		for entry: Variant in (raw_cond as Array):
			if entry is Dictionary:
				conditional_dialogues.append(entry as Dictionary)

	black_market      = bool(data.get("black_market",    false))
	safe_house        = bool(data.get("safe_house",      false))
	faction_action_id = str(data.get("faction_action",   ""))
	is_guard_npc      = bool(data.get("is_guard",        false))
	gender            = str(data.get("gender",           ""))
	is_child          = bool(data.get("is_child",        false))

	faction     = primary_faction_id if primary_faction_id != "" else "neutral"
	is_blocking = true
	_setup_visual("N", Color(1.0, 0.78, 0.20, 1))


func interact(_player: Node) -> void:
	if primary_faction_id != "":
		GameState.record_known_member(primary_faction_id, npc_id, display_name)

	# Safe house: register this location on first encounter
	if safe_house:
		WorldState.register_safe_house(GameState.current_map_id, grid_position)

	# Black market: requires tsn_black_market passive flag
	if black_market:
		if not bool(GameState.faction_passive_flags.get("tsn_black_market", false)):
			EventBus.notification_shown.emit(Notification.faction_access_denied(
				FactionDisplay.get_display_name("tavola_senza_nome")))
			return

	# Faction world actions triggered through NPC dialogue (e.g., cartografi HQ)
	if faction_action_id != "":
		var svc: Node = get_node_or_null("/root/FactionActionsService")
		if svc != null:
			match faction_action_id:
				"deposit_map":        svc.call("try_deposit_map")
				"build_post_station": svc.call("try_build_post_station")
				"open_ambulatorio":   svc.call("try_open_ambulatorio")
				"reduce_bounty":      svc.call("try_reduce_bounty_tsn")
		return

	# Standard faction access check (primary faction)
	if primary_faction_id != "":
		var state: String = FactionReputation.get_state_id(primary_faction_id)
		if state == "enemy_sworn":
			var fname: String = FactionDisplay.get_display_name(primary_faction_id)
			EventBus.notification_shown.emit(Notification.faction_access_denied(fname))
			return
	var id: String = _pick_dialogue()
	if id != "":
		DialogueManager.start_dialogue(id)


func _pick_dialogue() -> String:
	# Quest-state aware selection.
	if linked_quest_id != "":
		if GameState.completed_quests.has(linked_quest_id) or GameState.ready_quests.has(linked_quest_id):
			if dialogue_id_quest_done != "":
				return dialogue_id_quest_done
		elif GameState.active_quests.has(linked_quest_id):
			if dialogue_id_quest_active != "":
				return dialogue_id_quest_active

	# If the main dialogue already started the quest, use idles to avoid repetition.
	if linked_quest_id != "" and GameState.active_quests.has(linked_quest_id):
		if not idle_dialogue_ids.is_empty():
			return idle_dialogue_ids[randi() % idle_dialogue_ids.size()]

	# Default: main dialogue (quest-giver) or random idle.
	if not idle_dialogue_ids.is_empty() and dialogue_id == "":
		return idle_dialogue_ids[randi() % idle_dialogue_ids.size()]
	return dialogue_id
