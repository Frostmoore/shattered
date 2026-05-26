class_name HUDOptionsPanel
extends Control

const _FONT_BOLD: String = "res://assets/fonts/Roboto-Bold.ttf"
const _FONT_REG:  String = "res://assets/fonts/Roboto-Regular.ttf"

var _mode_option:  OptionButton = null
var _cb_status:    CheckBox     = null
var _cb_quest:     CheckBox     = null
var _cb_minimap:   CheckBox     = null
var _cb_worldinfo: CheckBox     = null
var _cb_needs:     CheckBox     = null

var _block_signals: bool = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var font_bold: Font = load(_FONT_BOLD)
	var font_reg:  Font = load(_FONT_REG)

	var panel := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color     = Color(0.10, 0.10, 0.12, 0.97)
	bg_style.border_color = Color(0.75, 0.62, 0.20, 0.80)
	bg_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", bg_style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(210.0, 0.0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Titolo
	var title := Label.new()
	title.text = "Opzioni HUD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font_bold)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Modalità UI
	var mode_lbl := Label.new()
	mode_lbl.text = "Modalità UI"
	mode_lbl.add_theme_font_override("font", font_reg)
	mode_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(mode_lbl)

	_mode_option = OptionButton.new()
	_mode_option.add_item("Info")
	_mode_option.add_item("Style")
	_mode_option.add_theme_font_override("font", font_reg)
	_mode_option.add_theme_font_size_override("font_size", 11)
	_mode_option.item_selected.connect(_on_mode_selected)
	vbox.add_child(_mode_option)

	vbox.add_child(HSeparator.new())

	# Toggle pannelli
	_cb_status    = _make_checkbox("Pannello status",   vbox, font_reg)
	_cb_quest     = _make_checkbox("Quest tracker",     vbox, font_reg)
	_cb_minimap   = _make_checkbox("Minimappa",         vbox, font_reg)
	_cb_worldinfo = _make_checkbox("Info mondo",        vbox, font_reg)
	_cb_needs     = _make_checkbox("Bisogni (F/A/E/T)", vbox, font_reg)

	_cb_status.toggled.connect(   func(v: bool): _on_bool_toggled("hud_show_status",    v))
	_cb_quest.toggled.connect(    func(v: bool): _on_bool_toggled("hud_show_quest",     v))
	_cb_minimap.toggled.connect(  func(v: bool): _on_bool_toggled("hud_show_minimap",   v))
	_cb_worldinfo.toggled.connect(func(v: bool): _on_bool_toggled("hud_show_worldinfo", v))
	_cb_needs.toggled.connect(    func(v: bool): _on_bool_toggled("hud_show_needs",     v))

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Chiudi"
	close_btn.add_theme_font_override("font", font_reg)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func(): hide())
	vbox.add_child(close_btn)


func _make_checkbox(label: String, parent: Control, font: Font) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label
	cb.add_theme_font_override("font", font)
	cb.add_theme_font_size_override("font_size", 11)
	parent.add_child(cb)
	return cb


# ── API pubblica ──────────────────────────────────────────────────────────────

func refresh() -> void:
	_block_signals = true
	_mode_option.selected = 0 if SettingsManager.hud_ui_mode == "info" else 1
	_cb_status.button_pressed    = SettingsManager.hud_show_status
	_cb_quest.button_pressed     = SettingsManager.hud_show_quest
	_cb_minimap.button_pressed   = SettingsManager.hud_show_minimap
	_cb_worldinfo.button_pressed = SettingsManager.hud_show_worldinfo
	_cb_needs.button_pressed     = SettingsManager.hud_show_needs
	_block_signals = false


# ── Handler ───────────────────────────────────────────────────────────────────

func _on_mode_selected(idx: int) -> void:
	if _block_signals:
		return
	SettingsManager.hud_ui_mode = "info" if idx == 0 else "style"
	SettingsManager.save_settings()
	EventBus.settings_changed.emit()


func _on_bool_toggled(field: String, value: bool) -> void:
	if _block_signals:
		return
	SettingsManager.set(field, value)
	SettingsManager.save_settings()
	EventBus.settings_changed.emit()
