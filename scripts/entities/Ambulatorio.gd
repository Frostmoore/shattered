extends Entity
class_name Ambulatorio

var service_uid: String = ""


func setup(params: Dictionary) -> void:
	service_uid  = str(params.get("uid", ""))
	display_name = LocaleManager.t_or("UI_AMBULATORIO_NAME", "Ambulatorio")
	is_blocking  = true
	_setup_visual("+", Color(0.9, 0.35, 0.35, 1))


func interact(_player: Node) -> void:
	var max_hp: int = int(GameState.player_stats.get("max_hp", 1))
	var cur_hp: int = int(GameState.player_stats.get("hp", 0))
	var healed: bool = cur_hp < max_hp
	if healed:
		GameState.heal_player(max_hp - cur_hp)
	var msg: String
	if healed:
		msg = LocaleManager.t_or("UI_AMBULATORIO_HEALED", "Ambulatorio: cure prestate. HP ripristinati.")
	else:
		msg = LocaleManager.t_or("UI_AMBULATORIO_ALREADY_HEALED", "Ambulatorio: sei già in piena salute.")
	EventBus.notification_shown.emit(Notification.faction_action(msg))
