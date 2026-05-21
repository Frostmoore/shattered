extends Node

var _active_special: Object = null   # istanza ClassSpecial
var _active_class_id: String = ""
var _tracker: Object = null          # istanza AbilityUseTracker (null se nessun limite)
var _targeting_overlay: Node = null
var _targeting_player: Node  = null
var _menu_player: Node       = null

var hook_counters: Dictionary = {
	"before_attack":  0,
	"after_attack":   0,
	"before_damaged": 0,
	"after_damaged":  0,
	"enemy_killed":   0,
}


func _ready() -> void:
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.player_moved.connect(_on_player_moved)


# ── Gestione classe attiva ────────────────────────────────────────────────────

func set_active_class(class_id: String) -> void:
	_active_special  = null
	_tracker         = null
	_active_class_id = class_id

	if class_id.is_empty():
		return

	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		return

	var class_data: Dictionary = reg.call("get_class_data", class_id)
	var special_id: String = str(class_data.get("special_id", ""))
	if special_id.is_empty():
		return

	var path: String = "res://scripts/classes/specials/%s.gd" % _to_pascal(special_id)
	if not ResourceLoader.exists(path):
		return   # not yet implemented

	var script: Script = load(path) as Script
	if not script:
		return

	_active_special = script.new()
	_active_special.call("init_with_runtime", self)

	# Crea AbilityUseTracker se la special ha una config di uso
	var usage_config: Dictionary = _active_special.call("get_usage_config")
	if not usage_config.is_empty():
		_tracker = load("res://scripts/classes/AbilityUseTracker.gd").new()
		_tracker.call("setup", usage_config)

	print("ClassRuntime: classe '%s' attiva (special: %s)" % [class_id, special_id])


func can_use_active() -> bool:
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		return false
	var data: Dictionary = reg.call("get_class_data", _active_class_id)
	var stype: String = str(data.get("special_type", ""))
	if stype not in ["active_key", "passive_and_active", "active_toggle", "active_target"]:
		return false
	# active_target: l'overlay funziona anche senza la special caricata
	if stype == "active_target":
		return true
	# altri tipi attivi: serve la special
	return _active_special != null


# ── Dispatch hook ──────────────────────────────────────────────────────────────

func on_before_player_attack(ctx: Object) -> void:
	hook_counters["before_attack"] += 1
	if _has_special("on_before_player_attack"):
		_active_special.on_before_player_attack(ctx)


func on_after_player_attack(ctx: Object) -> void:
	hook_counters["after_attack"] += 1
	if _has_special("on_after_player_attack"):
		_active_special.on_after_player_attack(ctx)


func on_before_player_damaged(ctx: Object) -> void:
	hook_counters["before_damaged"] += 1
	if _has_special("on_before_player_damaged"):
		_active_special.on_before_player_damaged(ctx)


func on_before_damage_apply(ctx: Object) -> void:
	if _has_special("on_before_damage_apply"):
		_active_special.on_before_damage_apply(ctx)


func on_after_player_damaged(ctx: Object) -> void:
	hook_counters["after_damaged"] += 1
	if _has_special("on_after_player_damaged"):
		_active_special.on_after_player_damaged(ctx)


func on_enemy_killed(ctx: Object) -> void:
	hook_counters["enemy_killed"] += 1
	if _has_special("on_enemy_killed"):
		_active_special.on_enemy_killed(ctx)


func on_turn_end() -> void:
	if _tracker:
		_tracker.call("on_turn_end")
	if _has_special("on_turn_end"):
		_active_special.on_turn_end()


func on_floor_changed() -> void:
	if _tracker:
		_tracker.call("on_floor_changed")
	if _has_special("on_floor_changed"):
		_active_special.on_floor_changed()


func on_combat_start() -> void:
	if _has_special("on_combat_start"):
		_active_special.on_combat_start()


func use_active() -> void:
	if not can_use_active():
		return
	if _tracker and not _tracker.call("can_use"):
		EventBus.notification_shown.emit(
			Notification.warning("Abilità non disponibile."))
		return
	if _has_special("use_active"):
		_active_special.use_active()
	if _tracker:
		_tracker.call("record_use")


func use_targeted(tile: Vector2i) -> void:
	if _has_special("use_targeted"):
		_active_special.use_targeted(tile)


func is_valid_target(tile: Vector2i) -> bool:
	if _has_special("is_valid_target"):
		return bool(_active_special.is_valid_target(tile))
	return false


func get_active_special_id() -> String:
	return _active_class_id


func get_tracker() -> Object:
	return _tracker


# ── Targeting ─────────────────────────────────────────────────────────────────

