extends Control

const CELL:           int     = 16
const TOOLTIP_OFFSET: Vector2 = Vector2(14, 14)
const BG_COLOR:       Color   = Color(0.05, 0.05, 0.08, 0.92)
const BORDER_COLOR:   Color   = Color(0.35, 0.35, 0.45, 1.0)
const NAME_COLOR:     Color   = Color(0.95, 0.95, 0.95, 1.0)
const SUB_COLOR:      Color   = Color(0.60, 0.60, 0.70, 1.0)
const AFFIX_COLOR:    Color   = Color(0.85, 0.75, 0.35, 1.0)

var _targeting_overlay: Node       = null
var _panel:             PanelContainer = null
var _icon_lbl:          Label          = null
var _name_lbl:          Label          = null
var _sub_lbl:           Label          = null
var _sep:               HSeparator     = null
var _affix_container:   VBoxContainer  = null
var _last_entity:       Node           = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color              = BG_COLOR
	style.border_color          = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	_icon_lbl = Label.new()
	_icon_lbl.custom_minimum_size  = Vector2(18, 20)
	_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_icon_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(_icon_lbl)

	_name_lbl = Label.new()
	_name_lbl.add_theme_color_override("font_color", NAME_COLOR)
	_name_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(_name_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.add_theme_color_override("font_color", SUB_COLOR)
	_sub_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_sub_lbl)

	_sep = HSeparator.new()
	_sep.add_theme_color_override("color", BORDER_COLOR)
	vbox.add_child(_sep)

	_affix_container = VBoxContainer.new()
	_affix_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_affix_container)

	add_child(_panel)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	if motion.relative == Vector2.ZERO:
		return
	_on_mouse_moved(motion.position)


func _on_mouse_moved(screen_pos: Vector2) -> void:
	if _targeting_overlay != null and bool(_targeting_overlay.get("_is_active")):
		_last_entity = null
		_hide()
		return

	var map: Node = WorldManager.get_current_map() if WorldManager else null
	if map == null:
		_hide()
		return

	var grid: Vector2i = _mouse_to_grid(screen_pos)
	var entity: Node   = map.call("get_entity_at", grid)

	if entity == null or entity.get("enemy_data_id") == null:
		_last_entity = null
		_hide()
		return

	if entity != _last_entity:
		_last_entity = entity
		_update_content(entity)

	_panel.visible = true
	_position_panel(screen_pos)


func _update_content(enemy: Node) -> void:
	var entry: Dictionary = EnemyRegistry.get_enemy_data(str(enemy.get("enemy_data_id")))

	var icon_char: String = "e"
	var col:       Color  = Color(0.88, 0.28, 0.28, 1.0)
	if not entry.is_empty():
		icon_char = str(entry.get("char", "e"))
		var c: Array = entry.get("color", [0.88, 0.28, 0.28, 1.0]) as Array
		if c.size() >= 4:
			col = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	if bool(enemy.get("is_boss")):
		icon_char = icon_char.to_upper()
		col       = Color(1.0, 0.15, 0.15, 1.0)

	_icon_lbl.text = icon_char
	_icon_lbl.add_theme_color_override("font_color", col)
	var dn: Variant = enemy.get("display_name")
	_name_lbl.text = str(dn) if dn != null else "?"

	var family: String = str(entry.get("family", "")).capitalize()
	var role:   String = str(entry.get("role",   "")).capitalize()
	if family != "" and role != "":
		_sub_lbl.text = "%s — %s" % [family, role]
	elif family != "":
		_sub_lbl.text = family
	elif role != "":
		_sub_lbl.text = role
	else:
		_sub_lbl.text = ""

	for child: Node in _affix_container.get_children():
		_affix_container.remove_child(child)
		child.queue_free()

	var affix_ids: Array = []
	var raw: Variant = enemy.get("affixes")
	if raw is Array:
		affix_ids = raw as Array

	for affix_id: Variant in affix_ids:
		var affix: Dictionary = AffixRegistry.get_affix(str(affix_id))
		if affix.is_empty():
			continue
		var lbl := Label.new()
		var prefix: String = str(affix.get("prefix", str(affix_id)))
		var rank:   String = str(affix.get("affix_rank", ""))
		lbl.text = "▸ " + prefix + (" [maggiore]" if rank == "major" else "")
		lbl.add_theme_color_override("font_color", AFFIX_COLOR)
		lbl.add_theme_font_size_override("font_size", 11)
		_affix_container.add_child(lbl)

	var has_affixes: bool = affix_ids.size() > 0
	_sep.visible             = has_affixes
	_affix_container.visible = has_affixes
	_panel.reset_size()


func _position_panel(screen_pos: Vector2) -> void:
	var vp_size:    Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _panel.size
	if panel_size == Vector2.ZERO:
		panel_size = _panel.get_minimum_size()
	var pos: Vector2 = screen_pos + TOOLTIP_OFFSET
	pos.x = clampf(pos.x, 0.0, maxf(0.0, vp_size.x - panel_size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, vp_size.y - panel_size.y))
	_panel.position = pos


func _hide() -> void:
	if _panel != null and _panel.visible:
		_panel.visible = false


func _mouse_to_grid(screen_pos: Vector2) -> Vector2i:
	var ct: Transform2D    = get_viewport().get_canvas_transform()
	var world_pos: Vector2 = ct.affine_inverse() * screen_pos
	return Vector2i(int(world_pos.x / float(CELL)), int(world_pos.y / float(CELL)))
