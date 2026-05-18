extends CanvasLayer
class_name GameOver

signal restart_requested()
signal main_menu_requested()

func _ready() -> void:
	visible = false
	EventBus.player_died.connect(_on_player_died)
	$Panel/VBox/RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	$Panel/VBox/MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())
	$Panel/VBox/QuitButton.pressed.connect(func() -> void: get_tree().quit())


func _on_player_died() -> void:
	visible = true
	get_tree().paused = true


func hide_panel() -> void:
	visible = false
