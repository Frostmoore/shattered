extends Entity
class_name Door

var is_open: bool = false
var door_uid: String = ""

var _label: Label = null


func setup(params: Dictionary) -> void:
	door_uid = params.get("uid", "")
	# Set state before _ready() so it can apply the correct visual
	if bool(params.get("open", false)):
		is_open     = true
		is_blocking = false


func _ready() -> void:
	faction = "neutral"
	if not is_open:
		is_blocking = true
	_setup_visual("+", Color(0.65, 0.50, 0.28, 1))
	_label = get_node_or_null("Label") as Label
	if is_open:
		_apply_open_visual()


func interact(_player: Node) -> void:
	open()


func open() -> void:
	if is_open:
		return
	is_open     = true
	is_blocking = false
	_apply_open_visual()

	# Persist open state so it survives save/load without a full save-game
	var map: BaseMap = get_parent() as BaseMap
	if map != null:
		map.mark_door_open(door_uid)

	EventBus.map_changed.emit(GameState.current_map_id)


func _apply_open_visual() -> void:
	if _label == null:
		return
	_label.text = "."
	if _label.label_settings != null:
		_label.label_settings.font_color = Color(0.28, 0.22, 0.33, 1)
