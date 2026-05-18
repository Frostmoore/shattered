extends CanvasLayer
class_name WorldSelectScreen

signal load_requested(world_name: String, char_name: String)
signal cancelled()

@onready var world_list: ItemList  = $Panel/OuterVBox/HBox/WorldCol/WorldList
@onready var char_list: ItemList   = $Panel/OuterVBox/HBox/CharCol/CharList
@onready var load_btn: Button      = $Panel/OuterVBox/VBox/LoadButton
@onready var cancel_btn: Button    = $Panel/OuterVBox/VBox/CancelButton
@onready var world_label: Label    = $Panel/OuterVBox/HBox/WorldCol/WorldLabel
@onready var char_label: Label     = $Panel/OuterVBox/HBox/CharCol/CharLabel

var _selected_world: String = ""
var _selected_char: String  = ""


func _ready() -> void:
	visible = false
	load_btn.pressed.connect(_on_load)
	cancel_btn.pressed.connect(_on_cancel)
	world_list.item_selected.connect(_on_world_selected)
	char_list.item_selected.connect(_on_char_selected)


func open() -> void:
	_selected_world = ""
	_selected_char  = ""
	load_btn.disabled = true
	char_list.clear()
	world_list.clear()
	var worlds: Array[String] = WorldSaveManager.list_worlds()
	for w: String in worlds:
		world_list.add_item(w)
	visible = true


func close() -> void:
	visible = false


func _on_world_selected(index: int) -> void:
	_selected_world = world_list.get_item_text(index)
	_selected_char  = ""
	load_btn.disabled = true
	char_list.clear()
	var chars: Array[String] = SaveManager.list_characters(_selected_world)
	for c: String in chars:
		char_list.add_item(c)


func _on_char_selected(index: int) -> void:
	_selected_char = char_list.get_item_text(index)
	load_btn.disabled = (_selected_world == "" or _selected_char == "")


func _on_load() -> void:
	if _selected_world == "" or _selected_char == "":
		return
	close()
	load_requested.emit(_selected_world, _selected_char)


func _on_cancel() -> void:
	close()
	cancelled.emit()
