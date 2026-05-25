extends Entity
class_name PostStation

var station_uid: String = ""


func setup(params: Dictionary) -> void:
	station_uid  = str(params.get("uid", ""))
	display_name = LocaleManager.t_or("UI_POST_STATION_NAME", "Stazione di Posta")
	is_blocking  = true
	_setup_visual("⚑", Color(0.9, 0.8, 0.2, 1))


func interact(_player: Node) -> void:
	var max_hp: int = int(GameState.player_stats.get("max_hp", 1))
	var cur_hp: int = int(GameState.player_stats.get("hp", 0))
	var healed: bool = cur_hp < max_hp
	if healed:
		GameState.heal_player(max_hp - cur_hp)
	var msg: String
	if healed:
		msg = LocaleManager.t_or("UI_POST_STATION_RESTED", "Stazione di Posta: HP ripristinati.")
	else:
		msg = LocaleManager.t_or("UI_POST_STATION_ALREADY_RESTED", "Stazione di Posta: sei già in piena forma.")
	EventBus.notification_shown.emit(Notification.faction_action(msg))
