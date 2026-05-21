extends CanvasLayer

signal class_confirmed(class_id: String)
signal cancelled()

const PANEL_MARGIN  := 15
const TOOLTIP_W     := 205.0
const GRID_COLUMNS  := 8

var _cards: Array               = []
var _selected_class: Dictionary = {}
var _confirm_btn: Button
var _tooltip: PanelContainer
var _tooltip_label: Label
var _grid: GridContainer


func _ready() -> void:
	layer   = 91
	visible = false
	_build_ui()


func open() -> void:
	_selected_class = {}
	_rebuild_cards()
	_confirm_btn.disabled = true
	visible = true


func _get_card_count() -> int:
	return _cards.size()


# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.60)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.09, 0.15, 0.98)
	pstyle.border_color = Color(0.48, 0.28, 0.28, 1.0)
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(4)
	pstyle.content_margin_left   = 12.0
	pstyle.content_margin_right  = 12.0
	pstyle.content_margin_top    = 10.0
	pstyle.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left   = PANEL_MARGIN
	panel.offset_right  = -PANEL_MARGIN
	panel.offset_top    = PANEL_MARGIN
	panel.offset_bottom = -PANEL_MARGIN
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "Cambia Classe"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.92, 0.58, 0.58))
	outer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "La Licenza di Classe verrà consumata alla conferma"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.55, 0.55))
	outer.add_child(subtitle)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(_grid)

	outer.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	outer.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "← Annulla"
	cancel_btn.pressed.connect(func() -> void:
		visible = false
		cancelled.emit()
	)
	btn_row.add_child(cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Cambia Classe →"
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

	_build_tooltip()


func _rebuild_cards() -> void:
	for card: Node in _cards:
		_grid.remove_child(card)
		card.queue_free()
	_cards.clear()
	_populate_grid()


func _populate_grid() -> void:
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		return
	var gmt: Node = get_node_or_null("/root/GlobalMilestoneTracker")
	var gs: Node  = get_node_or_null("/root/GameState")
	var current_class: String = str(gs.get("current_class")) if gs else ""

	var implemented: Array = reg.call("get_implemented")
	implemented.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = int(a.get("tier", 0))
		var tb: int = int(b.get("tier", 0))
		if ta != tb:
			return ta < tb
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	implemented = implemented.filter(func(data: Dictionary) -> bool:
		var cid: String = str(data.get("id", ""))
		if cid == current_class:
			return false
		if not gmt:
			return true
		return bool(gmt.call("is_class_unlocked", cid))
	)
	for data: Dictionary in implemented:
		var card: Node = load("res://scripts/ui/ClassCard.gd").new()
		card.call("setup", data)
		card.connect("hovered",      _on_card_hovered)
		card.connect("unhovered",    _on_card_unhovered)
		card.connect("card_pressed", _on_card_pressed)
		_grid.add_child(card)
		_cards.append(card)


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.07, 0.07, 0.12, 0.97)
	ts.border_color = Color(0.38, 0.38, 0.58)
	ts.set_border_width_all(1)
	ts.set_corner_radius_all(3)
	ts.content_margin_left   = 8.0
	ts.content_margin_right  = 8.0
	ts.content_margin_top    = 6.0
	ts.content_margin_bottom = 6.0
	_tooltip.add_theme_stylebox_override("panel", ts)
	_tooltip.custom_minimum_size = Vector2(TOOLTIP_W, 0)
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 10)
	_tooltip_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(TOOLTIP_W - 16.0, 0)
	_tooltip.add_child(_tooltip_label)


# ── card events ───────────────────────────────────────────────────────────────

func _on_card_hovered(data: Dictionary) -> void:
	_tooltip_label.text = _tooltip_text(data)
	_tooltip.visible = true
	_move_tooltip()


func _on_card_unhovered() -> void:
	_tooltip.visible = false


func _on_card_pressed(data: Dictionary) -> void:
	_selected_class = data
	var sel_id: String = str(data.get("id", ""))
	for card: Node in _cards:
		card.call("set_selected", card.call("get_class_id") == sel_id)
	_confirm_btn.disabled = false


func _process(_dt: float) -> void:
	if visible and _tooltip.visible:
		_move_tooltip()


func _move_tooltip() -> void:
	var m: Vector2  = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tx: float = m.x + 14.0
	if tx + TOOLTIP_W > vp.x - 4.0:
		tx = m.x - TOOLTIP_W - 6.0
	var ty: float = clampf(m.y + 14.0, 4.0, vp.y - _tooltip.size.y - 4.0)
	_tooltip.position = Vector2(tx, ty)


