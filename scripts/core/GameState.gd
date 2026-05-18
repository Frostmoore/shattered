extends Node

var world_name: String = ""
var character_name: String = ""
var permadeath: bool = false

var current_map_id: String = "overworld"
var player_position: Vector2i = Vector2i(5, 5)

var player_stats: Dictionary = {
	"hp": 20,
	"max_hp": 20,
	"attack": 4,
	"defense": 1,
	"gold": 0
}

var world_flags: Dictionary = {
	"intro_completed": false,
	"dungeon_boss_defeated": false,
	"village_quest_completed": false
}

var active_quests: Array = []
var ready_quests: Array = []
var completed_quests: Array = []
var inventory: Array = []

var equipped: Dictionary = {
	"helm":       "",
	"armor":      "",
	"left_hand":  "",
	"right_hand": "",
	"ring_1":     "",
	"ring_2":     "",
	"amulet":     "",
	"boots":      "",
	"cloak":      "",
	"accessory":  ""
}

var quick_slots: Array = ["", "", ""]

var level: int = 1
var xp: int = 0


func set_flag(flag_name: String, value: bool) -> void:
	world_flags[flag_name] = value
	EventBus.world_flag_changed.emit(flag_name, value)


func get_flag(flag_name: String) -> bool:
	return world_flags.get(flag_name, false)


func modify_gold(amount: int) -> void:
	player_stats["gold"] = int(player_stats["gold"]) + amount
	EventBus.inventory_changed.emit()
	if amount > 0:
		EventBus.notification_shown.emit(Notification.gold(amount))


func heal_player(amount: int) -> void:
	player_stats["hp"] = mini(int(player_stats["hp"]) + amount, int(player_stats["max_hp"]))
	EventBus.player_stats_changed.emit()


func damage_player(amount: int) -> void:
	player_stats["hp"] = maxi(0, int(player_stats["hp"]) - amount)
	EventBus.player_stats_changed.emit()
	if int(player_stats["hp"]) <= 0:
		EventBus.player_died.emit()
