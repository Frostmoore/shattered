extends CanvasLayer

const PANEL_COLOR  := Color(0.07, 0.07, 0.12, 0.97)
const BORDER_COLOR := Color(0.30, 0.40, 0.60, 1.0)
const CELL_SIZE    := 40
const GRID_COLS    := 6

var _drops:         Array          = []
var _source_label:  String         = ""
var _cells:         Array          = []
var _grid:          GridContainer
var _title_lbl:     Label
var _tooltip_panel: PanelContainer
var _tooltip_lbl:   RichTextLabel


func _ready() -> void:
	layer   = 80
	visible = false
	_build_ui()
	EventBus.loot_screen_open.connect(_on_open)


func _on_open(drops: Array, source_label: String) -> void:
	_drops        = drops.duplicate(true)
	_source_label = source_label
	_refresh()
	visible = true
	_set_player_blocked(true)


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(CELL_SIZE * GRID_COLS + 60, 240)
	panel.anchor_left   = 0.5; panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left   = -panel.size.x / 2.0
	panel.offset_right  =  panel.size.x / 2.0
	panel.offset_top    = -panel.size.y / 2.0
	panel.offset_bottom =  panel.size.y / 2.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_title_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(_title_lbl)

	vbox.add_child(HSeparator.new())

	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_grid)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var take_all_btn := Button.new()
	take_all_btn.text = LocaleManager.t("UI_LOOT_TAKE_ALL")
	take_all_btn.add_theme_font_size_override("font_size", 11)
	take_all_btn.pressed.connect(_take_all)
	btn_row.add_child(take_all_btn)

	var close_btn := Button.new()
	close_btn.text = LocaleManager.t("UI_LOOT_CLOSE")
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(_close)
	btn_row.add_child(close_btn)

	# Custom tooltip panel (matches InventoryPanel style)
	_tooltip_panel = PanelContainer.new()
	var tt_style := StyleBoxFlat.new()
	tt_style.bg_color        = Color(0.06, 0.06, 0.10, 0.97)
	tt_style.border_color    = Color(0.30, 0.40, 0.60, 1.0)
	tt_style.set_border_width_all(1)
	tt_style.set_corner_radius_all(3)
	tt_style.content_margin_left   = 8.0
	tt_style.content_margin_right  = 8.0
	tt_style.content_margin_top    = 5.0
	tt_style.content_margin_bottom = 5.0
	_tooltip_panel.add_theme_stylebox_override("panel", tt_style)
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_lbl = RichTextLabel.new()
	_tooltip_lbl.add_theme_font_size_override("normal_font_size", 11)
	_tooltip_lbl.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	_tooltip_lbl.bbcode_enabled = true
	_tooltip_lbl.fit_content = true
	_tooltip_lbl.scroll_active = false
	_tooltip_lbl.custom_minimum_size = Vector2(200.0, 0.0)
	_tooltip_panel.add_child(_tooltip_lbl)
	add_child(_tooltip_panel)


func _refresh() -> void:
	_title_lbl.text = _source_label if _source_label != "" else LocaleManager.t("UI_LOOT_TITLE")

	# Clear old cells
	for c: Variant in _cells:
		if is_instance_valid(c as Node):
			(c as Node).queue_free()
	_cells.clear()

	# Build cells for each drop
	for i: int in _drops.size():
		var drop: Dictionary = _drops[i]
		var btn: Button = _make_cell(drop, i)
		_grid.add_child(btn)
		_cells.append(btn)


