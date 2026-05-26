extends Node2D

const CELL: int = 16
const FONT_SIZE: int = 13
const BASELINE_Y: int = 12

var _font: SystemFont


func _ready() -> void:
	z_index = -5
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"Courier New", "Courier", "Consolas",
		"DejaVu Sans Mono", "Liberation Mono", "Lucida Console"
	])
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.hinting      = TextServer.HINTING_NONE
	EventBus.player_moved.connect(_on_redraw_needed)
	EventBus.map_changed.connect(_on_redraw_needed)
	EventBus.enemy_died.connect(_on_redraw_needed)
	EventBus.turn_ended.connect(_on_redraw_needed)
	EventBus.day_slot_changed.connect(_on_redraw_needed)


func _on_redraw_needed(_arg: Variant = null) -> void:
	queue_redraw()


func _draw() -> void:
	var map: BaseMap = get_parent() as BaseMap
	if map == null or _font == null:
		return

	var theme: Dictionary = _get_theme(map.map_type)
	draw_rect(Rect2(0, 0, map.map_width * CELL, map.map_height * CELL), theme["bg"])

	# Night overlay mode: village/city with active lights.
	# Tiles are drawn at full color; a per-tile black gradient overlay is applied on top.
	# Player and each light source cast a circular gradient (0.0 at center → 0.5 at edge).
	var night_overlay_mode: bool = map._lights_active and map.map_type in ["village", "city"]

	# Dungeon: traditional binary FOV dim.
	var use_fov: bool = map.map_type == "dungeon"

	var tile_overlay: Dictionary = {}   # Vector2i → float (only populated in night_overlay_mode)
	if night_overlay_mode:
		_fill_overlay(map, tile_overlay, GameState.player_position, GameBalance.FOV_RADIUS)
		for ls: Dictionary in map._light_sources:
			_fill_overlay(map, tile_overlay, ls["pos"] as Vector2i, int(ls["radius"]))

	for y: int in range(map.map_height):
		for x: int in range(map.map_width):
			var pos: Vector2i = Vector2i(x, y)
			var visible: int = map.is_tile_visible(pos)
			var seen: int    = map.is_tile_seen(pos)

			if (use_fov or night_overlay_mode) and seen == 0:
				continue  # never seen — leave as background (dark)

			var dim: bool = use_fov and visible == 0  # dungeon: seen but not in FOV

			var ch: String
			var col: Color

			if map.is_blocked_tile(pos):
				ch  = theme["wall_char"]
				col = theme["wall_color"]
			else:
				var trans: Variant = map.get_transition_at(pos)
				if trans != null:
					var t: Dictionary = trans as Dictionary
					var stair_type: String = str(t.get("stair_type", ""))
					if stair_type == "down":
						ch  = ">"
						col = Color(1.0, 0.48, 0.12, 1)
					elif stair_type == "up":
						ch  = "<"
						col = Color(0.42, 0.95, 0.42, 1)
					else:
						match str(t.get("target_type", "")):
							"village":
								ch  = "V"
								col = Color(1.0, 0.88, 0.22, 1)
							"dungeon":
								ch  = ">"
								col = Color(1.0, 0.48, 0.12, 1)
							_:
								ch  = "<"
								col = Color(0.42, 0.95, 0.42, 1)
				elif map.has_save_point_at(pos):
					ch  = "Ω"
					col = Color(0.4, 0.88, 0.95, 1)
				else:
					ch  = theme["floor_char"]
					col = theme["floor_color"]

			if dim:
				col = col * GameBalance.FOV_MEMORY_ALPHA
				col.a = 1.0

			draw_string(
				_font,
				Vector2(x * CELL, y * CELL + BASELINE_Y),
				ch,
				HORIZONTAL_ALIGNMENT_CENTER,
				CELL, FONT_SIZE,
				col
			)

			if night_overlay_mode:
				var ov: float = tile_overlay.get(pos, 0.5) as float
				if ov > 0.0:
					draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), Color(0.0, 0.0, 0.0, ov))

	# Corpses
	_draw_corpses(map, use_fov, tile_overlay if night_overlay_mode else {})

	# Entities
	_draw_entities(map, use_fov, tile_overlay if night_overlay_mode else {})

	# Light source glyphs always on top (full brightness, never overlaid)
	if map._lights_active:
		for ls: Dictionary in map._light_sources:
			var lp: Vector2i = ls["pos"] as Vector2i
			if map.is_tile_seen(lp) == 0:
				continue
			var lc: Color = ls.get("color", Color(1.0, 0.82, 0.20)) as Color
			draw_string(_font,
				Vector2(lp.x * CELL, lp.y * CELL + BASELINE_Y),
				"*", HORIZONTAL_ALIGNMENT_CENTER, CELL, FONT_SIZE, lc)


