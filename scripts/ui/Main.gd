extends Node

@onready var map_container: Node                   = $MapContainer
@onready var hud: CanvasLayer                      = $HUD
@onready var inventory_panel: InventoryPanel       = $InventoryPanel
@onready var game_over: GameOver                   = $GameOver
@onready var main_menu: MainMenu                   = $MainMenu
@onready var pause_menu: PauseMenu                 = $PauseMenu
@onready var options_menu: OptionsMenu             = $OptionsMenu
@onready var combat_bar: CombatBar                 = $CombatBar
@onready var quest_journal: QuestJournal           = $QuestJournal
@onready var new_game_panel: NewGamePanel          = $NewGamePanel
@onready var world_select_screen: WorldSelectScreen = $WorldSelectScreen

var _game_started: bool = false
var _options_from_main_menu: bool = false


func _ready() -> void:
	WorldManager.init(map_container)
	hud.visible = false
	_connect_menus()
	main_menu.show_menu()


func _connect_menus() -> void:
	main_menu.new_game_requested.connect(_show_new_game_panel)
	main_menu.load_requested.connect(_show_world_select)
	main_menu.options_requested.connect(_show_options_from_main)
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.inventory_requested.connect(_show_inventory_from_pause)
	pause_menu.quest_journal_requested.connect(_open_quest_journal)
	pause_menu.options_requested.connect(_show_options_from_pause)
	pause_menu.main_menu_requested.connect(_go_to_main_menu)
	options_menu.back_requested.connect(_hide_options)
	game_over.restart_requested.connect(_on_restart)
	game_over.main_menu_requested.connect(_go_to_main_menu)
	combat_bar.use_item_requested.connect(_show_inventory_from_combat)
	combat_bar.open_menu_requested.connect(_open_pause_from_bar)
	new_game_panel.confirmed.connect(_start_new_game)
	EventBus.player_died.connect(_on_player_died)
	new_game_panel.cancelled.connect(_show_main_menu_from_panel)
	world_select_screen.load_requested.connect(_load_game)
	world_select_screen.cancelled.connect(_show_main_menu_from_panel)


func _input(event: InputEvent) -> void:
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


func _show_new_game_panel() -> void:
	main_menu.hide_menu()
	new_game_panel.open()


func _show_world_select() -> void:
	main_menu.hide_menu()
	world_select_screen.open()


func _show_main_menu_from_panel() -> void:
	main_menu.show_menu()


func _start_new_game(world_name: String, char_name: String, permadeath_enabled: bool = false) -> void:
	get_tree().paused = false
	WorldManager.discard_current_map()
	_reset_game_state(world_name, char_name, permadeath_enabled)
	if WorldSaveManager.has_world(world_name):
		WorldSaveManager.load_world(world_name)
		LocationRegistry.clear_states()
	else:
		WorldSaveManager.generate_new_world(world_name)
	_launch_game("overworld", Vector2i(5, 5))


func _load_game(world_name: String, char_name: String) -> void:
	get_tree().paused = false
	WorldManager.discard_current_map()
	SaveManager.load_game(world_name, char_name)
	_launch_game(GameState.current_map_id, GameState.player_position)


func _launch_game(map_id: String, pos: Vector2i) -> void:
	hud.visible = true
	combat_bar.visible = true
	_game_started = true
	WorldManager.change_map(map_id, pos)


func _resume_game() -> void:
	pause_menu.close_pause()


func _show_inventory_from_pause() -> void:
	pause_menu.close_pause()
	inventory_panel.open()


func _show_inventory_from_combat() -> void:
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
	pause_menu.visible = false
	quest_journal.visible = false
	game_over.hide_panel()
	hud.visible = false
	combat_bar.visible = false
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


func _reset_game_state(world_name: String, char_name: String, permadeath: bool = false) -> void:
	GameState.world_name      = world_name
	GameState.character_name  = char_name
	GameState.permadeath      = permadeath
	GameState.level           = 1
	GameState.xp              = 0
	GameState.current_map_id  = "overworld"
	GameState.player_position = Vector2i(5, 5)
	GameState.player_stats    = {"hp": 20, "max_hp": 20, "attack": 4, "defense": 1, "gold": 0}
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
		"helm": "", "armor": "", "left_hand": "", "right_hand": "",
		"ring_1": "", "ring_2": "", "amulet": "", "boots": "",
		"cloak": "", "accessory": ""
	}
	GameState.quick_slots      = ["", "", ""]
	Inventory.add_item("rusty_sword",   1, false)
	Inventory.add_item("leather_armor", 1, false)
	Inventory.add_item("leather_helm",  1, false)
	Inventory.add_item("leather_boots", 1, false)
	Inventory.add_item("lucky_ring",    1, false)
	Inventory.add_item("small_potion",  1, false)
