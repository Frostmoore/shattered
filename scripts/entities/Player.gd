extends Entity
class_name Player

var _can_act: bool = true
var _god_mode: bool = false

# Hold-to-move state
var _hold_dir: Vector2i = Vector2i.ZERO
var _hold_timer: float = 0.0
const HOLD_FIRST_DELAY: float = 0.22   # pause before repeat starts
const HOLD_REPEAT_DELAY: float = 0.10  # step interval while held


func _ready() -> void:
	entity_id = "player"
	display_name = "Player"
	faction = "player"

	grid_position = GameState.player_position
	snap_to_grid()

	_setup_visual("@", Color(0.95, 0.95, 0.72, 1))

	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.equipment_changed.connect(_refresh_stats)
	EventBus.player_stats_changed.connect(_refresh_stats)
	_refresh_stats()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act:
		return
	if TurnManager.is_active and not TurnManager.is_player_turn:
		return

	# Direction key pressed — move immediately and start hold tracking.
	var dir: Vector2i = Vector2i.ZERO
	if event.is_action_pressed("move_up"):    dir = Vector2i(0, -1)
	elif event.is_action_pressed("move_down"):  dir = Vector2i(0,  1)
	elif event.is_action_pressed("move_left"):  dir = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"): dir = Vector2i( 1, 0)

	if dir != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		_hold_dir   = dir
		_hold_timer = HOLD_FIRST_DELAY
		_try_move(dir)
		return

	# Direction key released — stop hold.
	if event.is_action_released("move_up") or event.is_action_released("move_down") or \
	   event.is_action_released("move_left") or event.is_action_released("move_right"):
		_hold_dir = Vector2i.ZERO
		return

	# God mode toggle (ù key, unicode 249).
	if event is InputEventKey and (event as InputEventKey).unicode == 249 and event.is_pressed() and not event.is_echo():
		_god_mode = not _god_mode
		var state: String = "ON" if _god_mode else "OFF"
		EventBus.combat_log.emit("GOD MODE: " + state)
		get_viewport().set_input_as_handled()
		return

	# Status screen toggle (C key).
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_C \
			and event.is_pressed() and not event.is_echo():
		EventBus.toggle_status_screen.emit()
		get_viewport().set_input_as_handled()
		return

	# Abilità di classe (Q).
	if event.is_action_pressed("class_ability"):
		var runtime: Node = get_node_or_null("/root/ClassRuntime")
		if runtime and runtime.can_use_active():
			if runtime.call("uses_targeting"):
				runtime.call("start_targeting", self)
				# _action_done() chiamato da confirm_targeting dopo la scelta del tile
			elif runtime.call("uses_menu"):
				runtime.call("start_menu", self)
				# _action_done() chiamato da confirm_menu dopo la scelta nel menu
			else:
				runtime.use_active()
				_action_done()
		get_viewport().set_input_as_handled()
		return

	# Non-directional actions.
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("save_game"):
		if SaveManager.can_save_here():
			SaveManager.save_game()
		else:
			EventBus.notification_shown.emit(Notification.warning("Non puoi salvare in questa zona."))
	elif event.is_action_pressed("load_game"):
		_do_load()
	elif event.is_action_pressed("open_inventory"):
		EventBus.inventory_changed.emit()


func _process(delta: float) -> void:
	if _hold_dir == Vector2i.ZERO:
		return
	if not _can_act:
		_hold_dir = Vector2i.ZERO
		return
	# In combat, wait for our turn without resetting the held direction.
	if TurnManager.is_active and not TurnManager.is_player_turn:
		return

	# Check that the key is still physically held.
	var still_held: bool = (
		(_hold_dir == Vector2i(0, -1) and Input.is_action_pressed("move_up"))   or
		(_hold_dir == Vector2i(0,  1) and Input.is_action_pressed("move_down")) or
		(_hold_dir == Vector2i(-1, 0) and Input.is_action_pressed("move_left")) or
		(_hold_dir == Vector2i( 1, 0) and Input.is_action_pressed("move_right"))
	)
	if not still_held:
		_hold_dir = Vector2i.ZERO
		return

	_hold_timer -= delta
	if _hold_timer <= 0.0:
		_hold_timer = HOLD_REPEAT_DELAY
		_try_move(_hold_dir)


