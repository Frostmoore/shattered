@tool
extends Control

var on_draw:  Callable
var on_input: Callable


func _draw() -> void:
	if on_draw.is_valid():
		on_draw.call()


func _gui_input(event: InputEvent) -> void:
	if on_input.is_valid():
		on_input.call(event)
