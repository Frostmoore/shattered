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

var _class_label:   Label
var _special_label: Label
var _crime_status_label: Label
var _crime_record_label: Label


func _ready() -> void:
	visible = false
	_setup_bar_colors()
	_setup_class_section()
	_setup_crime_section()
	EventBus.toggle_status_screen.connect(_on_toggle)
	EventBus.player_stats_changed.connect(_on_stats_changed)
	EventBus.equipment_changed.connect(_on_stats_changed)
	EventBus.player_leveled_up.connect(_on_stats_changed)
	EventBus.player_arrested.connect(_on_stats_changed)
	EventBus.crime_committed.connect(_on_stats_changed)
	EventBus.crime_cleared.connect(_on_stats_changed)


func _setup_crime_section() -> void:
	var vbox: VBoxContainer = $Panel/Margin/VBox

	var header := Label.new()
	header.text = "STATO LEGALE"
	header.add_theme_font_size_override("font_size", 11)
	header.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(header)

	_crime_status_label = Label.new()
	_crime_status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_crime_status_label)

	_crime_record_label = Label.new()
	_crime_record_label.add_theme_font_size_override("font_size", 9)
	_crime_record_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_crime_record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_crime_record_label)

	var close_hint: Node = vbox.get_node_or_null("CloseHint")
	if close_hint:
		var idx: int = close_hint.get_index()
		vbox.move_child(header, idx)
		vbox.move_child(_crime_status_label, idx + 1)
		vbox.move_child(_crime_record_label, idx + 2)


func _setup_class_section() -> void:
	var vbox: VBoxContainer = $Panel/Margin/VBox

	_class_label = Label.new()
	_class_label.add_theme_font_size_override("font_size", 11)
	_class_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.55))

	_special_label = Label.new()
	_special_label.add_theme_font_size_override("font_size", 9)
	_special_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	_special_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var sep := HSeparator.new()

	vbox.add_child(_class_label)
	vbox.move_child(_class_label, 0)
	vbox.add_child(_special_label)
	vbox.move_child(_special_label, 1)
	vbox.add_child(sep)
	vbox.move_child(sep, 2)


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
	# Classe corrente
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if reg and _class_label:
		var cd: Dictionary = reg.call("get_class_data", GameState.current_class)
		_class_label.text   = LocaleManager.t("UI_STATUS_CLASS_TIER", {"class": str(cd.get("name", "?")), "tier": int(cd.get("tier", 1))})
		_special_label.text = LocaleManager.t("UI_STATUS_SPECIAL_ABILITY", {"key": str(cd.get("special_name", "")), "name": str(cd.get("special_desc", ""))})

	var attrs: Dictionary = GameState.effective_attributes
	_str_label.text = LocaleManager.t("UI_STATUS_ATTR_LINE", {"attr": LocaleManager.t("ATTR_STR"), "value": int(attrs.get("str", 0))})
	_dex_label.text = LocaleManager.t("UI_STATUS_ATTR_LINE", {"attr": LocaleManager.t("ATTR_DEX"), "value": int(attrs.get("dex", 0))})
	_int_label.text = LocaleManager.t("UI_STATUS_ATTR_LINE", {"attr": LocaleManager.t("ATTR_INT"), "value": int(attrs.get("int", 0))})
	_vit_label.text = LocaleManager.t("UI_STATUS_ATTR_LINE", {"attr": LocaleManager.t("ATTR_VIT"), "value": int(attrs.get("vit", 0))})
	_wil_label.text = LocaleManager.t("UI_STATUS_ATTR_LINE", {"attr": LocaleManager.t("ATTR_WIL"), "value": int(attrs.get("wil", 0))})

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

	_atk_label.text = LocaleManager.t("UI_STATUS_ATTACK_LINE", {"total": base_atk + equip_atk, "base": base_atk, "equip": equip_atk})
	_def_label.text = LocaleManager.t("UI_STATUS_DEFENSE_LINE", {"total": base_def + equip_def, "base": base_def, "equip": equip_def})

	_atk_label.tooltip_text = _build_tooltip(Equipment.get_attack_bonus_breakdown(), LocaleManager.t("UI_STATUS_STAT_ATK"))
	_def_label.tooltip_text = _build_tooltip(Equipment.get_defense_bonus_breakdown(), LocaleManager.t("UI_STATUS_STAT_DEF"))

	var lv: int      = GameState.level
	var xp_next: int = LevelSystem.xp_for_next_level(lv)
	_level_label.text = LocaleManager.t("UI_STATUS_LEVEL", {"level": lv})
	_xp_bar.max_value = maxf(1.0, float(xp_next))
	_xp_bar.value     = GameState.xp
	if lv >= LevelSystem.MAX_LEVEL:
		_xp_val.text = LocaleManager.t("UI_STATUS_MAX_LEVEL")
	else:
		_xp_val.text = LocaleManager.t("UI_STATUS_XP", {"current": GameState.xp, "max": xp_next})

	_refresh_crime_section()


func _refresh_crime_section() -> void:
	if _crime_status_label == null:
		return
	var city_id: String = GameState.current_city_id
	var is_wanted: bool = city_id != "" and CrimeSystem.is_crime_active(city_id)
	if is_wanted:
		_crime_status_label.text = LocaleManager.t_or("UI_STATUS_WANTED", "Ricercato in questa città")
		_crime_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))
	else:
		_crime_status_label.text = LocaleManager.t_or("UI_STATUS_CLEAN", "Nessun mandato attivo")
		_crime_status_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.45))

	var record: Array = CrimeSystem.get_criminal_record()
	if record.is_empty():
		_crime_record_label.text = LocaleManager.t_or("UI_STATUS_CLEAN_RECORD", "Fedina penale: pulita")
	else:
		var lines: Array[String] = [LocaleManager.t_or("UI_STATUS_ARREST_HEADER", "Arresti precedenti:")]
		for entry: Variant in record:
			var e: Dictionary = entry as Dictionary
			lines.append("  • " + LocaleManager.t_or("UI_STATUS_ARREST_ENTRY",
				str(e.get("city_name", e.get("city_id", "?"))),
				{"city": str(e.get("city_name", e.get("city_id", "?")))}))
		_crime_record_label.text = "\n".join(lines)


func _build_tooltip(breakdown: Array, stat_name: String) -> String:
	if breakdown.is_empty():
		return LocaleManager.t("UI_STATUS_EQUIP_BONUS_NONE")
	var lines: Array[String] = [LocaleManager.t("UI_STATUS_EQUIP_BONUS_HEADER", {"attr": stat_name})]
	for entry: Variant in breakdown:
		var e: Dictionary = entry as Dictionary
		lines.append(LocaleManager.t("UI_STATUS_EQUIP_BONUS_LINE", {"amount": int(e["bonus"]), "source": str(e["name"])}))
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
