class_name MinimapPanel
extends Panel

signal position_changed(pos: Vector2)

const MAP_SIZE    := Vector2i(160, 160)
const TILE_RADIUS := 80

const C_PLAYER   := Color(1.0, 1.0, 1.0)
const C_EXPLORED := Color(0.22, 0.22, 0.22)
const C_EMPTY    := Color(0.0,  0.0,  0.0)

const _FONT_REG: String = "res://assets/fonts/Roboto-Regular.ttf"

var _header_lbl:  Label       = null
var _tex_rect:    TextureRect = null
var _image:       Image       = null
var _texture:     ImageTexture = null

var _dragging:    bool    = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_image   = Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_tex_rect.texture = _texture


func _build_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.95)
	panel_style.border_color = Color(0.75, 0.62, 0.20, 0.80)
	panel_style.set_border_width_all(1)
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_header_lbl = Label.new()
	_header_lbl.name = "HeaderLabel"
	_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_lbl.add_theme_font_override("font", load(_FONT_REG))
	_header_lbl.add_theme_font_size_override("font_size", 10)
	_header_lbl.add_theme_color_override("font_color", Color(0.72, 0.60, 0.18))
	_header_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header_lbl.clip_text = true
	vbox.add_child(_header_lbl)

	_tex_rect = TextureRect.new()
	_tex_rect.name = "MapRect"
	_tex_rect.custom_minimum_size = Vector2(MAP_SIZE.x, MAP_SIZE.y)
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_tex_rect)


# ── API pubblica ──────────────────────────────────────────────────────────────

func load_position(pos: Vector2) -> void:
	position = _clamp_to_viewport(pos)


func mark_explored(tile: Vector2i) -> void:
	GameState.explored_tiles["%d,%d" % [tile.x, tile.y]] = true


func refresh_header() -> void:
	var zone_name: String = ""
	var map_id: String = GameState.current_map_id
	if map_id != "":
		var map_data: MapData = LocationRegistry.get_or_generate(map_id)
		if map_data != null:
			zone_name = str(map_data.metadata.get("name", ""))
		if zone_name == "":
			zone_name = LocaleManager.t_or("ZONE_" + map_id.to_upper(), map_id)
	_header_lbl.text = zone_name + " · " + TimeManager.format_time()


func refresh_image() -> void:
	_image.fill(C_EMPTY)

	var center: Vector2i = GameState.player_position
	var half:   int      = TILE_RADIUS

	for py: int in range(MAP_SIZE.y):
		for px: int in range(MAP_SIZE.x):
			var tx: int = center.x + px - half
			var ty: int = center.y + py - half
			if GameState.explored_tiles.has("%d,%d" % [tx, ty]):
				_image.set_pixel(px, py, C_EXPLORED)

	# Pixel del giocatore — centro esatto
	_image.set_pixel(half, half, C_PLAYER)

	_texture.update(_image)


func refresh_full() -> void:
	refresh_header()
	refresh_image()


# ── Drag ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging    = true
				_drag_offset = mb.global_position - global_position
			else:
				_dragging = false
				position  = _clamp_to_viewport(position)
				position_changed.emit(position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		position = _clamp_to_viewport(mm.global_position - _drag_offset)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		position = _clamp_to_viewport(position)


func _clamp_to_viewport(pos: Vector2) -> Vector2:
	var vp: Rect2 = get_viewport_rect()
	return Vector2(
		clampf(pos.x, 0.0, vp.size.x - size.x),
		clampf(pos.y, 0.0, vp.size.y - size.y)
	)
