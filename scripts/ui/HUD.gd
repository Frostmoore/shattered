extends CanvasLayer

@onready var _hp_bar: ProgressBar = $Panel/VBox/HPRow/HPBar
@onready var _hp_val: Label       = $Panel/VBox/HPRow/HPVal
@onready var _mp_bar: ProgressBar = $Panel/VBox/MPRow/MPBar
@onready var _mp_val: Label       = $Panel/VBox/MPRow/MPVal
@onready var _st_bar: ProgressBar = $Panel/VBox/STRow/STBar
@onready var _st_val: Label       = $Panel/VBox/STRow/STVal
@onready var _xp_tag: Label       = $Panel/VBox/XPRow/XPTag
@onready var _xp_bar: ProgressBar = $Panel/VBox/XPRow/XPBar
@onready var _xp_val: Label       = $Panel/VBox/XPRow/XPVal
@onready var gold_label:  Label   = $Panel/VBox/GoldLabel
@onready var stats_label: Label   = $Panel/VBox/StatsLabel
@onready var map_label:   Label   = $Panel/VBox/MapLabel
@onready var quest_label: Label   = $Panel/VBox/QuestLabel


func _ready() -> void:
	_setup_bar_colors()
	EventBus.player_stats_changed.connect(_refresh)
	EventBus.equipment_changed.connect(_refresh)
	EventBus.xp_gained.connect(_refresh)
	EventBus.player_leveled_up.connect(_refresh)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.quest_started.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func _setup_bar_colors() -> void:
	_set_bar_fill(_hp_bar, Color(0.78, 0.12, 0.12))
	_set_bar_fill(_mp_bar, Color(0.12, 0.38, 0.82))
	_set_bar_fill(_st_bar, Color(0.82, 0.52, 0.08))
	_set_bar_fill(_xp_bar, Color(0.48, 0.12, 0.78))


func _set_bar_fill(bar: ProgressBar, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)


func _refresh(_arg: Variant = null) -> void:
	var hp: int     = int(GameState.player_stats["hp"])
	var max_hp: int = int(GameState.player_stats["max_hp"])
	var mp: int     = int(GameState.player_stats.get("mp", 0))
	var max_mp: int = int(GameState.player_stats.get("max_mp", 1))
	var st: int     = int(GameState.player_stats.get("stamina", 0))
	var max_st: int = int(GameState.player_stats.get("max_stamina", 1))

	_hp_bar.max_value = max_hp
	_hp_bar.value     = hp
	_hp_val.text      = "%d/%d" % [hp, max_hp]

	_mp_bar.max_value = max_mp
	_mp_bar.value     = mp
	_mp_val.text      = "%d/%d" % [mp, max_mp]

	_st_bar.max_value = max_st
	_st_bar.value     = st
	_st_val.text      = "%d/%d" % [st, max_st]

	var xp_next: int = LevelSystem.xp_for_next_level(GameState.level)
	_xp_tag.text      = "LV%d" % GameState.level
	_xp_bar.max_value = maxf(1.0, float(xp_next))
	_xp_bar.value     = GameState.xp
	if GameState.level >= LevelSystem.MAX_LEVEL:
		_xp_val.text = "MAX"
	else:
		_xp_val.text = "%d/%d" % [GameState.xp, xp_next]

	gold_label.text  = "Oro: %d" % int(GameState.player_stats["gold"])
	stats_label.text = "ATK: %d  DEF: %d" % [
		int(GameState.player_stats["attack"]) + Equipment.get_attack_bonus(),
		int(GameState.player_stats["defense"]) + Equipment.get_defense_bonus(),
	]
	quest_label.text = "Quest: " + (
		QuestManager.get_active_quest_title()
		if QuestManager.get_active_quest_title() != "" else "—"
	)


func _on_map_changed(map_id: String) -> void:
	map_label.text = "Zona: " + map_id.replace("_", " ").capitalize()
	_refresh()


func _on_quest_changed(_id: String) -> void:
	_refresh()
