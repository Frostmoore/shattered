extends PanelContainer
class_name ClassCard

signal hovered(class_data: Dictionary)
signal unhovered()
signal card_pressed(class_data: Dictionary)

const TIER_COLORS: Array[Color] = [
	Color.TRANSPARENT,
	Color(0.38, 0.38, 0.38),   # Tier 1 — grigio
	Color(0.16, 0.50, 0.26),   # Tier 2 — verde
	Color(0.13, 0.30, 0.60),   # Tier 3 — blu
	Color(0.40, 0.16, 0.56),   # Tier 4 — viola
	Color(0.70, 0.26, 0.10),   # Tier 5 — arancione
	Color(0.62, 0.52, 0.06),   # Tier 6 — oro
]

const CARD_SIZE := Vector2(70, 70)

var class_data: Dictionary = {}

var _style: StyleBoxFlat
var _is_selected: bool = false


func setup(data: Dictionary) -> void:
	class_data = data


func _ready() -> void:
	if class_data.is_empty():
		return

	custom_minimum_size = CARD_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var tier: int = clampi(int(class_data.get("tier", 1)), 1, 6)
	_style = StyleBoxFlat.new()
	_style.bg_color      = TIER_COLORS[tier]
	_style.border_color  = TIER_COLORS[tier].lightened(0.35)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(4)
	_style.content_margin_left   = 4.0
	_style.content_margin_right  = 4.0
	_style.content_margin_top    = 6.0
	_style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", _style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	var letter_lbl := Label.new()
	letter_lbl.text = str(class_data.get("name", "?")).substr(0, 1).to_upper()
	letter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_lbl.add_theme_font_size_override("font_size", 20)
	letter_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(letter_lbl)

	var name_lbl := Label.new()
	name_lbl.text = _short(str(class_data.get("name", "")), 9)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	mouse_entered.connect(func() -> void: hovered.emit(class_data))
	mouse_exited.connect(func() -> void: unhovered.emit())
	gui_input.connect(_on_gui_input)


func set_selected(value: bool) -> void:
	_is_selected = value
	if not _style:
		return
	if _is_selected:
		_style.border_color = Color.WHITE
		_style.set_border_width_all(3)
	else:
		var tier: int = clampi(int(class_data.get("tier", 1)), 1, 6)
		_style.border_color = TIER_COLORS[tier].lightened(0.35)
		_style.set_border_width_all(2)


func get_class_id() -> String:
	return str(class_data.get("id", ""))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			card_pressed.emit(class_data)


func _short(text: String, max_len: int) -> String:
	return text if text.length() <= max_len else text.substr(0, max_len - 1) + "."
