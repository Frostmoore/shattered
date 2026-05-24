@tool
extends EditorPlugin

var _window: Window = null


func _enter_tree() -> void:
	add_tool_menu_item("City Builder...", _open_window)


func _exit_tree() -> void:
	remove_tool_menu_item("City Builder...")
	if is_instance_valid(_window):
		_window.queue_free()
	_window = null


func _open_window() -> void:
	if is_instance_valid(_window):
		_window.show()
		_window.grab_focus()
		return
	var PanelScript: GDScript = load("res://addons/city_builder/CityBuilderPanel.gd")
	var panel: Control = PanelScript.new()
	_window = Window.new()
	_window.title = "City Builder"
	_window.min_size = Vector2i(1100, 650)
	_window.close_requested.connect(func() -> void: _window.hide())
	_window.add_child(panel)
	EditorInterface.get_base_control().add_child(_window)
	_window.popup_centered_ratio(0.85)
