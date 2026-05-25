extends Node


func get_display_name(faction_id: String) -> String:
	var data: Dictionary = FactionRegistry.get_faction(faction_id)
	var raw: String = str(data.get("name", faction_id))
	return LocaleManager.t_or("FACTION_" + faction_id.to_upper() + "_NAME", raw)


func get_display_desc(faction_id: String) -> String:
	return LocaleManager.t_or("FACTION_" + faction_id.to_upper() + "_DESC", "")


func get_display_state(faction_id: String) -> String:
	var state_id: String = FactionReputation.get_state_id(faction_id)
	return LocaleManager.t_or("FACTION_STATE_" + state_id.to_upper(), state_id)


func get_display_rank(faction_id: String, rank_n: int) -> String:
	return LocaleManager.t_or(
		"FACTION_" + faction_id.to_upper() + "_RANK_" + str(rank_n), str(rank_n)
	)


func get_display_passive_name(faction_id: String) -> String:
	var data: Dictionary = FactionRegistry.get_faction(faction_id)
	var passive_id: String = str(data.get("join_passive", ""))
	if passive_id == "":
		return ""
	return LocaleManager.t_or("PASSIVE_" + passive_id.to_upper() + "_NAME", passive_id)


func get_display_passive_desc(faction_id: String) -> String:
	var data: Dictionary = FactionRegistry.get_faction(faction_id)
	var passive_id: String = str(data.get("join_passive", ""))
	if passive_id == "":
		return ""
	return LocaleManager.t_or("PASSIVE_" + passive_id.to_upper() + "_DESC", "")


func get_display_crime(crime_type: String) -> String:
	return LocaleManager.t_or("CRIME_" + crime_type.to_upper(), crime_type)
