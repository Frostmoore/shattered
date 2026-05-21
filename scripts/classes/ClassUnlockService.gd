extends Node


func _ready() -> void:
	EventBus.milestone_updated.connect(_on_milestone_updated)
	# Controlla subito in caso alcune condizioni siano già soddisfatte
	call_deferred("_check_all_unlocks")


func _on_milestone_updated(_key: String, _value: int) -> void:
	_check_all_unlocks()


func _check_all_unlocks() -> void:
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		return
	var gmt: Node = get_node_or_null("/root/GlobalMilestoneTracker")
	if not gmt:
		return
	for cls: Variant in reg.call("get_all"):
		if not cls is Dictionary:
			continue
		var data: Dictionary = cls as Dictionary
		var class_id: String = str(data.get("id", ""))
		if class_id.is_empty():
			continue
		if gmt.call("is_class_unlocked", class_id):
			continue
		var unlock: Variant = data.get("unlock", {})
		if not unlock is Dictionary:
			continue
		if _is_condition_met(unlock as Dictionary):
			gmt.call("unlock_class", class_id)
			var uname: String = str(data.get("name", class_id))
			EventBus.class_unlocked.emit(class_id, uname)
			EventBus.notification_shown.emit(Notification.class_unlock(uname))


func _is_condition_met(unlock: Dictionary) -> bool:
	var type: String  = str(unlock.get("type", "always"))
	var scope: String = str(unlock.get("trigger_scope", "global"))
	var value: Variant = unlock.get("value", 0)

	if type == "always":
		return true

	# "all" è un valore stringa speciale per overworld_zones_explored
	if type == "overworld_zones_explored" and str(value) == "all":
		return false  # TODO: implementare tracking zone overworld

	var required: int = int(value)
	var current: int  = 0

	if scope == "run":
		current = int(GameState.run_milestones.get(type, 0))
	else:
		var gmt: Node = get_node_or_null("/root/GlobalMilestoneTracker")
		current = gmt.call("get_value", type) if gmt else 0

	if type == "all_classes_completed":
		var reg: Node = get_node_or_null("/root/ClassRegistry")
		var gmt2: Node = get_node_or_null("/root/GlobalMilestoneTracker")
		if not reg or not gmt2:
			return false
		var completed: Array = gmt2.call("get_completed_classes")
		for c: Variant in reg.call("get_all"):
			var cid: String = str((c as Dictionary).get("id", ""))
			if not completed.has(cid):
				return false
		return true

	if type in ["kills_total", "kills_boss", "dungeons_completed",
			"dungeons_completed_no_death", "deaths_total",
			"damage_dealt_total", "damage_taken_total", "dungeon_floors_total",
			"chests_opened", "quests_completed", "npcs_spoken",
			"consumables_used", "save_points_used", "class_respec_count",
			"overworld_tiles", "overworld_zones_visited", "dungeon_rooms_explored",
			"tiles_explored_total", "combat_wins_no_items", "near_death_survived",
			"survived_at_1hp", "attacks_dodged_total", "gold_accumulated",
			"enemies_seen_die", "scrolls_collected"]:
		return current >= required

	return false
