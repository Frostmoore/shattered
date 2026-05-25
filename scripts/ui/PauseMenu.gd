extends CanvasLayer
class_name PauseMenu

signal resume_requested()
signal inventory_requested()
signal status_requested()
signal quest_journal_requested()
signal faction_screen_requested()
signal options_requested()
signal main_menu_requested()

@onready var save_btn: Button = $Panel/VBox/SaveButton


func _ready() -> void:
	visible = false
	$Panel/VBox/ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	$Panel/VBox/InventoryButton.pressed.connect(func() -> void: inventory_requested.emit())
	$Panel/VBox/StatusButton.pressed.connect(func() -> void: status_requested.emit())
	$Panel/VBox/QuestJournalButton.pressed.connect(func() -> void: quest_journal_requested.emit())
	$Panel/VBox/FactionScreenButton.pressed.connect(func() -> void: faction_screen_requested.emit())
	$Panel/VBox/OptionsButton.pressed.connect(func() -> void: options_requested.emit())
	$Panel/VBox/SaveButton.pressed.connect(_on_save)
	$Panel/VBox/LoadButton.pressed.connect(_on_load)
	$Panel/VBox/MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_menu"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_J and ke.is_pressed() and not ke.is_echo():
			get_viewport().set_input_as_handled()
			quest_journal_requested.emit()
		if ke.keycode == KEY_G and ke.is_pressed() and not ke.is_echo():
			get_viewport().set_input_as_handled()
			faction_screen_requested.emit()


func open_pause() -> void:
	save_btn.visible = SaveManager.can_save_here()
	visible = true
	get_tree().paused = true


func close_pause() -> void:
	visible = false
	get_tree().paused = false


func hide_panel() -> void:
	visible = false


func _on_save() -> void:
	SaveManager.save_game()


func _on_load() -> void:
	if not SaveManager.has_current_save():
		return
	WorldManager.discard_current_map()
	close_pause()
	SaveManager.load_game(GameState.world_name, GameState.character_name)
	WorldManager.change_map(GameState.current_map_id, GameState.player_position)
