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


func _on_redraw_needed(_arg: Variant = null) -> void:
	queue_redraw()


func _draw() -> void:
	var map: BaseMap = get_parent() as BaseMap
	if map == null or _font == null:
		return

	var theme: Dictionary = _get_theme(map.map_type)
	draw_rect(Rect2(0, 0, map.map_width * CELL, map.map_height * CELL), theme["bg"])

	# Dungeon-type maps use fog of war; overworld and village are always fully lit
	var use_fov: bool = (map.map_type == "dungeon")

	for y: int in range(map.map_height):
		for x: int in range(map.map_width):
			var pos: Vector2i = Vector2i(x, y)
			var visible: int = map.is_tile_visible(pos)
			var seen: int    = map.is_tile_seen(pos)

			if use_fov and seen == 0:
				continue  # never seen — leave as background (dark)

			var dim: bool = use_fov and visible == 0  # seen but not currently visible

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
						# Legacy / non-dungeon transitions
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

	# Draw entities on top — only if visible (when FOV is active)
	if use_fov:
		_draw_entities(map)


func _draw_entities(map: BaseMap) -> void:
	# Entity nodes render themselves via their own Label children.
	# We only need to hide/show them based on FOV.
	for child: Node in map.get_children():
		if child is Entity and not (child is Player):
			var entity: Entity = child as Entity
			var visible_tile: int = map.is_tile_visible(entity.grid_position)
			entity.visible = visible_tile > 0


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
