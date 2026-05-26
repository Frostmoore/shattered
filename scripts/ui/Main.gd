extends Node

@onready var map_container: Node                   = $MapContainer
@onready var _hud_v2: HUDV2                        = $HUDV2
@onready var inventory_panel: InventoryPanel       = $InventoryPanel
@onready var game_over: GameOver                   = $GameOver
@onready var main_menu: MainMenu                   = $MainMenu
@onready var pause_menu: PauseMenu                 = $PauseMenu
@onready var options_menu: OptionsMenu             = $OptionsMenu
@onready var quest_journal: QuestJournal           = $QuestJournal
@onready var new_game_panel: NewGamePanel          = $NewGamePanel
@onready var world_select_screen: WorldSelectScreen = $WorldSelectScreen

var _game_started: bool = false
var _options_from_main_menu: bool = false

var _class_picker:    Node = null
var _respec_screen:   Node = null
var _faction_screen:  Node = null
var _quick_food_menu: Node = null
var _pending_world: String = ""
var _pending_char: String  = ""
var _pending_pd: bool      = false



func _ready() -> void:
	WorldManager.init(map_container)
	_hud_v2.visible = false
	_setup_class_picker()
	_setup_respec_screen()
	_setup_faction_screen()
	_setup_quick_food_menu()
	_setup_targeting_overlay()
	_setup_enemy_tooltip()
	_connect_menus()
	_connect_needs_signals()
	main_menu.show_menu()
	_setup_debug_screen()


func _setup_respec_screen() -> void:
	_respec_screen = load("res://scripts/ui/ClassRespecScreen.gd").new()
	add_child(_respec_screen)
	_respec_screen.class_confirmed.connect(_on_respec_confirmed)
	EventBus.respec_screen_requested.connect(_on_respec_screen_requested)


func _on_respec_screen_requested() -> void:
	if _respec_screen:
		_respec_screen.open()


func _on_respec_confirmed(class_id: String) -> void:
	Inventory.remove_item("class_license", 1)
	var svc: Node = get_node_or_null("/root/ClassRespecService")
	if svc:
		svc.call("respec", class_id)


func _setup_faction_screen() -> void:
	_faction_screen = load("res://scripts/ui/FactionScreen.gd").new()
	add_child(_faction_screen)
	pause_menu.faction_screen_requested.connect(_open_faction_screen)


func _open_faction_screen() -> void:
	pause_menu.hide_panel()
	_faction_screen.open()


func _setup_quick_food_menu() -> void:
	_quick_food_menu = load("res://scripts/ui/QuickFoodMenu.gd").new()
	_quick_food_menu.name = "QuickFoodMenu"
	add_child(_quick_food_menu)


func _connect_needs_signals() -> void:
	EventBus.need_warning.connect(_on_need_state_changed.bind("warning"))
	EventBus.need_critical.connect(_on_need_state_changed.bind("critical"))
	EventBus.need_depleted.connect(_on_need_state_changed.bind("depleted"))
	EventBus.disease_acquired.connect(_on_disease_acquired_log)
	EventBus.disease_progressed.connect(_on_disease_progressed_log)
	EventBus.disease_regressed.connect(_on_disease_regressed_log)
	EventBus.disease_cured.connect(_on_disease_cured_log)
	EventBus.meal_hint.connect(_on_meal_hint)
	EventBus.player_collapsed.connect(_on_player_collapsed)


func _on_need_state_changed(need: String, level: String) -> void:
	var key: String = "NOTIF_NEEDS_" + need.to_upper() + "_" + level.to_upper()
	var msg: String = LocaleManager.t(key)
	EventBus.notification_shown.emit(Notification.warning(msg))
	EventBus.combat_log.emit(msg)


func _on_disease_acquired_log(_disease_id: String, display_name: String) -> void:
	EventBus.combat_log.emit(LocaleManager.t("NOTIF_DISEASE_ACQUIRED", {"name": display_name}))


func _on_disease_progressed_log(_disease_id: String, display_name: String, stage_label: String) -> void:
	EventBus.combat_log.emit(LocaleManager.t("NOTIF_DISEASE_PROGRESSED",
		{"name": display_name, "stage": stage_label}))


