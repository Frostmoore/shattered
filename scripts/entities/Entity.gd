extends Node2D
class_name Entity

var entity_id: String = ""
var display_name: String = "Entity"
var grid_position: Vector2i = Vector2i.ZERO

var level: int = 1
var dex: int = 5
var accuracy: int = 0
var evasion: int = 0
var hp: int = 10
var max_hp: int = 10
var attack: int = 2
var defense: int = 0

var is_blocking: bool = true
var faction: String = "neutral"
var is_dead: bool = false

var entity_char: String = "?"
var entity_color: Color = Color.WHITE


func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp = maxi(0, hp - amount)
	if hp <= 0:
		die()


func die() -> void:
	is_dead = true
	EventBus.enemy_died.emit(self)
	queue_free()


func move_to(target_position: Vector2i) -> void:
	grid_position = target_position
	position = WorldManager.grid_to_world(target_position)


func snap_to_grid() -> void:
	position = WorldManager.grid_to_world(grid_position)


# Sets up an ASCII character label for this entity.
# Removes the placeholder ColorRect and configures a styled Label.
func _setup_visual(char: String, col: Color) -> void:
	var spr: Node = get_node_or_null("Sprite")
	if spr != null:
		spr.queue_free()

	var lbl: Label = get_node_or_null("Label") as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = "Label"
		add_child(lbl)

	entity_char  = char
	entity_color = col
	lbl.text = char
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.offset_left   = -8.0
	lbl.offset_top    = -8.0
	lbl.offset_right  =  8.0
	lbl.offset_bottom =  8.0

	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray([
		"Courier New", "Courier", "Consolas",
		"DejaVu Sans Mono", "Liberation Mono", "Lucida Console"
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE

	var settings: LabelSettings = LabelSettings.new()
	settings.font = font
	settings.font_size = 14
	settings.font_color = col
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 1.0)
	lbl.label_settings = settings
