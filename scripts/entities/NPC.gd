extends Entity
class_name NPC

var npc_id: String = ""
var dialogue_id: String = ""
var dialogue_id_quest_active: String = ""
var dialogue_id_quest_done: String = ""
var idle_dialogue_ids: Array[String] = []
var linked_quest_id: String = ""


func setup(data: Dictionary) -> void:
	npc_id                    = data.get("id", "npc")
	display_name              = data.get("name", "NPC")
	dialogue_id               = data.get("dialogue_id", "")
	dialogue_id_quest_active  = data.get("dialogue_id_quest_active", "")
	dialogue_id_quest_done    = data.get("dialogue_id_quest_done", "")
	linked_quest_id           = data.get("linked_quest_id", "")
	var raw_idle: Variant     = data.get("idle_dialogue_ids", [])
	if raw_idle is Array:
		for entry: Variant in (raw_idle as Array):
			idle_dialogue_ids.append(str(entry))
	faction     = "neutral"
	is_blocking = true
	_setup_visual("N", Color(1.0, 0.78, 0.20, 1))


func interact(_player: Node) -> void:
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