func _on_disease_regressed_log(_disease_id: String, display_name: String, stage_label: String) -> void:
	EventBus.combat_log.emit(LocaleManager.t("NOTIF_DISEASE_REGRESSED",
		{"name": display_name, "stage": stage_label}))


func _on_disease_cured_log(disease_id: String) -> void:
	var dis_reg: Node = get_node_or_null("/root/DiseaseRegistry")
	var display_name: String = disease_id
	if dis_reg:
		var def: Dictionary = dis_reg.call("get_def", disease_id)
		display_name = str(def.get("name", disease_id))
	EventBus.combat_log.emit(LocaleManager.t("NOTIF_DISEASE_CURED", {"name": display_name}))


func _on_meal_hint(meal: String) -> void:
	var key: String = "NOTIF_MEAL_" + meal.to_upper()
	EventBus.combat_log.emit(LocaleManager.t_or(key, meal))


func _on_player_collapsed() -> void:
	EventBus.combat_log.emit(LocaleManager.t("NOTIF_PLAYER_COLLAPSED"))
	if not _game_started:
		return
	ScreenFade.fade(
		func() -> void:
			TimeManager.advance(60, { "activity": "sleep" })
			GameState.exhaustion = maxf(0.0, GameState.exhaustion - 25.0)
			var max_hp: int = int(GameState.player_stats.get("max_hp", 1))
			var loss:   int = maxi(1, int(max_hp * 0.10))
			GameState.player_stats["hp"] = maxi(1, int(GameState.player_stats.get("hp", 1)) - loss)
			EventBus.player_stats_changed.emit(),
		Callable()
	)


func _setup_targeting_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name  = "TargetingLayer"
	layer.layer = 95
	add_child(layer)
	var overlay: Node = load("res://scripts/ui/TargetingOverlay.gd").new()
	overlay.name = "TargetingOverlay"
	layer.add_child(overlay)
	var runtime: Node = get_node_or_null("/root/ClassRuntime")
	if runtime:
		runtime.call("register_targeting_overlay", overlay)


func _setup_enemy_tooltip() -> void:
	var layer := CanvasLayer.new()
	layer.name  = "EnemyTooltipLayer"
	layer.layer = 90
	add_child(layer)
	var tooltip: Node = load("res://scripts/ui/EnemyTooltip.gd").new()
	tooltip.name = "EnemyTooltip"
	layer.add_child(tooltip)
	var targeting_overlay: Node = get_node_or_null("TargetingLayer/TargetingOverlay")
	if targeting_overlay:
		tooltip.set("_targeting_overlay", targeting_overlay)


func _setup_class_picker() -> void:
	_class_picker = load("res://scripts/ui/ClassPickerPanel.gd").new()
	add_child(_class_picker)
	_class_picker.class_confirmed.connect(_on_class_confirmed)
	_class_picker.cancelled.connect(_on_class_picker_cancelled)


func _connect_menus() -> void:
	main_menu.new_game_requested.connect(_show_new_game_panel)
	main_menu.load_requested.connect(_show_world_select)
	main_menu.options_requested.connect(_show_options_from_main)
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.inventory_requested.connect(_show_inventory_from_pause)
	pause_menu.status_requested.connect(_show_status_from_pause)
	pause_menu.quest_journal_requested.connect(_open_quest_journal)
	pause_menu.options_requested.connect(_show_options_from_pause)
	pause_menu.main_menu_requested.connect(_go_to_main_menu)
	options_menu.back_requested.connect(_hide_options)
	game_over.restart_requested.connect(_on_restart)
	game_over.main_menu_requested.connect(_go_to_main_menu)
	_hud_v2.use_item_requested.connect(_show_inventory_from_combat)
	_hud_v2.open_menu_requested.connect(_open_pause_from_bar)
	new_game_panel.class_selection_requested.connect(_on_class_selection_requested)
	EventBus.player_died.connect(_on_player_died)
	new_game_panel.cancelled.connect(_show_main_menu_from_panel)
	world_select_screen.load_requested.connect(_load_game)
	world_select_screen.cancelled.connect(_show_main_menu_from_panel)