func uses_menu() -> bool:
	return _has_special("uses_menu") and bool(_active_special.uses_menu())


func can_phase_walls() -> bool:
	return _has_special("can_phase_walls") and bool(_active_special.can_phase_walls())


func can_enter_wall_at(map: Node, target: Vector2i) -> bool:
	if not can_phase_walls():
		return false
	if _has_special("can_enter_wall_at"):
		return bool(_active_special.call("can_enter_wall_at", map, target))
	return true


func get_detection_range_cap() -> int:
	if _has_special("get_detection_range_cap"):
		return int(_active_special.get_detection_range_cap())
	return -1


func start_menu(player: Node) -> void:
	_menu_player = player
	if _has_special("use_active"):
		_active_special.use_active()


func confirm_menu() -> void:
	if _menu_player and is_instance_valid(_menu_player):
		_menu_player.call("_action_done")
	_menu_player = null


func cancel_menu() -> void:
	_menu_player = null


func register_targeting_overlay(overlay: Node) -> void:
	_targeting_overlay = overlay


func uses_targeting() -> bool:
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		return false
	var data: Dictionary = reg.call("get_class_data", _active_class_id)
	return str(data.get("special_type", "")) == "active_target"


func start_targeting(player: Node) -> void:
	if _tracker and not _tracker.call("can_use"):
		EventBus.notification_shown.emit(Notification.warning("Abilità non disponibile."))
		return
	if not _targeting_overlay:
		push_error("ClassRuntime: _targeting_overlay non registrato")
		return

	# Prova a ricaricare la special se non è caricata (file aggiunto fuori dall'editor)
	if _active_special == null and not _active_class_id.is_empty():
		set_active_class(_active_class_id)

	_targeting_player = player

	var wm: Node = get_node_or_null("/root/WorldManager")
	var map: Node = wm.call("get_current_map") if wm else null
	if not map:
		EventBus.notification_shown.emit(Notification.warning("Nessuna mappa attiva."))
		_targeting_player = null
		return

	var gs: Node  = get_node_or_null("/root/GameState")
	var pp: Vector2i  = gs.get("player_position") if gs else Vector2i.ZERO
	var attrs: Dictionary = gs.get("effective_attributes") if gs else {}

	var valid: Array[Vector2i] = []
	if _active_special != null:
		var raw: Variant = _active_special.call("compute_valid_targets", map, pp, attrs)
		if raw is Array:
			for v: Variant in raw as Array:
				if v is Vector2i:
					valid.append(v as Vector2i)

	if valid.is_empty():
		EventBus.notification_shown.emit(
			Notification.warning("Nessun bersaglio valido nel raggio."))
		_targeting_player = null
		return

	_targeting_overlay.call("activate", valid)


func confirm_targeting(tile: Vector2i) -> void:
	if _active_special != null and _has_special("use_targeted"):
		_active_special.use_targeted(tile)
	elif _active_special == null:
		push_error("ClassRuntime: confirm_targeting senza special caricata per '%s'" % _active_class_id)
	if _tracker:
		_tracker.call("record_use")
	if _targeting_player and is_instance_valid(_targeting_player):
		_targeting_player.call("_action_done")
	_targeting_player = null


func cancel_targeting() -> void:
	_targeting_player = null


func check_entity_at_position(entity: Node, pos: Vector2i) -> void:
	if _has_special("on_entity_at_position"):
		_active_special.on_entity_at_position(entity, pos)


# ── Item use ──────────────────────────────────────────────────────────────────

func can_use_item_in_combat() -> bool:
	if _has_special("blocks_item_use_in_combat"):
		return not bool(_active_special.blocks_item_use_in_combat())
	return true


func on_player_moved() -> void:
	if _has_special("on_player_moved"):
		_active_special.on_player_moved()


# ── Connessioni EventBus ──────────────────────────────────────────────────────

func _on_combat_started() -> void:
	on_combat_start()


func _on_map_changed(_map_id: String) -> void:
	on_floor_changed()


func _on_turn_ended(actor: Variant) -> void:
	if not (actor is Node):
		return
	if str((actor as Node).get("faction")) != "player":
		return
	on_turn_end()


func _on_player_moved(_pos: Vector2i) -> void:
	on_player_moved()


# ── Utility ───────────────────────────────────────────────────────────────────

func _has_special(method: String) -> bool:
	return _active_special != null and _active_special.has_method(method)


func _to_pascal(snake: String) -> String:
	var result := ""
	for part: String in snake.split("_"):
		if not part.is_empty():
			result += part.substr(0, 1).to_upper() + part.substr(1)
	return result
