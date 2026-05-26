extends CanvasLayer
class_name WaitScreen

signal wait_completed

const WAIT_TICK_DELAY: float = 0.08
const MAX_WAIT_HOURS:  int   = 8

var _start_minutes:  int  = 0
var _target_minutes: int  = 0
var _animating:      bool = false

var _from_label:   Label
var _to_label:     Label
var _now_label:    Label
var _hours_slider: HSlider
var _hours_label:  Label
var _wait_btn:     Button
var _cancel_btn:   Button


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.97)
	style.border_color = Color(0.25, 0.35, 0.55, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left   = 14.0
	style.content_margin_right  = 14.0
	style.content_margin_top    = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = LocaleManager.t("UI_WAIT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_from_label = Label.new()
	_from_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_from_label)

	_to_label = Label.new()
	_to_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_to_label)

	_now_label = Label.new()
	_now_label.add_theme_font_size_override("font_size", 11)
	_now_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	_now_label.visible = false
	vbox.add_child(_now_label)

	vbox.add_child(HSeparator.new())

	_hours_slider = HSlider.new()
	_hours_slider.min_value = 1
	_hours_slider.max_value = MAX_WAIT_HOURS
	_hours_slider.step      = 1
	_hours_slider.value     = 1
	_hours_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hours_slider.value_changed.connect(_on_slider_changed)
	vbox.add_child(_hours_slider)

	_hours_label = Label.new()
	_hours_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hours_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_hours_label)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_wait_btn = Button.new()
	_wait_btn.text = LocaleManager.t("UI_WAIT_BTN")
	_wait_btn.pressed.connect(_on_wait_confirmed)
	btn_row.add_child(_wait_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = LocaleManager.t("UI_BTN_CANCEL")
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(_cancel_btn)


func open() -> void:
	_start_minutes         = GameState.total_minutes
	_target_minutes        = _start_minutes + 60
	_animating             = false
	_hours_slider.value    = 1
	_hours_slider.editable = true
	_wait_btn.disabled     = false
	_cancel_btn.disabled   = false
	_now_label.visible     = false
	_update_selection_labels()
	show()


func _update_selection_labels() -> void:
	_from_label.text  = LocaleManager.t("UI_WAIT_FROM") + " " + TimeManager.format_time()
	_to_label.text    = LocaleManager.t("UI_WAIT_TO")   + " " + TimeManager.format_time_from(_target_minutes)
	_hours_label.text = LocaleManager.t("UI_WAIT_HOURS", {"n": str(int(_hours_slider.value))})


func _on_slider_changed(value: float) -> void:
	if _animating:
		return
	_target_minutes   = _start_minutes + int(value) * 60
	_to_label.text    = LocaleManager.t("UI_WAIT_TO")   + " " + TimeManager.format_time_from(_target_minutes)
	_hours_label.text = LocaleManager.t("UI_WAIT_HOURS", {"n": str(int(value))})


func _on_wait_confirmed() -> void:
	_hours_slider.editable = false
	_wait_btn.disabled     = true
	_cancel_btn.disabled   = true
	_animating             = true
	_from_label.text       = LocaleManager.t("UI_WAIT_START") + " " + TimeManager.format_time()
	_now_label.visible     = true
	_run_wait_animation()


func _run_wait_animation() -> void:
	while GameState.total_minutes < _target_minutes:
		var step: int = mini(60, _target_minutes - GameState.total_minutes)
		TimeManager.advance(step)
		_hours_slider.value = float(_target_minutes - GameState.total_minutes) / 60.0
		_now_label.text     = LocaleManager.t("UI_WAIT_NOW") + " " + TimeManager.format_time()
		await get_tree().create_timer(WAIT_TICK_DELAY).timeout
	_finish()


func _finish() -> void:
	_animating     = false
	var hours: int = int(float(_target_minutes - _start_minutes) / 60.0)
	EventBus.notification_shown.emit(Notification.wait_finished(hours, TimeManager.format_time()))
	TurnManager.on_player_action_done()
	hide()
	wait_completed.emit()


func _on_cancel_pressed() -> void:
	if _animating:
		return
	hide()
	wait_completed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
