class_name ActionBar
extends HBoxContainer

signal use_item_requested()
signal open_menu_requested()

const WAIT_HOLD_THRESHOLD := 0.4
const _FONT_BOLD: String = "res://assets/fonts/Roboto-Bold.ttf"
const _FONT_REG:  String = "res://assets/fonts/Roboto-Regular.ttf"

var _in_combat: bool = false
var _wait_btn_held: bool = false
var _wait_held_time: float = 0.0
var _flee_btn: Button = null


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_build_ui()


func _build_ui() -> void:
	_make_action_btn("↻", "R",
		LocaleManager.t_or("UI_HUD_ACTION_WAIT", "Aspetta"),
		_on_wait_pressed, _on_wait_released)
	_flee_btn = _make_action_btn("↗", "F",
		LocaleManager.t_or("UI_HUD_ACTION_FLEE", "Fuggi"),
		_on_flee_pressed, null)
	_flee_btn.visible = false
	_make_action_btn("⊞", "I",
		LocaleManager.t_or("UI_HUD_ACTION_INVENTORY", "Inventario"),
		func(): use_item_requested.emit(), null)
	_make_action_btn("≡", "Esc",
		LocaleManager.t_or("UI_HUD_ACTION_MENU", "Menu"),
		func(): open_menu_requested.emit(), null)


func _make_action_btn(icon: String, key: String, label: String,
		on_press: Callable, on_release) -> Button:
	var font_bold: Font = load(_FONT_BOLD)
	var font_reg:  Font = load(_FONT_REG)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(36, 0)
	btn.focus_mode = Control.FOCUS_NONE

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.10, 0.10, 0.12, 0.9)
	btn_style.border_color = Color(0.50, 0.42, 0.14, 0.5)
	btn_style.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.16, 0.16, 0.18, 0.9)
	hover_style.border_color = Color(0.75, 0.62, 0.20, 0.9)
	hover_style.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_override("font", font_bold)
	icon_lbl.add_theme_font_size_override("font_size", 14)
	icon_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_lbl)

	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.add_theme_font_override("font", font_reg)
	key_lbl.add_theme_font_size_override("font_size", 9)
	key_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(key_lbl)

	btn.add_child(vbox)
	btn.tooltip_text = label

	btn.button_down.connect(on_press)
	if on_release != null:
		btn.button_up.connect(on_release)

	add_child(btn)
	return btn


func _process(delta: float) -> void:
	if _wait_btn_held:
		_wait_held_time += delta
		if _wait_held_time >= WAIT_HOLD_THRESHOLD:
			_wait_btn_held = false
			_open_wait_screen()


func _on_wait_pressed() -> void:
	_wait_held_time = 0.0
	_wait_btn_held = true


func _on_wait_released() -> void:
	if _wait_btn_held:
		_wait_btn_held = false
		_on_quick_wait()


func _on_quick_wait() -> void:
	var map: BaseMap = WorldManager.get_current_map()
	if map != null:
		TimeManager.advance(TimeManager.get_action_cost(map.map_type, 4))
	TurnManager.on_player_action_done()


func _on_flee_pressed() -> void:
	if not _in_combat:
		return
	var map: BaseMap = WorldManager.get_current_map()
	if map == null:
		return
	var player = map.get_player()
	if player != null:
		player.flee_attempt()


func _open_wait_screen() -> void:
	var ws = get_node_or_null("/root/Main/WaitScreen")
	if ws != null:
		ws.show()


func set_combat_mode(in_combat: bool) -> void:
	_in_combat = in_combat
	if _flee_btn != null:
		_flee_btn.visible = in_combat


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_wait"):
		_on_wait_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("action_wait"):
		_on_wait_released()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("action_flee") and _in_combat:
		_on_flee_pressed()
		get_viewport().set_input_as_handled()