func _try_move(dir: Vector2i) -> void:
	var target: Vector2i = grid_position + dir
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return

	var entity_at: Node = map.get_entity_at(target)
	if entity_at != null:
		if entity_at.faction == "enemy":
			CombatManager.attack(self, entity_at)
			_action_done()
			return
		# Blocking entity (closed door, NPC, etc.) — use interact key to open/use
		if entity_at.is_blocking:
			return

	var runtime: Node = get_node_or_null("/root/ClassRuntime")
	if not map.is_walkable(target):
		if not (runtime and runtime.call("can_phase_walls")):
			return
		if target.x < 0 or target.y < 0 or target.x >= map.map_width or target.y >= map.map_height:
			return
		if not runtime.call("can_enter_wall_at", map, target):
			return

	var transition: Variant = map.get_transition_at(target)
	if transition != null:
		var t: Dictionary = transition as Dictionary
		_hold_dir = Vector2i.ZERO
		GameState.player_position = target
		WorldManager.change_map(str(t["target_id"]), t["target_position"] as Vector2i)
		return

	move_to(target)
	GameState.player_position = target
	EventBus.player_moved.emit(target)
	_action_done()


func _try_interact() -> void:
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return
	# Save point: player stands on it and presses interact.
	if map.has_save_point_at(grid_position):
		_use_save_point()
		return
	var dirs: Array[Vector2i] = [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]
	for d: Vector2i in dirs:
		var adj: Vector2i = grid_position + d
		var entity_at: Node = map.get_entity_at(adj)
		if entity_at != null and entity_at.has_method("interact"):
			entity_at.interact(self)
			_action_done()
			return


func _use_save_point() -> void:
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return
	_can_act = false
	_hold_dir = Vector2i.ZERO
	ScreenFade.fade(
		func() -> void:
			var ally_mgr: Node = get_node_or_null("/root/AllyManager")
			if ally_mgr:
				ally_mgr.call("clear_temp_allies")
			map.respawn_non_boss_enemies()
			LocationRegistry.respawn_non_boss_enemies_in_unloaded_floors(GameState.current_map_id)
			GameState.player_stats["hp"]      = int(GameState.player_stats["max_hp"])
			GameState.player_stats["mp"]      = int(GameState.player_stats["max_mp"])
			GameState.player_stats["stamina"] = int(GameState.player_stats["max_stamina"])
			EventBus.player_stats_changed.emit()
			SaveManager.save_game(),
		func() -> void:
			EventBus.save_point_used.emit()
			EventBus.notification_shown.emit(Notification.save_point())
			_can_act = true
	)


func _action_done() -> void:
	EventBus.turn_ended.emit(self)
	TurnManager.on_player_action_done()


func _refresh_stats() -> void:
	level   = GameState.level
	hp      = GameState.player_stats["hp"]
	max_hp  = GameState.player_stats["max_hp"]
	attack  = GameState.player_stats["attack"] + Equipment.get_attack_bonus()
	defense = GameState.player_stats["defense"] + Equipment.get_defense_bonus()
	# mp and stamina live in GameState only — no Entity field needed


func take_damage(amount: int) -> void:
	if _god_mode:
		return
	GameState.damage_player(amount)
	hp = GameState.player_stats["hp"]
	if hp <= 0:
		is_dead = true


func flee_attempt() -> void:
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return
	if randf() > 0.70:
		EventBus.combat_log.emit("Non riesci a fuggire!")
		_action_done()
		return
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d: Vector2i in dirs:
		var target: Vector2i = grid_position + d
		if map.is_walkable(target) and map.get_entity_at(target) == null:
			move_to(target)
			GameState.player_position = target
			EventBus.player_moved.emit(target)
			EventBus.combat_log.emit("Ti allontani dal nemico!")
			_action_done()
			return
	EventBus.combat_log.emit("Sei circondato, impossibile fuggire!")
	_action_done()


func _on_dialogue_started(_id: String) -> void:
	_can_act = false
	_hold_dir = Vector2i.ZERO


func _on_dialogue_ended(_id: String) -> void:
	_can_act = true


func _do_load() -> void:
	if GameState.world_name == "" or GameState.character_name == "":
		return
	WorldManager.discard_current_map()
	if SaveManager.load_game(GameState.world_name, GameState.character_name):
		WorldManager.change_map(GameState.current_map_id, GameState.player_position)
		print("Game loaded.")