func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		return
	if event.is_action_pressed("open_menu"):
		if options_menu.visible or pause_menu.visible:
			return
		get_viewport().set_input_as_handled()
		pause_menu.open_pause()
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_J and ke.is_pressed() and not ke.is_echo():
			if quest_journal.visible:
				quest_journal.close()
			else:
				_open_quest_journal()
			get_viewport().set_input_as_handled()
		if ke.keycode == KEY_F and ke.is_pressed() and not ke.is_echo():
			if _quick_food_menu:
				if _quick_food_menu.visible:
					_quick_food_menu.close()
				else:
					_quick_food_menu.open()
				get_viewport().set_input_as_handled()
		if ke.keycode == KEY_G and ke.is_pressed() and not ke.is_echo():
			if _faction_screen and _faction_screen.visible:
				_faction_screen.close()
			else:
				_open_faction_screen()
			get_viewport().set_input_as_handled()
		# Faction world actions — F5/F6/F7 (also triggerable via NPC dialogue)
		if ke.is_pressed() and not ke.is_echo():
			var fas: Node = get_node_or_null("/root/FactionActionsService")
			if fas != null:
				match ke.keycode:
					KEY_F5:
						fas.call("try_deposit_map")
						get_viewport().set_input_as_handled()
					KEY_F6:
						fas.call("try_build_post_station")
						get_viewport().set_input_as_handled()
					KEY_F7:
						fas.call("try_open_ambulatorio")
						get_viewport().set_input_as_handled()


func _show_new_game_panel() -> void:
	main_menu.hide_menu()
	new_game_panel.open()


func _show_world_select() -> void:
	main_menu.hide_menu()
	world_select_screen.open()


func _show_main_menu_from_panel() -> void:
	main_menu.show_menu()


func _on_class_selection_requested(world_name: String, char_name: String, permadeath: bool) -> void:
	_pending_world = world_name
	_pending_char  = char_name
	_pending_pd    = permadeath
	_class_picker.open()


func _on_class_confirmed(class_id: String) -> void:
	_start_new_game(_pending_world, _pending_char, _pending_pd, class_id)


func _on_class_picker_cancelled() -> void:
	new_game_panel.open()


func _start_new_game(world_name: String, char_name: String,
		permadeath_enabled: bool = false, class_id: String = "noob") -> void:
	get_tree().paused = false
	WorldManager.discard_current_map()
	var start_minutes: int = 480
	if WorldSaveManager.has_world(world_name):
		var world_max: int = WorldSaveManager.get_world_max_minutes(world_name)
		start_minutes = (int(world_max / 1440.0) + 1) * 1440 + 480
		_reset_game_state(world_name, char_name, permadeath_enabled, class_id, start_minutes)
		WorldSaveManager.load_world(world_name)
		LocationRegistry.clear_states()
	else:
		_reset_game_state(world_name, char_name, permadeath_enabled, class_id)
		WorldSaveManager.generate_new_world(world_name)
	_launch_game("overworld", Vector2i(5, 5))


func _load_game(world_name: String, char_name: String) -> void:
	get_tree().paused = false
	WorldManager.discard_current_map()
	SaveManager.load_game(world_name, char_name)
	_launch_game(GameState.current_map_id, GameState.player_position)


func _launch_game(map_id: String, pos: Vector2i) -> void:
	_hud_v2.visible = true
	_game_started = true
	WorldManager.change_map(map_id, pos)


func _resume_game() -> void:
	pause_menu.close_pause()


func _show_inventory_from_pause() -> void:
	pause_menu.close_pause()
	inventory_panel.open()


func _show_status_from_pause() -> void:
	pause_menu.close_pause()
	EventBus.toggle_status_screen.emit()


func _show_inventory_from_combat() -> void:
	var runtime: Node = get_node_or_null("/root/ClassRuntime")
	if runtime and not runtime.can_use_item_in_combat():
		EventBus.notification_shown.emit(
			Notification.warning(LocaleManager.t("UI_WARN_CANT_USE_ITEMS")))
		return
	inventory_panel.open()


func _show_options_from_main() -> void:
	_options_from_main_menu = true
	main_menu.hide_menu()
	options_menu.show_options()


func _show_options_from_pause() -> void:
	_options_from_main_menu = false
	pause_menu.hide_panel()
	options_menu.show_options()


