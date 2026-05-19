extends CanvasLayer
class_name StatusScreen

@onready var _str_label: Label      = $Panel/Margin/VBox/Columns/Attrs/StrLabel
@onready var _dex_label: Label      = $Panel/Margin/VBox/Columns/Attrs/DexLabel
@onready var _int_label: Label      = $Panel/Margin/VBox/Columns/Attrs/IntLabel
@onready var _vit_label: Label      = $Panel/Margin/VBox/Columns/Attrs/VitLabel
@onready var _wil_label: Label      = $Panel/Margin/VBox/Columns/Attrs/WilLabel

@onready var _hp_bar: ProgressBar   = $Panel/Margin/VBox/Columns/Stats/HPRow/HPBar
@onready var _hp_val: Label         = $Panel/Margin/VBox/Columns/Stats/HPRow/HPVal
@onready var _mp_bar: ProgressBar   = $Panel/Margin/VBox/Columns/Stats/MPRow/MPBar
@onready var _mp_val: Label         = $Panel/Margin/VBox/Columns/Stats/MPRow/MPVal
@onready var _st_bar: ProgressBar   = $Panel/Margin/VBox/Columns/Stats/STRow/STBar
@onready var _st_val: Label         = $Panel/Margin/VBox/Columns/Stats/STRow/STVal

@onready var _atk_label: Label      = $Panel/Margin/VBox/Combat/AtkLabel
@onready var _def_label: Label      = $Panel/Margin/VBox/Combat/DefLabel

@onready var _level_label: Label    = $Panel/Margin/VBox/XPSection/LevelLabel
@onready var _xp_bar: ProgressBar   = $Panel/Margin/VBox/XPSection/XPRow/XPBar
@onready var _xp_val: Label         = $Panel/Margin/VBox/XPSection/XPRow/XPVal


func _ready() -> void:
	visible = false
	_setup_bar_colors()
	EventBus.toggle_status_screen.connect(_on_toggle)
	EventBus.player_stats_changed.connect(_on_stats_changed)
	EventBus.equipment_changed.connect(_on_stats_changed)
	EventBus.player_leveled_up.connect(_on_stats_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_c: bool = event is InputEventKey \
		and (event as InputEventKey).keycode == KEY_C \
		and event.is_pressed() and not event.is_echo()
	if is_c or event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


func _on_toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _on_stats_changed(_arg: Variant = null) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var attrs: Dictionary = GameState.attributes
	_str_label.text = "STR  %d" % int(attrs.get("str", 0))
	_dex_label.text = "DEX  %d" % int(attrs.get("dex", 0))
	_int_label.text = "INT  %d" % int(attrs.get("int", 0))
	_vit_label.text = "VIT  %d" % int(attrs.get("vit", 0))
	_wil_label.text = "WIL  %d" % int(attrs.get("wil", 0))

	var hp: int     = int(GameState.player_stats["hp"])
	var max_hp: int = int(GameState.player_stats["max_hp"])
	var mp: int     = int(GameState.player_stats.get("mp", 0))
	var max_mp: int = int(GameState.player_stats.get("max_mp", 1))
	var st: int     = int(GameState.player_stats.get("stamina", 0))
	var max_st: int = int(GameState.player_stats.get("max_stamina", 1))

	_hp_bar.max_value = max_hp
	_hp_bar.value     = hp
	_hp_val.text      = "%d / %d" % [hp, max_hp]

	_mp_bar.max_value = max_mp
	_mp_bar.value     = mp
	_mp_val.text      = "%d / %d" % [mp, max_mp]

	_st_bar.max_value = max_st
	_st_bar.value     = st
	_st_val.text      = "%d / %d" % [st, max_st]

	var base_atk: int  = int(GameState.player_stats["attack"])
	var equip_atk: int = Equipment.get_attack_bonus()
	var base_def: int  = int(GameState.player_stats["defense"])
	var equip_def: int = Equipment.get_defense_bonus()

	_atk_label.text = "Attacco:  %d  (base %d  +%d equip)" % [base_atk + equip_atk, base_atk, equip_atk]
	_def_label.text = "Difesa:   %d  (base %d  +%d equip)" % [base_def + equip_def, base_def, equip_def]

	_atk_label.tooltip_text = _build_tooltip(Equipment.get_attack_bonus_breakdown(), "attacco")
	_def_label.tooltip_text = _build_tooltip(Equipment.get_defense_bonus_breakdown(), "difesa")

	var lv: int      = GameState.level
	var xp_next: int = LevelSystem.xp_for_next_level(lv)
	_level_label.text = "Livello  %d" % lv
	_xp_bar.max_value = maxf(1.0, float(xp_next))
	_xp_bar.value     = GameState.xp
	if lv >= LevelSystem.MAX_LEVEL:
		_xp_val.text = "Livello massimo"
	else:
		_xp_val.text = "%d / %d XP" % [GameState.xp, xp_next]


func _build_tooltip(breakdown: Array, stat_name: String) -> String:
	if breakdown.is_empty():
		return "Nessun bonus da equipaggiamento"
	var lines: Array[String] = ["Bonus %s da equipaggiamento:" % stat_name]
	for entry: Variant in breakdown:
		var e: Dictionary = entry as Dictionary
		lines.append("  +%d  %s" % [int(e["bonus"]), str(e["name"])])
	return "\n".join(lines)


func _setup_bar_colors() -> void:
	_set_bar_fill(_hp_bar, Color(0.78, 0.12, 0.12))
	_set_bar_fill(_mp_bar, Color(0.12, 0.38, 0.82))
	_set_bar_fill(_st_bar, Color(0.82, 0.52, 0.08))
	_set_bar_fill(_xp_bar, Color(0.48, 0.12, 0.78))


func _set_bar_fill(bar: ProgressBar, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)
