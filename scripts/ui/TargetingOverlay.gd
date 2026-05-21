extends Control
# Overlay di targeting per classi active_target.
#
# Controlli:
#   WASD / frecce  → muove il cursore (blocca movimento del personaggio)
#   E / Spazio     → conferma bersaglio (solo su tile valido)
#   Click sinistro → conferma bersaglio (solo su tile valido)
#   ESC            → annulla

const CELL:        int   = 16
const COL_VALID:   Color = Color(0.15, 0.90, 0.15, 0.35)   # verde: tile validi
const COL_HOVER:   Color = Color(0.95, 0.92, 0.10, 0.65)   # giallo: cursore su tile valido
const COL_INVALID: Color = Color(0.90, 0.20, 0.20, 0.40)   # rosso: cursore su tile non valido

var _valid_tiles:    Array[Vector2i] = []
var _hover_tile:     Vector2i        = Vector2i(-1, -1)
var _is_active:      bool            = false
var _keyboard_mode:  bool            = false   # true = WASD ha il cursore, ignora mouse motion


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible      = false
	set_process_input(false)


func activate(valid_tiles: Array[Vector2i]) -> void:
	_valid_tiles = valid_tiles
	# Posiziona il cursore sul tile valido più vicino al player
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and not valid_tiles.is_empty():
		_hover_tile = _nearest_valid(gs.get("player_position"))
	elif not valid_tiles.is_empty():
		_hover_tile = valid_tiles[0]
	else:
		_hover_tile = Vector2i(-1, -1)

	_is_active   = true
	size         = get_viewport().get_visible_rect().size
	position     = Vector2.ZERO
	visible      = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	queue_redraw()


func deactivate() -> void:
	_is_active   = false
	visible      = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)
	_valid_tiles.clear()


func is_active() -> bool:
	return _is_active


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _is_active:
		return
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var zoom: float     = ct.get_scale().x
	var ts: float       = CELL * zoom

	# Tile validi in verde (escluso quello sotto il cursore)
	for tile: Vector2i in _valid_tiles:
		if tile == _hover_tile:
			continue
		var tl: Vector2 = ct * Vector2(tile.x * CELL, tile.y * CELL)
		draw_rect(Rect2(tl, Vector2(ts, ts)), COL_VALID)

	# Cursore: giallo su tile valido, rosso altrimenti
	if _hover_tile != Vector2i(-1, -1):
		var col: Color  = COL_HOVER if _valid_tiles.has(_hover_tile) else COL_INVALID
		var tl: Vector2 = ct * Vector2(_hover_tile.x * CELL, _hover_tile.y * CELL)
		draw_rect(Rect2(tl, Vector2(ts, ts)), col)


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# ── Tastiera ──────────────────────────────────────────────────────────────
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return

		# Movimento cursore — blocca il personaggio intercettando le action di movimento
		var dir := Vector2i.ZERO
		if event.is_action("move_up"):    dir = Vector2i( 0, -1)
		elif event.is_action("move_down"):  dir = Vector2i( 0,  1)
		elif event.is_action("move_left"):  dir = Vector2i(-1,  0)
		elif event.is_action("move_right"): dir = Vector2i( 1,  0)

		if dir != Vector2i.ZERO:
			_keyboard_mode = true
			_hover_tile   += dir
			get_viewport().set_input_as_handled()
			queue_redraw()
			return

		# Conferma con E / Spazio (action "interact")
		if event.is_action("interact"):
			get_viewport().set_input_as_handled()
			_try_confirm()
			return

		# Annulla con ESC
		if ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel()
			return

	# ── Mouse hover ───────────────────────────────────────────────────────────
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# Ignora eventi senza movimento reale (jitter OS, eventi sintetici)
		if motion.relative == Vector2.ZERO:
			return
		# Il mouse si è mosso davvero: cede il controllo al mouse
		_keyboard_mode = false
		var tile: Vector2i = _mouse_to_grid(motion.position)
		if tile != _hover_tile:
			_hover_tile = tile
			queue_redraw()
		return

	# ── Click sinistro: conferma ──────────────────────────────────────────────
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
			_keyboard_mode = false
			_hover_tile    = _mouse_to_grid(mb.position)
			_try_confirm()


# ── Azioni ────────────────────────────────────────────────────────────────────

func _try_confirm() -> void:
	if not _valid_tiles.has(_hover_tile):
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb:
			eb.notification_shown.emit(
				Notification.warning("Seleziona un bersaglio valido (tile verde)."))
		return
	var tile: Vector2i = _hover_tile
	deactivate()
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if rt:
		rt.call("confirm_targeting", tile)


func _cancel() -> void:
	deactivate()
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if rt:
		rt.call("cancel_targeting")


# ── Utility ───────────────────────────────────────────────────────────────────

func _mouse_to_grid(screen_pos: Vector2) -> Vector2i:
	var ct: Transform2D    = get_viewport().get_canvas_transform()
	var world_pos: Vector2 = ct.affine_inverse() * screen_pos
	return Vector2i(int(world_pos.x / float(CELL)), int(world_pos.y / float(CELL)))


func _nearest_valid(origin: Vector2i) -> Vector2i:
	if _valid_tiles.is_empty():
		return Vector2i(-1, -1)
	var best: Vector2i = _valid_tiles[0]
	var best_dist: int = 999999
	for t: Vector2i in _valid_tiles:
		var d: int = abs(t.x - origin.x) + abs(t.y - origin.y)
		if d < best_dist:
			best_dist = d
			best      = t
	return best
