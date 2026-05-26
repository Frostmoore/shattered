class_name WorldInfoPanel
extends PanelContainer

const _FONT_REG: String = "res://assets/fonts/Roboto-Regular.ttf"

var _zone_lbl: Label = null
var _time_lbl: Label = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.95)
	panel_style.border_color = Color(0.75, 0.62, 0.20, 0.80)
	panel_style.set_border_width_all(0)
	panel_style.border_width_bottom = 1
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top",   2)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	_zone_lbl = Label.new()
	_zone_lbl.name = "ZoneLabel"
	_zone_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_lbl.add_theme_font_override("font", load(_FONT_REG))
	_zone_lbl.add_theme_font_size_override("font_size", 11)
	_zone_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_zone_lbl.text = "—"
	hbox.add_child(_zone_lbl)

	_time_lbl = Label.new()
	_time_lbl.name = "TimeLabel"
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_lbl.add_theme_font_override("font", load(_FONT_REG))
	_time_lbl.add_theme_font_size_override("font_size", 11)
	_time_lbl.add_theme_color_override("font_color", Color(0.72, 0.60, 0.18))
	hbox.add_child(_time_lbl)


func refresh_zone(map_id: String) -> void:
	if map_id == "":
		_zone_lbl.text = "—"
		return
	var map_data: MapData = LocationRegistry.get_or_generate(map_id)
	if map_data == null:
		_zone_lbl.text = map_id
		return
	var zone_name: String = map_data.metadata.get("name", "")
	if zone_name == "":
		zone_name = LocaleManager.t_or("ZONE_" + map_id.to_upper(), map_id)
	_zone_lbl.text = zone_name


func refresh_time() -> void:
	_time_lbl.text = TimeManager.format_time()
