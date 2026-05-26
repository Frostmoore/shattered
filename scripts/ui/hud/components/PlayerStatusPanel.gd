class_name PlayerStatusPanel
extends PanelContainer

# ── Node refs (costruiti programmaticamente in _build_ui) ─────────────────────
var _name_lbl:  Label       = null
var _class_lbl: Label       = null
var _xp_bar:    ProgressBar = null
var _hp_bar:    ResourceBar = null
var _mp_bar:    ResourceBar = null
var _st_bar:    ResourceBar = null
var _food_lbl:  Label          = null
var _water_lbl: Label          = null
var _exh_lbl:   Label          = null
var _temp_lbl:  Label          = null
var _needs_box: HBoxContainer  = null

const _FONT_BOLD:   String = "res://assets/fonts/Roboto-Bold.ttf"
const _FONT_REG:    String = "res://assets/fonts/Roboto-Regular.ttf"
const _FONT_MED:    String = "res://assets/fonts/Roboto-Medium.ttf"


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# ── Panel style ──────────────────────────────────────────────────────────
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.10, 0.12, 0.93)
	panel_style.border_color = Color(0.75, 0.62, 0.20, 0.80)
	panel_style.set_border_width_all(0)
	panel_style.border_width_bottom = 1
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top",   2)
	margin.add_theme_constant_override("margin_bottom",2)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# ── Nome + XP bar ────────────────────────────────────────────────────────
	var name_block := VBoxContainer.new()
	name_block.add_theme_constant_override("separation", 1)
	hbox.add_child(name_block)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_block.add_child(name_row)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_override("font", load(_FONT_BOLD))
	_name_lbl.add_theme_font_size_override("font_size", 12)
	_name_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	name_row.add_child(_name_lbl)

	var sep := Label.new()
	sep.text = "·"
	sep.add_theme_font_size_override("font_size", 12)
	sep.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	name_row.add_child(sep)

	_class_lbl = Label.new()
	_class_lbl.add_theme_font_override("font", load(_FONT_REG))
	_class_lbl.add_theme_font_size_override("font_size", 11)
	_class_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	name_row.add_child(_class_lbl)

	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 3)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.max_value = 100.0
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.784, 0.659, 0.125)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.04, 0.04, 0.06, 1.0)
	_xp_bar.add_theme_stylebox_override("background", xp_bg)
	name_block.add_child(_xp_bar)

	# ── HP / MP / ST bars ────────────────────────────────────────────────────
	_hp_bar = ResourceBar.new()
	_hp_bar.bar_color = Color(0.745, 0.102, 0.102)
	hbox.add_child(_hp_bar)

	_mp_bar = ResourceBar.new()
	_mp_bar.bar_color = Color(0.102, 0.322, 0.784)
	hbox.add_child(_mp_bar)

	_st_bar = ResourceBar.new()
	_st_bar.bar_color = Color(0.784, 0.494, 0.063)
	hbox.add_child(_st_bar)

	# ── Needs (F / A / E / T°) ───────────────────────────────────────────────
	_needs_box = HBoxContainer.new()
	_needs_box.add_theme_constant_override("separation", 4)
	hbox.add_child(_needs_box)

	_food_lbl  = _make_needs_lbl("F")
	_water_lbl = _make_needs_lbl("A")
	_exh_lbl   = _make_needs_lbl("E")
	_temp_lbl  = _make_needs_lbl("0°")
	_needs_box.add_child(_food_lbl)
	_needs_box.add_child(_water_lbl)
	_needs_box.add_child(_exh_lbl)
	_needs_box.add_child(_temp_lbl)


func _make_needs_lbl(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", load(_FONT_MED))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.82, 0.35))
	return lbl


# ── API pubblica ──────────────────────────────────────────────────────────────

func refresh() -> void:
	_name_lbl.text  = GameState.character_name
	_class_lbl.text = ClassRegistry.get_display_name(GameState.current_class) \
					  + " Lv" + str(GameState.level)
	_xp_bar.value   = LevelSystem.get_xp_progress() * 100.0
	_hp_bar.set_value(
		float(GameState.player_stats.get("hp",      0)),
		float(GameState.player_stats.get("max_hp",  1)))
	_mp_bar.set_value(
		float(GameState.player_stats.get("mp",      0)),
		float(GameState.player_stats.get("max_mp",  1)))
	_st_bar.set_value(
		float(GameState.player_stats.get("stamina",     0)),
		float(GameState.player_stats.get("max_stamina", 1)))


func refresh_needs() -> void:
	_food_lbl.add_theme_color_override( "font_color", _color_food(GameState.food))
	_water_lbl.add_theme_color_override("font_color", _color_food(GameState.water))
	_exh_lbl.add_theme_color_override(  "font_color", _color_exh(GameState.exhaustion))
	var t: float = GameState.temperature
	_temp_lbl.text = ("%+.0f°" % t) if t != 0.0 else "0°"
	_temp_lbl.add_theme_color_override("font_color", _color_temp(t))


func apply_ui_mode(mode: String) -> void:
	_hp_bar.apply_ui_mode(mode)
	_mp_bar.apply_ui_mode(mode)
	_st_bar.apply_ui_mode(mode)


func set_needs_visible(v: bool) -> void:
	_needs_box.visible = v


# ── Colori needs ──────────────────────────────────────────────────────────────

func _color_food(val: float) -> Color:
	if val >= 60.0: return Color(0.35, 0.82, 0.35)
	if val >= 30.0: return Color(0.90, 0.75, 0.20)
	return Color(0.90, 0.25, 0.25)


func _color_exh(val: float) -> Color:
	if val < 30.0: return Color(0.35, 0.82, 0.35)
	if val < 70.0: return Color(0.90, 0.75, 0.20)
	return Color(0.90, 0.25, 0.25)


func _color_temp(val: float) -> Color:
	if val <= -10.0: return Color(0.40, 0.70, 1.00)
	if val <=  -2.0: return Color(0.70, 0.85, 1.00)
	if val <    2.0: return Color(0.82, 0.82, 0.82)
	if val <=  10.0: return Color(0.90, 0.75, 0.20)
	return Color(0.90, 0.25, 0.25)