func _on_confirm() -> void:
	if _selected_class.is_empty():
		return
	visible = false
	class_confirmed.emit(str(_selected_class.get("id", "noob")))


# ── tooltip text ──────────────────────────────────────────────────────────────

func _tooltip_text(d: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("%s  •  Tier %d" % [str(d.get("name", "")), int(d.get("tier", 1))])
	lines.append("──────────────────")
	lines.append(str(d.get("desc", "")))
	lines.append("")

	var primary: Variant = d.get("primary", [])
	if primary is Array and not (primary as Array).is_empty():
		var plist: Array = primary as Array
		lines.append("Principale: " + ", ".join(plist.map(
				func(a: Variant) -> String: return str(a).to_upper())))

	var growth: Variant = d.get("growth", {})
	if growth is Dictionary:
		var parts: Array[String] = []
		for attr: String in ["str", "dex", "int", "vit", "wil"]:
			var v: int = int((growth as Dictionary).get(attr, 0))
			if v > 0:
				parts.append("%s+%d" % [attr.to_upper(), v])
		if not parts.is_empty():
			lines.append("Crescita/lv: " + ", ".join(parts))

	lines.append("")
	lines.append("──────────────────")
	var stype: String = str(d.get("special_type", "passive"))
	lines.append("[%s]  %s" % [_stype_label(stype), str(d.get("special_name", ""))])
	lines.append(str(d.get("special_desc", "")))

	lines.append("")
	lines.append("──────────────────")
	var unlock: Variant = d.get("unlock", {})
	if unlock is Dictionary:
		lines.append("Sblocco: " + _unlock_label(unlock as Dictionary))

	return "\n".join(lines)


func _stype_label(t: String) -> String:
	match t:
		"passive":            return "Passiva"
		"active_key":         return "Attiva Q"
		"active_target":      return "Attiva: mira"
		"passive_and_active": return "Passiva + Q"
		"active_toggle":      return "Toggle Q"
		_:                    return t


func _unlock_label(u: Dictionary) -> String:
	var t: String = str(u.get("type", ""))
	var v: int    = int(u.get("value", 0))
	match t:
		"always":                      return "Sempre disponibile"
		"kills_total":                 return "Uccidi %d nemici (totale)" % v
		"kills_boss":                  return "Sconfiggi %d boss" % v
		"dungeons_completed":          return "Completa %d dungeon" % v
		"dungeons_completed_no_death": return "Completa %d dungeon senza morire" % v
		"deaths_total":                return "Muori %d volte" % v
		"damage_dealt_total":          return "Infliggi %d danni (totale)" % v
		"damage_taken_total":          return "Subisci %d danni in una run" % v
		"scrolls_collected":           return "Raccogli %d scroll" % v
		"chests_opened":               return "Apri %d forzieri" % v
		"quests_completed":            return "Completa %d missioni" % v
		"npcs_spoken":                 return "Parla con %d PNG" % v
		"consumables_used":            return "Usa %d consumabili" % v
		"overworld_tiles":             return "Esplora %d tile overworld" % v
		"overworld_zones_visited":     return "Visita %d zone overworld" % v
		"overworld_zones_explored":    return "Esplora tutte le zone overworld"
		"dungeon_floors_total":        return "Completa %d piani dungeon" % v
		"dungeon_rooms_explored":      return "Esplora %d stanze dungeon" % v
		"tiles_explored_total":        return "Esplora %d tile (totale)" % v
		"combat_wins_no_items":        return "Vinci %d combattimenti senza oggetti" % v
		"near_death_survived":         return "Sopravvivi a ≤10%% HP × %d in una run" % v
		"survived_at_1hp":             return "Sopravvivi con 1 HP (%d volte)" % v
		"attacks_dodged_total":        return "Schiva %d attacchi (totale)" % v
		"gold_accumulated":            return "Accumula %d monete d'oro" % v
		"class_respec_count":          return "Cambia classe %d volte" % v
		"save_points_used":            return "Usa %d punti di salvataggio" % v
		"enemies_seen_die":            return "Osserva morire %d nemici" % v
		"all_classes_completed":       return "Completa il gioco con tutte le altre classi"
		_:                             return "%s (%d)" % [t, v]
