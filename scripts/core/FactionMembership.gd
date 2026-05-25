extends Node


func join_faction(faction_id: String) -> void:
	if is_member(faction_id):
		return
	var data: Dictionary = FactionRegistry.get_faction(faction_id)
	if not bool(data.get("joinable", false)):
		push_error("FactionMembership: fazione non joinable: " + faction_id)
		return
	GameState.character_faction_membership[faction_id] = {"rank": 0, "join_date": 0, "tax_debt": 0}
	FactionEffects.apply_join_passive(faction_id)
	EventBus.faction_joined.emit(faction_id)


func leave_faction(faction_id: String) -> void:
	if not is_member(faction_id):
		return
	FactionEffects.remove_join_passive(faction_id)
	GameState.character_faction_membership.erase(faction_id)
	FactionReputation.add_rep(faction_id, -20, "left_faction", false)
	EventBus.faction_left.emit(faction_id)


func get_rank(faction_id: String) -> int:
	var membership: Variant = GameState.character_faction_membership.get(faction_id, null)
	if membership is Dictionary:
		return int((membership as Dictionary).get("rank", 0))
	return -1


func advance_rank(faction_id: String) -> void:
	if not is_member(faction_id):
		return
	if FactionEconomy.has_tax_restrictions(faction_id):
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("NOTIF_TAX_RANK_BLOCKED",
				"Paga le tasse arretrate prima di avanzare di rango.")))
		return
	var entry: Variant = GameState.character_faction_membership.get(faction_id, null)
	if entry is Dictionary:
		(entry as Dictionary)["rank"] = int((entry as Dictionary).get("rank", 0)) + 1
		FactionEffects.apply_join_passive(faction_id)


func is_member(faction_id: String) -> bool:
	return GameState.character_faction_membership.has(faction_id)


func is_supporter(faction_id: String) -> bool:
	if is_member(faction_id):
		return false
	var data: Dictionary = FactionRegistry.get_faction(faction_id)
	if not bool(data.get("supporter_eligible", false)):
		return false
	return FactionReputation.get_rep(faction_id) >= 50


func wears_recognition_sign(faction_id: String) -> bool:
	if not is_member(faction_id):
		return false
	var data: Dictionary = FactionRegistry.get_faction(faction_id)
	var sign_id_raw: Variant = data.get("recognition_item_id")
	var slot_raw: Variant    = data.get("recognition_slot")
	if sign_id_raw == null or slot_raw == null:
		return true
	var sign_id: String = str(sign_id_raw)
	var slot: String    = str(slot_raw)
	if sign_id == "" or slot == "":
		return true
	return str(GameState.equipped.get(slot, "")) == sign_id


func reapply_all_passives() -> void:
	for faction_id_var: Variant in GameState.character_faction_membership:
		FactionEffects.apply_join_passive(str(faction_id_var))


func initialize_for_new_game() -> void:
	GameState.character_faction_membership = {}
	GameState.faction_passive_flags        = {}
	GameState.known_faction_members        = {}