func _make_cell(drop: Dictionary, idx: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	btn.focus_mode = Control.FOCUS_NONE

	var icon_char: String
	var quality_col: Color

	if str(drop.get("type", "")) == "gold":
		icon_char   = "$"
		quality_col = Color(1.0, 0.8, 0.0)
	else:
		var base_id: String  = str(drop.get("base_id", ""))
		var base: Dictionary = ItemDB.get_item(base_id)
		var quality: String  = str(drop.get("quality", "normale"))
		quality_col = ItemGenerator.get_quality_color(quality)
		icon_char = str(base.get("icon", "?"))

	var drop_ref := drop
	btn.mouse_entered.connect(func() -> void: _show_drop_tooltip(drop_ref))
	btn.mouse_exited.connect(func() -> void: _hide_tooltip())

	# Style the cell
	var style := StyleBoxFlat.new()
	style.bg_color = quality_col.darkened(0.65)
	style.border_color = quality_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left  = 4.0; style.content_margin_right  = 4.0
	style.content_margin_top   = 4.0; style.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = quality_col.darkened(0.4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var lbl := Label.new()
	lbl.text = icon_char
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", quality_col)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	btn.add_child(lbl)

	btn.pressed.connect(_take_index.bind(idx))
	return btn


func _take_index(idx: int) -> void:
	if idx < 0 or idx >= _drops.size():
		return
	var drop: Dictionary = _drops[idx]
	_give_drop_to_player(drop)
	_drops[idx] = {}  # mark as taken
	# Disable cell
	if idx < _cells.size() and is_instance_valid(_cells[idx] as Node):
		(_cells[idx] as Button).disabled = true
		(_cells[idx] as Button).modulate = Color(0.35, 0.35, 0.35, 0.5)


func _take_all() -> void:
	for drop: Variant in _drops:
		var d: Dictionary = drop as Dictionary
		if not d.is_empty():
			_give_drop_to_player(d)
	_close()


func _give_drop_to_player(drop: Dictionary) -> void:
	if str(drop.get("type", "")) == "gold":
		var amount: int = int(drop.get("amount", 0))
		GameState.player_stats["gold"] = int(GameState.player_stats.get("gold", 0)) + amount
		EventBus.player_stats_changed.emit()
		EventBus.combat_log.emit(LocaleManager.t("UI_LOOT_GOLD_LOG", {"amount": amount}))
	else:
		# Auto-identify if player has enough INT+WIL
		var instance: Dictionary = drop
		if not bool(instance.get("identified", false)):
			var ea: Dictionary = GameState.effective_attributes
			var int_wil: int   = int(ea.get("int", 0)) + int(ea.get("wil", 0))
			var threshold: int = ItemGenerator.get_id_threshold(str(instance.get("quality", "normale")))
			if int_wil >= threshold:
				instance = ItemGenerator.identify(instance, GameState.level)
		Inventory.add_item_instance(instance)


func _close() -> void:
	visible = false
	var remaining: Array = []
	for d: Variant in _drops:
		var drop: Dictionary = d as Dictionary
		if not drop.is_empty():
			remaining.append(drop)
	_drops.clear()
	_hide_tooltip()
	_set_player_blocked(false)
	EventBus.loot_screen_closed.emit(remaining)


func _show_drop_tooltip(drop: Dictionary) -> void:
	var bbcode: String
	if str(drop.get("type", "")) == "gold":
		bbcode = ItemTooltipBuilder.build_gold(int(drop.get("amount", 0)))
	else:
		bbcode = ItemTooltipBuilder.build_instance(drop)
	_tooltip_lbl.text = bbcode
	_tooltip_panel.visible = true


func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.visible = false


func _process(_delta: float) -> void:
	if not _tooltip_panel.visible:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var mp: Vector2 = get_viewport().get_mouse_position()
	var pos: Vector2 = mp + Vector2(14.0, 14.0)
	if _tooltip_panel.size.x > 0.0:
		if pos.x + _tooltip_panel.size.x > vp.x:
			pos.x = mp.x - _tooltip_panel.size.x - 14.0
		if pos.y + _tooltip_panel.size.y > vp.y:
			pos.y = mp.y - _tooltip_panel.size.y - 14.0
	_tooltip_panel.position = pos


func _set_player_blocked(blocked: bool) -> void:
	var map: Node = WorldManager.get_current_map()
	if map == null:
		return
	var player: Node = map.call("get_player") if map.has_method("get_player") else null
	if player == null:
		return
	player.set("_can_act", not blocked)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
