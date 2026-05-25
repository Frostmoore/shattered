extends CanvasLayer
class_name FactionScreen

const STATE_COLORS: Dictionary = {
	"enemy_sworn": Color(0.85, 0.15, 0.15),
	"hostile":     Color(0.85, 0.45, 0.15),
	"neutral":     Color(0.75, 0.75, 0.75),
	"friendly":    Color(0.40, 0.85, 0.45),
	"allied":      Color(0.30, 0.70, 1.00),
	"trusted":     Color(0.90, 0.80, 0.20),
}

const TABS: Array[Dictionary] = [
	{"id": "civil",    "label": "Civili"},
	{"id": "signoria", "label": "Signorie"},
	{"id": "enemy",    "label": "Nemici"},
]

var _current_tab: int = 0
var _selected_faction_id: String = ""

var _tab_buttons:    Array[Button]    = []
var _list_container: VBoxContainer    = null
var _detail_label:   RichTextLabel    = null


func _ready() -> void:
	layer   = 8
	visible = false
	EventBus.toggle_faction_screen.connect(_on_toggle)
	_build_ui()


func _build_ui() -> void:
	var bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color               = Color(0.06, 0.06, 0.10, 0.97)
	style.content_margin_left    = 16.0
	style.content_margin_right   = 16.0
	style.content_margin_top     = 16.0
	style.content_margin_bottom  = 16.0
	bg.add_theme_stylebox_override("panel", style)
	bg.set_anchor_and_offset(SIDE_LEFT,   0.5, -440.0)
	bg.set_anchor_and_offset(SIDE_RIGHT,  0.5,  440.0)
	bg.set_anchor_and_offset(SIDE_TOP,    0.5, -280.0)
	bg.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  280.0)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	bg.add_child(vbox)

	var title := Label.new()
	title.text = LocaleManager.t_or("UI_FACTIONS_TITLE", "FAZIONI")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	vbox.add_child(title)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	_tab_buttons.clear()
	for i: int in TABS.size():
		var btn := Button.new()
		btn.text = TABS[i]["label"]
		btn.toggle_mode = true
		btn.button_pressed = (i == _current_tab)
		var idx := i
		btn.pressed.connect(func() -> void: _on_tab_pressed(idx))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Left: scrollable faction list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 4)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_container)

	# Right: detail panel
	var detail_panel := PanelContainer.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color              = Color(0.08, 0.08, 0.13, 1.0)
	ds.content_margin_left   = 12.0
	ds.content_margin_right  = 12.0
	ds.content_margin_top    = 10.0
	ds.content_margin_bottom = 10.0
	detail_panel.add_theme_stylebox_override("panel", ds)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(detail_panel)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled        = true
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_label.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_detail_label.scroll_active         = false
	detail_panel.add_child(_detail_label)

	var hint := Label.new()
	hint.text = "[G] / [Esc]  Chiudi"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)


func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh_list()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_tab_pressed(idx: int) -> void:
	_current_tab       = idx
	_selected_faction_id = ""
	for i: int in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == idx)
	_refresh_list()


func _refresh_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()

	var tab_id: String = TABS[_current_tab]["id"]
	var factions: Array = _get_factions_for_tab(tab_id)

	if _selected_faction_id == "" and factions.size() > 0:
		var first: Variant = factions[0]
		if first is Dictionary:
			_selected_faction_id = str((first as Dictionary).get("id", ""))

	for entry: Variant in factions:
		if not entry is Dictionary:
			continue
		var fd: Dictionary = entry as Dictionary
		var fid: String    = str(fd.get("id", ""))
		if fid == "":
			continue
		_list_container.add_child(_build_list_row(fid))

	_refresh_detail()


func _get_factions_for_tab(tab_id: String) -> Array:
	if tab_id == "enemy":
		var arr: Array = FactionRegistry.get_factions_by_type("nemico")
		arr.append_array(FactionRegistry.get_factions_by_type("natura"))
		return arr
	return FactionRegistry.get_factions_by_type(tab_id)


