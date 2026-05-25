extends Node

var _quests: Dictionary = {}
var _kill_progress: Dictionary = {}


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir: DirAccess = DirAccess.open("res://data/quests/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			_load_file("res://data/quests/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed as Dictionary
	_quests[d["id"]] = d


func start_quest(quest_id: String) -> void:
	if GameState.active_quests.has(quest_id) or GameState.ready_quests.has(quest_id) or GameState.completed_quests.has(quest_id):
		return
	if not _quests.has(quest_id):
		push_error("QuestManager: unknown quest: " + quest_id)
		return
	GameState.active_quests.append(quest_id)
	_kill_progress[quest_id] = {}
	EventBus.quest_started.emit(quest_id)
	var q: Dictionary = _quests.get(quest_id, {})
	EventBus.notification_shown.emit(Notification.quest_started(q.get("title", quest_id)))
	var raw_obj_check: Variant = q.get("objectives", [])
	if (raw_obj_check is Array) and (raw_obj_check as Array).is_empty():
		var mode_check: String = q.get("completion_mode", "auto")
		if mode_check == "turn_in":
			_mark_ready(quest_id)
		else:
			_complete_quest(quest_id)


func get_quest_data(quest_id: String) -> Dictionary:
	return _quests.get(quest_id, {})


func get_progress(quest_id: String, target_id: String) -> int:
	if not _kill_progress.has(quest_id):
		return 0
	return int(_kill_progress[quest_id].get(target_id, 0))


func on_enemy_killed(enemy_id: String) -> void:
	for quest_id: Variant in GameState.active_quests.duplicate():
		var qid: String = str(quest_id)
		var quest: Dictionary = _quests.get(qid, {})
		var raw_obj: Variant = quest.get("objectives", [])
		if not raw_obj is Array:
			continue
		for obj: Variant in (raw_obj as Array):
			if not obj is Dictionary:
				continue
			var o: Dictionary = obj as Dictionary
			if o.get("type") == "kill_enemy" and o.get("target_id") == enemy_id:
				if not _kill_progress.has(qid):
					_kill_progress[qid] = {}
				if not _kill_progress[qid].has(enemy_id):
					_kill_progress[qid][enemy_id] = 0
				_kill_progress[qid][enemy_id] = int(_kill_progress[qid][enemy_id]) + 1
				if int(_kill_progress[qid][enemy_id]) >= int(o.get("required", 1)):
					var mode: String = quest.get("completion_mode", "auto")
					if mode == "turn_in":
						_mark_ready(qid)
					else:
						_complete_quest(qid)


func _mark_ready(quest_id: String) -> void:
	if not GameState.active_quests.has(quest_id):
		return
	if GameState.ready_quests.has(quest_id):
		return
	GameState.active_quests.erase(quest_id)
	GameState.ready_quests.append(quest_id)
	var quest: Dictionary = _quests.get(quest_id, {})
	EventBus.quest_ready.emit(quest_id)
	EventBus.notification_shown.emit(Notification.quest_ready(quest.get("title", quest_id)))


func try_complete_quest(quest_id: String) -> void:
	if GameState.ready_quests.has(quest_id):
		_complete_quest(quest_id)
	elif GameState.active_quests.has(quest_id):
		var quest: Dictionary = _quests.get(quest_id, {})
		if quest.get("completion_mode", "auto") != "turn_in":
			_complete_quest(quest_id)


func is_quest_ready(quest_id: String) -> bool:
	return GameState.ready_quests.has(quest_id)


func _complete_quest(quest_id: String) -> void:
	GameState.active_quests.erase(quest_id)
	GameState.ready_quests.erase(quest_id)
	GameState.completed_quests.append(quest_id)

	var quest: Dictionary = _quests.get(quest_id, {})
	var rewards: Dictionary = quest.get("rewards", {})

	# join first so faction passives are active when XP/gold bonuses are calculated
	var join_id: Variant = rewards.get("join_faction")
	if join_id is String and str(join_id) != "":
		FactionMembership.join_faction(str(join_id))

	if rewards.has("xp"):
		LevelSystem.add_xp(int(rewards["xp"]), "quest")
	if rewards.has("gold") and int(rewards.get("gold", 0)) > 0:
		var base_gold: int  = int(rewards["gold"])
		var gmult: float    = FactionEffects.get_gold_multiplier("quest")
		GameState.modify_gold(roundi(float(base_gold) * gmult) if gmult != 1.0 else base_gold)
	var raw_items: Variant = rewards.get("items", [])
	if raw_items is Array:
		for item_id: Variant in (raw_items as Array):
			Inventory.add_item(str(item_id))

	var raw_rep: Variant = rewards.get("faction_rep", [])
	if raw_rep is Array:
		for entry: Variant in (raw_rep as Array):
			if not entry is Dictionary:
				continue
			var e: Dictionary = entry as Dictionary
			var fid: String   = str(e.get("faction_id", ""))
			var amt: int      = int(e.get("amount", 0))
			if fid != "" and amt != 0:
				FactionReputation.add_rep(fid, amt, "quest_reward")

	var flags: Dictionary = quest.get("sets_flags", {})
	for flag: Variant in flags:
		GameState.set_flag(str(flag), flags[flag] as bool)

	EventBus.quest_completed.emit(quest_id)
	EventBus.notification_shown.emit(Notification.quest_completed(quest.get("title", quest_id)))


func get_active_quest_title() -> String:
	if GameState.active_quests.is_empty():
		return ""
	var q: Dictionary = _quests.get(str(GameState.active_quests[0]), {})
	return q.get("title", "")
