extends Entity
class_name Door

var is_open: bool = false
var door_uid: String = ""
# {faction_id, min_rep, min_rank} — all optional; empty = no restriction
var faction_requirement: Dictionary = {}

var _label: Label = null


func setup(params: Dictionary) -> void:
	door_uid = params.get("uid", "")
	if bool(params.get("open", false)):
		is_open     = true
		is_blocking = false
	var req_raw: Variant = params.get("faction_requirement", {})
	if req_raw is Dictionary:
		faction_requirement = (req_raw as Dictionary).duplicate()


func _ready() -> void:
	faction = "neutral"
	if not is_open:
		is_blocking = true
	_setup_visual("+", Color(0.65, 0.50, 0.28, 1))
	_label = get_node_or_null("Label") as Label
	if is_open:
		_apply_open_visual()


func interact(_player: Node) -> void:
	if not _check_faction_access():
		var fid: String   = str(faction_requirement.get("faction_id", ""))
		var fname: String = FactionDisplay.get_display_name(fid) if fid != "" else "Fazione"
		EventBus.notification_shown.emit(Notification.faction_access_denied(fname))
		return
	open()


func _check_faction_access() -> bool:
	if faction_requirement.is_empty():
		return true
	var fid: String = str(faction_requirement.get("faction_id", ""))
	if fid == "":
		return true
	var min_rep: int  = int(faction_requirement.get("min_rep",  0))
	var min_rank: int = int(faction_requirement.get("min_rank", -1))
	if min_rep > 0 and FactionReputation.get_rep(fid) < min_rep:
		return false
	# min_rank 0 = member required (any rank); get_rank returns -1 for non-members
	if min_rank >= 0 and FactionMembership.get_rank(fid) < min_rank:
		return false
	return true


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