# Fills overlay[pos] = min(current, gradient_alpha) for all tiles in radius with LOS from origin.
func _fill_overlay(map: BaseMap, overlay: Dictionary, origin: Vector2i, radius: int) -> void:
	overlay[origin] = 0.0
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var tp := Vector2i(origin.x + dx, origin.y + dy)
			if tp.x < 0 or tp.y < 0 or tp.x >= map.map_width or tp.y >= map.map_height:
				continue
			if not map.has_line_of_sight(origin, tp):
				continue
			var dist: float = Vector2(float(dx), float(dy)).length()
			var alpha: float = 0.5 * (dist / float(radius))
			if not overlay.has(tp) or (overlay[tp] as float) > alpha:
				overlay[tp] = alpha


func _draw_corpses(map: BaseMap, use_fov: bool, tile_overlay: Dictionary) -> void:
	var night_overlay_mode: bool = not tile_overlay.is_empty()
	for corpse: Dictionary in map._corpses:
		var pos: Vector2i = corpse["pos"] as Vector2i
		var col: Color    = corpse["color"] as Color
		if use_fov:
			if map.is_tile_seen(pos) == 0:
				continue
			if map.is_tile_visible(pos) == 0:
				col = col * GameBalance.FOV_MEMORY_ALPHA
				col.a = 1.0
		elif night_overlay_mode:
			if map.is_tile_seen(pos) == 0:
				continue
			var ov: float = tile_overlay.get(pos, 0.5) as float
			col = col.darkened(ov * 0.8)
		draw_string(
			_font,
			Vector2(pos.x * CELL, pos.y * CELL + BASELINE_Y),
			"_",
			HORIZONTAL_ALIGNMENT_CENTER,
			CELL, FONT_SIZE,
			col
		)


func _draw_entities(map: BaseMap, use_fov: bool, tile_overlay: Dictionary) -> void:
	var night_overlay_mode: bool = not tile_overlay.is_empty()
	for child: Node in map.get_children():
		if not (child is Entity) or child is Player:
			continue
		var entity: Entity = child as Entity
		if entity.is_dead:
			entity.visible = false
			entity.modulate = Color.WHITE
			continue

		if night_overlay_mode:
			if map.is_tile_seen(entity.grid_position) == 0:
				entity.visible = false
				entity.modulate = Color.WHITE
				continue
			var ov: float = tile_overlay.get(entity.grid_position, 0.5) as float
			if entity is NPC or entity is Enemy or entity is Ally:
				entity.visible = ov < 0.5
				entity.modulate = Color.WHITE
			else:
				entity.visible = true
				entity.modulate = Color.WHITE.darkened(ov * 0.8)
		elif use_fov:
			# Dungeon: mostra solo se la tile è nel FOV corrente
			entity.visible = map.is_tile_visible(entity.grid_position) > 0
			entity.modulate = Color.WHITE
		else:
			# Giorno in villaggio/città/edificio: sempre visibile
			entity.visible = true
			entity.modulate = Color.WHITE


func _get_theme(map_type: String) -> Dictionary:
	match map_type:
		"overworld":
			return {
				"bg":          Color(0.02, 0.06, 0.02, 1),
				"floor_char":  ",",
				"floor_color": Color(0.20, 0.42, 0.10, 1),
				"wall_char":   "^",
				"wall_color":  Color(0.50, 0.44, 0.28, 1),
			}
		"village":
			return {
				"bg":          Color(0.06, 0.05, 0.03, 1),
				"floor_char":  ".",
				"floor_color": Color(0.50, 0.42, 0.28, 1),
				"wall_char":   "#",
				"wall_color":  Color(0.75, 0.64, 0.46, 1),
			}
		"building":
			return {
				"bg":          Color(0.05, 0.04, 0.03, 1),
				"floor_char":  ".",
				"floor_color": Color(0.55, 0.48, 0.35, 1),
				"wall_char":   "#",
				"wall_color":  Color(0.65, 0.55, 0.40, 1),
			}
		_:  # dungeon + fallback
			return {
				"bg":          Color(0.03, 0.02, 0.04, 1),
				"floor_char":  ".",
				"floor_color": Color(0.28, 0.22, 0.33, 1),
				"wall_char":   "#",
				"wall_color":  Color(0.48, 0.42, 0.54, 1),
			}
