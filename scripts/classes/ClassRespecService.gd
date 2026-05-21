extends Node


func respec(new_class_id: String) -> void:
	var gs: Node  = get_node_or_null("/root/GameState")
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	var rt: Node  = get_node_or_null("/root/ClassRuntime")
	var gmt: Node = get_node_or_null("/root/GlobalMilestoneTracker")
	if not gs or not reg or not rt:
		return

	var current_class: String = str(gs.get("current_class"))
	if new_class_id == current_class:
		EventBus.notification_shown.emit(Notification.warning("Sei già questa classe!"))
		return

	var data: Dictionary = reg.call("get_class_data", new_class_id)
	if data.is_empty():
		return

	var ally_mgr: Node = get_node_or_null("/root/AllyManager")
	if ally_mgr:
		ally_mgr.call("clear_temp_allies")

	# CRITICO: usa = non += per evitare accumulo stat tra respec
	gs.call("apply_class", new_class_id)
	rt.call("set_active_class", new_class_id)

	if gmt:
		gmt.call("increment", "class_respec_count", 1)

	var uname: String = str(data.get("name", new_class_id))
	EventBus.player_stats_changed.emit()
	EventBus.notification_shown.emit(Notification.class_respec(uname))
