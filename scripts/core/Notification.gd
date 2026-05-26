extends RefCounted
class_name Notification

var text:     String
var color:    Color = Color.WHITE
var duration: float = 3.0


static func item(item_name: String, qty: int = 1) -> Notification:
	var n := Notification.new()
	if qty > 1:
		n.text = LocaleManager.t("NOTIF_ITEM_COLLECTED_MULTI", {"name": item_name, "qty": qty})
	else:
		n.text = LocaleManager.t("NOTIF_ITEM_COLLECTED_SINGLE", {"name": item_name})
	n.color = Color(0.85, 0.85, 0.95)
	return n


static func gold(amount: int) -> Notification:
	var n := Notification.new()
	n.text = LocaleManager.t("NOTIF_GOLD_GAINED", {"amount": amount})
	n.color = Color(1.0, 0.82, 0.2)
	return n


static func quest_started(quest_name: String) -> Notification:
	var n := Notification.new()
	n.text = LocaleManager.t("NOTIF_QUEST_STARTED", {"title": quest_name})
	n.color = Color(0.4, 0.9, 0.45)
	return n


static func quest_ready(quest_name: String) -> Notification:
	var n := Notification.new()
	n.text = LocaleManager.t("NOTIF_QUEST_READY", {"title": quest_name})
	n.color = Color(1.0, 0.6, 0.1)
	n.duration = 4.0
	return n


static func quest_completed(quest_name: String) -> Notification:
	var n := Notification.new()
	n.text = LocaleManager.t("NOTIF_QUEST_COMPLETED", {"title": quest_name})
	n.color = Color(0.95, 0.8, 0.15)
	n.duration = 4.0
	return n


static func level_up(level: int, gains: Dictionary = {}) -> Notification:
	var n := Notification.new()
	var lines: Array[String] = [LocaleManager.t("NOTIF_LEVEL_UP_TITLE", {"level": level})]
	var parts: Array[String] = []
	for attr: String in ["str", "dex", "int", "vit", "wil"]:
		var v: int = int(gains.get(attr, 0))
		if v > 0:
			parts.append(LocaleManager.t("NOTIF_ATTR_GAIN",
					{"attr": attr.to_upper(), "amount": v}))
	if not parts.is_empty():
		lines.append("  ".join(parts))
	lines.append(LocaleManager.t("NOTIF_LEVEL_UP_RESTORE"))
	n.text     = "\n".join(lines)
	n.color    = Color(0.75, 0.4, 1.0)
	n.duration = 4.0
	return n


static func class_unlock(name: String) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t("NOTIF_CLASS_UNLOCKED", {"name": name})
	n.color    = Color(0.45, 0.90, 1.0)
	n.duration = 5.0
	return n


static func class_respec(name: String) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t("NOTIF_CLASS_CHANGED", {"name": name})
	n.color    = Color(0.95, 0.55, 0.95)
	n.duration = 4.0
	return n


static func warning(msg: String) -> Notification:
	var n := Notification.new()
	n.text  = msg   # caller is responsible for passing a localised string
	n.color = Color(0.95, 0.55, 0.15)
	return n


static func identify_item(item_name: String) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t("NOTIF_ITEM_IDENTIFIED", {"name": item_name})
	n.color    = Color(0.4, 0.9, 1.0)
	n.duration = 3.5
	return n


static func save_point() -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t("NOTIF_SAVE_POINT")
	n.color    = Color(0.4, 0.88, 0.95)
	n.duration = 3.5
	return n


static func faction_state(faction_name: String, state_label: String, is_positive: bool) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t_or("NOTIF_FACTION_STATE",
				faction_name + ": " + state_label,
				{"faction": faction_name, "state": state_label})
	n.color    = Color(0.5, 0.9, 0.55) if is_positive else Color(0.95, 0.35, 0.25)
	n.duration = 3.5
	return n


static func faction_supporter_gained(faction_name: String) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t_or("NOTIF_FACTION_SUPPORTER_GAINED",
				"Sostenitore di " + faction_name, {"faction": faction_name})
	n.color    = Color(0.5, 0.88, 0.5)
	n.duration = 4.0
	return n


static func faction_supporter_lost(faction_name: String) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t_or("NOTIF_FACTION_SUPPORTER_LOST",
				"Non più sostenitore di " + faction_name, {"faction": faction_name})
	n.color    = Color(0.85, 0.55, 0.25)
	n.duration = 4.0
	return n


static func faction_action(msg: String) -> Notification:
	var n := Notification.new()
	n.text  = msg
	n.color = Color(0.4, 0.85, 0.95)
	return n


static func faction_access_denied(faction_name: String) -> Notification:
	var n := Notification.new()
	n.text  = LocaleManager.t_or("NOTIF_FACTION_ACCESS_DENIED",
				"Accesso negato: " + faction_name, {"faction": faction_name})
	n.color = Color(0.9, 0.3, 0.25)
	return n


static func crime_committed() -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t_or("NOTIF_CRIME_COMMITTED", "Crimine commesso! Le guardie ti cercano.")
	n.color    = Color(0.9, 0.3, 0.25)
	n.duration = 4.0
	return n


static func player_arrested(fine: int) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t_or("NOTIF_CRIME_ARRESTED", "Arrestato. Multa: {fine}g.", {"fine": fine})
	n.color    = Color(0.95, 0.55, 0.15)
	n.duration = 4.0
	return n


static func crime_cleared() -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t_or("NOTIF_CRIME_CLEARED", "Il mandato è stato cancellato.")
	n.color    = Color(0.4, 0.85, 0.95)
	n.duration = 3.5
	return n


static func crime_safe_house() -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t_or("NOTIF_CRIME_SAFE_HOUSE", "Rifugio sicuro — il mandato è stato cancellato.")
	n.color    = Color(0.4, 0.85, 0.95)
	n.duration = 4.0
	return n


static func wait_finished(hours: int, new_time: String) -> Notification:
	var n := Notification.new()
	n.text     = LocaleManager.t("NOTIF_WAIT_DONE", {"hours": str(hours), "time": new_time})
	n.color    = Color(0.6, 0.9, 1.0)
	n.duration = 3.0
	return n


static func faction_rep_delta(faction_name: String, delta: int) -> Notification:
	var n    := Notification.new()
	var delta_prefix := "+" if delta > 0 else ""
	n.text     = LocaleManager.t_or("NOTIF_FACTION_REP_DELTA",
				"{faction}: {delta} rep",
				{"faction": faction_name, "delta": delta_prefix + str(delta)})
	n.color    = Color(0.40, 0.80, 0.45) if delta > 0 else Color(0.88, 0.35, 0.20)
	n.duration = 2.0
	return n