func _build_list_row(fid: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color             = Color(0.15, 0.15, 0.22, 1.0) if fid == _selected_faction_id else Color(0.09, 0.09, 0.14, 1.0)
	style.content_margin_left  = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top   = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	panel.add_child(inner)

	# Row 1: name + membership badge
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	inner.add_child(row1)

	var name_lbl := Label.new()
	name_lbl.text                  = FactionDisplay.get_display_name(fid)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	row1.add_child(name_lbl)

	if FactionMembership.is_member(fid):
		var badge := Label.new()
		badge.text = LocaleManager.t_or("UI_FACTIONS_MEMBER_BADGE", "M")
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		row1.add_child(badge)
	elif FactionMembership.is_supporter(fid):
		var badge := Label.new()
		badge.text = LocaleManager.t_or("UI_FACTIONS_SUPPORTER_BADGE", "S")
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		row1.add_child(badge)

	# Row 2: state label + rep bar
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	inner.add_child(row2)

	var state_id: String = FactionReputation.get_state_id(fid)
	var state_lbl := Label.new()
	state_lbl.text = FactionDisplay.get_display_state(fid)
	state_lbl.add_theme_font_size_override("font_size", 11)
	state_lbl.add_theme_color_override("font_color", STATE_COLORS.get(state_id, Color.WHITE) as Color)
	row2.add_child(state_lbl)

	var bar := ProgressBar.new()
	bar.min_value               = -100
	bar.max_value               = 100
	bar.value                   = FactionReputation.get_rep(fid)
	bar.custom_minimum_size     = Vector2(70, 8)
	bar.size_flags_vertical     = Control.SIZE_SHRINK_CENTER
	bar.show_percentage         = false
	row2.add_child(bar)

	# Invisible button to capture click
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fid_c := fid
	btn.pressed.connect(func() -> void:
		_selected_faction_id = fid_c
		_refresh_list()
	)
	panel.add_child(btn)

	return panel


func _refresh_detail() -> void:
	if _selected_faction_id == "":
		_detail_label.text = ""
		return

	var fid: String      = _selected_faction_id
	var data: Dictionary = FactionRegistry.get_faction(fid)
	var rep: int         = FactionReputation.get_rep(fid)
	var state_id: String = FactionReputation.get_state_id(fid)
	var sc: Color        = STATE_COLORS.get(state_id, Color.WHITE) as Color
	var state_hex: String = "#%02x%02x%02x" % [int(sc.r * 255), int(sc.g * 255), int(sc.b * 255)]

	var lines: Array[String] = []

	lines.append("[b]" + FactionDisplay.get_display_name(fid) + "[/b]")
	lines.append("[color=" + state_hex + "]" + FactionDisplay.get_display_state(fid)
			+ "[/color]  (rep: " + str(rep) + ")")

	var desc: String = str(data.get("description", ""))
	if desc != "":
		lines.append("")
		lines.append(desc)

	if FactionMembership.is_member(fid):
		lines.append("")
		var rank: int = FactionMembership.get_rank(fid)
		lines.append("[color=#e5cc33]Rango: " + str(rank) + "[/color]")

		var passives: Variant = data.get("rank_passives", [])
		if passives is Array and rank < (passives as Array).size():
			var p: Variant = (passives as Array)[rank]
			if p is Dictionary:
				var pdesc: String = str((p as Dictionary).get("description", ""))
				if pdesc != "":
					lines.append("[color=#7cc0ff]Passivo: " + pdesc + "[/color]")

		var membership: Variant = GameState.character_faction_membership.get(fid, null)
		if membership is Dictionary:
			var debt: int = int((membership as Dictionary).get("tax_debt", 0))
			if debt > 0:
				lines.append("[color=#ff4444]Debito tasse: " + str(debt) + " monete[/color]")

	elif FactionMembership.is_supporter(fid):
		lines.append("")
		lines.append("[color=#66e575]" + LocaleManager.t_or("UI_FACTIONS_SUPPORTER_BADGE", "Sostenitore") + "[/color]")

	var known: Variant = GameState.known_faction_members.get(fid, {})
	if known is Dictionary and not (known as Dictionary).is_empty():
		lines.append("")
		lines.append("[color=#aaaaaa]" + LocaleManager.t_or("UI_FACTIONS_KNOWN_MEMBERS", "Membri conosciuti") + ":[/color]")
		for npc_id_var: Variant in (known as Dictionary):
			lines.append("  • " + str((known as Dictionary)[npc_id_var]))

	_detail_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.is_pressed() and not ke.is_echo():
			if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_G:
				get_viewport().set_input_as_handled()
				close()