func _hide_options() -> void:
	options_menu.visible = false
	if _options_from_main_menu:
		main_menu.show_menu()
	else:
		pause_menu.visible = true


func _go_to_main_menu() -> void:
	_game_started = false
	get_tree().paused = false
	pause_menu.visible = false
	quest_journal.visible = false
	if _faction_screen:
		_faction_screen.visible = false
	game_over.hide_panel()
	_hud_v2.visible = false
	main_menu.show_menu()


func _open_quest_journal() -> void:
	quest_journal.open()


func _open_pause_from_bar() -> void:
	if not _game_started:
		return
	if options_menu.visible or pause_menu.visible:
		return
	pause_menu.open_pause()


func _on_player_died() -> void:
	if GameState.permadeath and GameState.world_name != "" and GameState.character_name != "":
		SaveManager.delete_character_save(GameState.world_name, GameState.character_name)


func _setup_debug_screen() -> void:
	if not OS.is_debug_build():
		return
	add_child(load("res://scripts/debug/DebugScreen.gd").new())


func _on_restart() -> void:
	var world_name: String    = GameState.world_name
	var char_name: String     = GameState.character_name
	var was_permadeath: bool  = GameState.permadeath
	if world_name == "" or char_name == "":
		game_over.hide_panel()
		get_tree().paused = false
		_go_to_main_menu()
		return
	WorldManager.discard_current_map()
	_reset_game_state(world_name, char_name, was_permadeath)
	WorldSaveManager.generate_new_world(world_name)
	get_tree().paused = false
	game_over.hide_panel()
	_launch_game("overworld", Vector2i(5, 5))


func _reset_game_state(world_name: String, char_name: String, permadeath: bool = false,
		class_id: String = "noob", start_minutes: int = 480) -> void:
	GameState.world_name      = world_name
	GameState.character_name  = char_name
	GameState.permadeath      = permadeath
	GameState.level           = 1
	GameState.xp              = 0
	GameState.total_minutes   = start_minutes
	GameState.current_map_id  = "overworld"
	GameState.player_position = Vector2i(5, 5)
	GameState.run_milestones  = {}
	var _base_val: int = 10 if class_id == "eletto" else 5
	GameState.base_attributes = {"str": _base_val, "dex": _base_val, "int": _base_val, "vit": _base_val, "wil": _base_val}
	GameState.class_bonus     = {"str": 0, "dex": 0, "int": 0, "vit": 0, "wil": 0}
	GameState.player_stats    = {
		"hp": 25, "max_hp": 25, "mp": 20, "max_mp": 20,
		"stamina": 20, "max_stamina": 20, "attack": 4, "defense": 1, "gold": 0
	}
	GameState.apply_class(class_id)  # applica respec_bonus e ricalcola
	GameState.world_flags     = {
		"intro_completed": false,
		"dungeon_boss_defeated": false,
		"village_quest_completed": false
	}
	GameState.active_quests    = []
	GameState.ready_quests     = []
	GameState.completed_quests = []
	GameState.inventory        = []
	GameState.equipped         = {
		"head": "", "body": "", "left_hand": "", "right_hand": "",
		"ring_1": "", "ring_2": "", "neck": "", "feet": "",
		"cloak": "", "trinket": "", "hands": ""
	}
	GameState.quick_slots      = ["", "", "", "", ""]
	GameState.explored_tiles   = {}
	GameState.food            = 100.0
	GameState.water           = 100.0
	GameState.exhaustion      = 0.0
	GameState.temperature     = 0.0
	GameState.active_diseases = []
	GameState.needs_modifiers = {}
	FactionReputation.initialize_for_new_game()
	FactionMembership.initialize_for_new_game()
	CrimeSystem.initialize_for_new_game()
	Inventory.add_item("rusty_sword",    1, false)
	Inventory.add_item("leather_armor",  1, false)
	Inventory.add_item("leather_helm",   1, false)
	Inventory.add_item("leather_boots",  1, false)
	Inventory.add_item("lucky_ring",     1, false)
	Inventory.add_item("pozione_piccola", 1, false)
	var _test_leg: Dictionary = ItemGenerator.drop("spada_dell_alba", GameState.level)
	Inventory.add_item_instance(_test_leg, false)
	Inventory.add_item("pergamena_identificazione", 1, false)
