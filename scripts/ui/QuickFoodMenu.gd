extends CanvasLayer

const PANEL_COLOR  := Color(0.06, 0.06, 0.10, 0.97)
const BORDER_COLOR := Color(0.25, 0.35, 0.55, 1.0)
const SEL_COLOR    := Color(1.00, 0.85, 0.30)
const NORMAL_COLOR := Color(0.80, 0.80, 0.80)

var _items:        Array = []   # [{id, name, qty}]
var _selected_idx: int   = 0
var _vbox:         VBoxContainer


func _ready() -> void:
	layer   = 15
	visible = false
	_build_ui()


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(240, 0)
	center.add_child(panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(_vbox)


func open() -> void:
	_populate()
	_selected_idx = 0
	_rebuild_list()
	visible = true


func _populate() -> void:
	_items = []
	for entry: Variant in GameState.inventory:
		var e: Dictionary = entry as Dictionary
		if e.has("instance_id"):
			continue
		var item_id: String = e.get("id", "")
		if item_id == "":
			continue
		var item_data: Dictionary = ItemDB.get_item(item_id)
		var eff: Dictionary = item_data.get("effect", {}) as Dictionary
		var eff_type: String = str(eff.get("type", ""))
		if eff_type not in ["needs", "disease_cure", "disease_cure_by_item"]:
			continue
		_items.append({
			"id":   item_id,
			"name": ItemDB.get_display_name(item_id),
			"qty":  int(e.get("qty", 1)),
		})


func _rebuild_list() -> void:
	for c: Node in _vbox.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = LocaleManager.t("UI_NEEDS_MENU_TITLE")
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.add_theme_font_size_override("font_size", 11)
	_vbox.add_child(title)
	_vbox.add_child(HSeparator.new())

	if _items.is_empty():
		var empty := Label.new()
		empty.text = LocaleManager.t("UI_NEEDS_MENU_EMPTY")
		empty.add_theme_font_size_override("font_size", 11)
		_vbox.add_child(empty)
	else:
		for i: int in _items.size():
			var it: Dictionary = _items[i]
			var lbl := Label.new()
			lbl.text = "%d. %s  (x%d)" % [i + 1, str(it["name"]), int(it["qty"])]
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override(
				"font_color", SEL_COLOR if i == _selected_idx else NORMAL_COLOR)
			_vbox.add_child(lbl)

	_vbox.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = LocaleManager.t("UI_NEEDS_MENU_HINT")
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	hint.add_theme_font_size_override("font_size", 10)
	_vbox.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	match ke.keycode:
		KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_use_selected()
			get_viewport().set_input_as_handled()
		KEY_UP:
			if not _items.is_empty():
				_selected_idx = wrapi(_selected_idx - 1, 0, _items.size())
				_rebuild_list()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			if not _items.is_empty():
				_selected_idx = wrapi(_selected_idx + 1, 0, _items.size())
				_rebuild_list()
			get_viewport().set_input_as_handled()
		_:
			var num: int = ke.keycode - KEY_1
			if num >= 0 and num < _items.size():
				_selected_idx = num
				_use_selected()
				get_viewport().set_input_as_handled()


func _use_selected() -> void:
	if _items.is_empty() or _selected_idx >= _items.size():
		return
	Inventory.use_item((_items[_selected_idx] as Dictionary).get("id", ""))
	close()


func close() -> void:
	visible = false
