class_name MessageLog
extends Control

const PASSIVE_LIFETIME := 5.0
const EXPANDED_HEIGHT  := 120.0
const LOG_CAPACITY     := 40

const _FONT_REG: String = "res://assets/fonts/Roboto-Regular.ttf"

var _passive_lbl:  RichTextLabel = null
var _expand_panel: Panel         = null
var _expand_rtl:   RichTextLabel = null
var _fade_timer:   float = 0.0
var _expanded:     bool  = false
var _log_entries:  Array = []   # [{text, cat}] — plain dict, no typed array issues


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	var font: Font = load(_FONT_REG)

	# ── Riga passiva (riempie tutto il control) ──────────────────────────────
	_passive_lbl = RichTextLabel.new()
	_passive_lbl.name = "PassiveLabel"
	_passive_lbl.bbcode_enabled = true
	_passive_lbl.fit_content = true
	_passive_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_passive_lbl.add_theme_font_override("normal_font", font)
	_passive_lbl.add_theme_font_size_override("normal_font_size", 12)
	_passive_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_passive_lbl)

	# ── Pannello espanso (bottom edge = y=0 del MessageLog, cresce verso l'alto) ──
	_expand_panel = Panel.new()
	_expand_panel.name = "ExpandPanel"
	_expand_panel.anchor_left   = 0.0
	_expand_panel.anchor_right  = 1.0
	_expand_panel.anchor_top    = 0.0
	_expand_panel.anchor_bottom = 0.0
	_expand_panel.offset_top    = 0.0
	_expand_panel.offset_bottom = 0.0
	_expand_panel.clip_contents = true
	_expand_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var expand_style := StyleBoxFlat.new()
	expand_style.bg_color = Color(0.08, 0.08, 0.10, 0.94)
	expand_style.border_color = Color(0.75, 0.62, 0.20, 0.60)
	expand_style.set_border_width_all(1)
	_expand_panel.add_theme_stylebox_override("panel", expand_style)

	_expand_rtl = RichTextLabel.new()
	_expand_rtl.name = "ExpandRTL"
	_expand_rtl.bbcode_enabled = true
	_expand_rtl.fit_content = false
	_expand_rtl.scroll_active = true
	_expand_rtl.scroll_following = true
	_expand_rtl.anchor_left   = 0.0
	_expand_rtl.anchor_right  = 1.0
	_expand_rtl.anchor_top    = 0.0
	_expand_rtl.anchor_bottom = 1.0
	_expand_rtl.offset_left   = 4.0
	_expand_rtl.offset_right  = -4.0
	_expand_rtl.offset_top    = 4.0
	_expand_rtl.offset_bottom = -4.0
	_expand_rtl.add_theme_font_override("normal_font", font)
	_expand_rtl.add_theme_font_size_override("normal_font_size", 12)
	_expand_rtl.add_theme_color_override("default_color", Color(0.92, 0.92, 0.92, 1.0))
	_expand_panel.add_child(_expand_rtl)

	add_child(_expand_panel)


# ── API pubblica ──────────────────────────────────────────────────────────────

func show_entry(entry: HUDState.LogEntry, color: Color) -> void:
	_log_entries.append({"text": entry.text, "cat": entry.category})
	if _log_entries.size() > LOG_CAPACITY:
		_log_entries.pop_front()
	_passive_lbl.clear()
	_passive_lbl.push_color(color)
	_passive_lbl.add_text(entry.text)
	_passive_lbl.pop()
	_fade_timer = PASSIVE_LIFETIME
	_passive_lbl.modulate.a = 1.0


func open_expanded() -> void:
	_expanded = true
	_expand_rtl.clear()
	for e in _log_entries:
		var t: String = str(e.get("text", ""))
		var c: int    = int(e.get("cat", 0))
		_expand_rtl.push_color(HUDState.get_color(c))
		_expand_rtl.add_text(t + "\n")
		_expand_rtl.pop()
	var tw := create_tween()
	tw.tween_property(_expand_panel, "offset_top", -EXPANDED_HEIGHT, 0.15)


func close_expanded() -> void:
	_expanded = false
	var tw := create_tween()
	tw.tween_property(_expand_panel, "offset_top", 0.0, 0.15)


# ── Update loop ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _expanded:
		return
	if _fade_timer > 0.0:
		_fade_timer -= delta
		if _fade_timer <= 0.5:
			_passive_lbl.modulate.a = maxf(0.0, _fade_timer / 0.5)


# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not _expanded:
			open_expanded()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _expanded:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			close_expanded()
			get_viewport().set_input_as_handled()
