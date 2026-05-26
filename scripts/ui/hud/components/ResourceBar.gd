class_name ResourceBar
extends PanelContainer

@export var bar_color:          Color = Color(0.745, 0.102, 0.102)
@export var critical_threshold: float = 0.25

var _bar:        ProgressBar    = null
var _value_lbl:  Label          = null
var _fill_style: StyleBoxFlat   = null
var _tween:      Tween          = null
var _pulsing:    bool           = false
var _style_mode: bool           = false   # false=info (label sempre), true=style (label su hover)


func _ready() -> void:
	custom_minimum_size = Vector2(52, 8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_ui()


func _build_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.90)
	panel_style.border_color = Color(0.75, 0.62, 0.20, 0.55)
	panel_style.set_border_width_all(1)
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 7)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = bar_color
	_bar.add_theme_stylebox_override("fill", _fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.04, 0.06, 1.0)
	_bar.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(_bar)

	_value_lbl = Label.new()
	_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_lbl.add_theme_font_size_override("font_size", 10)
	_value_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_value_lbl.add_theme_font_override("font", load("res://assets/fonts/Roboto-Medium.ttf"))
	_value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_lbl.visible = true   # info mode default
	vbox.add_child(_value_lbl)


func set_value(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_bar, "value", current, 0.25).set_ease(Tween.EASE_OUT)
	_value_lbl.text = "%d/%d" % [int(current), int(maximum)]
	var ratio := current / maxf(1.0, maximum)
	if ratio <= critical_threshold and not _pulsing:
		_start_pulse()
	elif ratio > critical_threshold and _pulsing:
		_stop_pulse()


func apply_ui_mode(mode: String) -> void:
	_style_mode = (mode == "style")
	_value_lbl.visible = not _style_mode


func _start_pulse() -> void:
	_pulsing = true


func _stop_pulse() -> void:
	_pulsing = false
	_fill_style.bg_color = bar_color


func _process(_delta: float) -> void:
	if not _pulsing:
		return
	var alpha: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
	_fill_style.bg_color = Color(bar_color.r, bar_color.g, bar_color.b, alpha)


func _on_mouse_entered() -> void:
	if _style_mode:
		_value_lbl.visible = true


func _on_mouse_exited() -> void:
	if _style_mode:
		_value_lbl.visible = false
