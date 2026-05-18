extends CanvasLayer
class_name MainMenu

signal new_game_requested()
signal load_requested()
signal options_requested()

@onready var load_btn: Button = $Panel/VBox/LoadButton


func _ready() -> void:
	visible = true
	$Panel/VBox/NewGameButton.pressed.connect(func() -> void: new_game_requested.emit())
	load_btn.pressed.connect(func() -> void: load_requested.emit())
	$Panel/VBox/OptionsButton.pressed.connect(func() -> void: options_requested.emit())
	$Panel/VBox/QuitButton.pressed.connect(func() -> void: get_tree().quit())
	load_btn.disabled = not SaveManager.has_any_save()


func show_menu() -> void:
	visible = true
	load_btn.disabled = not SaveManager.has_any_save()


func hide_menu() -> void:
	visible = false
