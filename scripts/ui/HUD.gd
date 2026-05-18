extends CanvasLayer

@onready var hp_label: Label    = $Panel/VBox/HPLabel
@onready var gold_label: Label  = $Panel/VBox/GoldLabel
@onready var level_label: Label = $Panel/VBox/LevelLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var map_label: Label   = $Panel/VBox/MapLabel
@onready var quest_label: Label = $Panel/VBox/QuestLabel


func _ready() -> void:
	EventBus.player_stats_changed.connect(_refresh)
	EventBus.equipment_changed.connect(_refresh)
	EventBus.xp_gained.connect(_refresh)
	EventBus.player_leveled_up.connect(_refresh)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.quest_started.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func _refresh(_arg: Variant = null) -> void:
	hp_label.text   = "HP: %d/%d" % [GameState.player_stats["hp"], GameState.player_stats["max_hp"]]
	gold_label.text = "Oro: %d" % GameState.player_stats["gold"]
	var xp_next: int = LevelSystem.xp_for_next_level(GameState.level)
	if GameState.level >= 100:
		level_label.text = "LV: 100  MAX"
	else:
		level_label.text = "LV: %d  XP: %d/%d" % [GameState.level, GameState.xp, xp_next]
	stats_label.text = "ATK: %d  DEF: %d" % [
		int(GameState.player_stats["attack"]) + Equipment.get_attack_bonus(),
		int(GameState.player_stats["defense"]) + Equipment.get_defense_bonus()
	]
	quest_label.text = "Quest: " + (QuestManager.get_active_quest_title() if QuestManager.get_active_quest_title() != "" else "—")


func _on_map_changed(map_id: String) -> void:
	map_label.text = "Zona: " + map_id.replace("_", " ").capitalize()
	_refresh()


func _on_quest_changed(_id: String) -> void:
	_refresh()
