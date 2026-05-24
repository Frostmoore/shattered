extends CanvasLayer
# Mini-menu modale per la scelta del tipo di elementale (Evocatore).
# Si aggiunge come figlio di ClassRuntime.
# Alla scelta/annullamento: chiama ClassRuntime.confirm_menu() o cancel_menu() e si libera.

const PANEL_W: float = 230.0
const PANEL_H: float = 160.0

const TYPES: Array = [
	{
		"id":    "elemental_fire",
		"label": "[1] Fuoco",
		"desc":  "ATK ×1.5, aggressivo",
		"color": Color(1.0, 0.45, 0.1),
	},
	{
		"id":    "elemental_water",
		"label": "[2] Acqua",
		"desc":  "Cura +3 HP/turno player",
		"color": Color(0.25, 0.65, 1.0),
	},
	{
		"id":    "elemental_earth",
		"label": "[3] Terra",
		"desc":  "HP ×3, barriera lenta",
		"color": Color(0.65, 0.48, 0.25),
	},
]

var _on_choice: Callable = Callable()


func _ready() -> void:
	layer = 92
	_build_ui()
	visible = true


func setup(on_choice: Callable) -> void:
	_on_choice = on_choice


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.17, 0.97)
	style.border_color = Color(0.35, 0.55, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = LocaleManager.t("UI_SUMMONER_CHOOSE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.55, 0.80, 1.0))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	for entry: Variant in TYPES:
		var d: Dictionary = entry as Dictionary
		var btn := Button.new()
		var type_id: String = str(d["id"])
		btn.text = "%s — %s" % [str(d["label"]), str(d["desc"])]
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", d["color"] as Color)
		btn.pressed.connect(func() -> void: _choose(type_id))
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	var cancel_btn := Button.new()
	cancel_btn.text = LocaleManager.t("UI_BTN_CANCEL")
	cancel_btn.add_theme_font_size_override("font_size", 10)
	cancel_btn.pressed.connect(_cancel)
	vbox.add_child(cancel_btn)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.is_pressed():
		return
	match ke.keycode:
		KEY_1:
			get_viewport().set_input_as_handled()
			_choose("elemental_fire")
		KEY_2:
			get_viewport().set_input_as_handled()
			_choose("elemental_water")
		KEY_3:
			get_viewport().set_input_as_handled()
			_choose("elemental_earth")
		KEY_ESCAPE, KEY_Q:
			get_viewport().set_input_as_handled()
			_cancel()


func _choose(type_id: String) -> void:
	if _on_choice.is_valid():
		_on_choice.call(type_id)
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if rt:
		rt.call("confirm_menu")
	queue_free()


func _cancel() -> void:
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if rt:
		rt.call("cancel_menu")
	queue_free()
