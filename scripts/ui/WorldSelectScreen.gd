extends CanvasLayer
class_name WorldSelectScreen

signal load_requested(world_name: String, char_name: String)
signal cancelled()

@onready var world_list:       ItemList           = $Panel/OuterVBox/HBox/WorldCol/WorldList
@onready var char_list:        ItemList           = $Panel/OuterVBox/HBox/CharCol/CharList
@onready var load_btn:         Button             = $Panel/OuterVBox/Buttons/LoadButton
@onready var cancel_btn:       Button             = $Panel/OuterVBox/Buttons/CancelButton
@onready var del_world_btn:    Button             = $Panel/OuterVBox/HBox/WorldCol/DeleteWorldButton
@onready var del_char_btn:     Button             = $Panel/OuterVBox/HBox/CharCol/DeleteCharButton
@onready var confirm_dialog:   ConfirmationDialog = $ConfirmDialog

var _selected_world: String = ""
var _selected_char:  String = ""
var _pending_action: String = ""  # "world" | "char"


func _ready() -> void:
	visible = false
	load_btn.pressed.connect(_on_load)
	cancel_btn.pressed.connect(_on_cancel)
	world_list.item_selected.connect(_on_world_selected)
	char_list.item_selected.connect(_on_char_selected)
	del_world_btn.pressed.connect(_on_delete_world_pressed)
	del_char_btn.pressed.connect(_on_delete_char_pressed)
	confirm_dialog.confirmed.connect(_on_delete_confirmed)


func open() -> void:
	_selected_world = ""
	_selected_char  = ""
	_pending_action = ""
	load_btn.disabled      = true
	del_world_btn.disabled = true
	del_char_btn.disabled  = true
	char_list.clear()
	world_list.clear()
	for w: String in WorldSaveManager.list_worlds():
		world_list.add_item(w)
	visible = true


func close() -> void:
	visible = false


func _on_world_selected(index: int) -> void:
	_selected_world        = world_list.get_item_text(index)
	_selected_char         = ""
	load_btn.disabled      = true
	del_world_btn.disabled = false
	del_char_btn.disabled  = true
	char_list.clear()
	for c: String in SaveManager.list_characters(_selected_world):
		char_list.add_item(c)


func _on_char_selected(index: int) -> void:
	_selected_char        = char_list.get_item_text(index)
	load_btn.disabled     = (_selected_world == "" or _selected_char == "")
	del_char_btn.disabled = (_selected_char == "")


func _on_load() -> void:
	if _selected_world == "" or _selected_char == "":
		return
	close()
	load_requested.emit(_selected_world, _selected_char)


func _on_cancel() -> void:
	close()
	cancelled.emit()


func _on_delete_world_pressed() -> void:
	if _selected_world == "":
		return
	_pending_action = "world"
	var char_count: int = SaveManager.list_characters(_selected_world).size()
	var detail: String  = LocaleManager.t("UI_WORLDSELECT_DELETE_WORLD_DETAIL", {"count": char_count, "suffix": "i" if char_count != 1 else "io"}) if char_count > 0 else ""
	confirm_dialog.title       = LocaleManager.t("UI_WORLDSELECT_DELETE_WORLD_TITLE")
	confirm_dialog.dialog_text = LocaleManager.t("UI_WORLDSELECT_DELETE_WORLD_TEXT", {"name": _selected_world, "detail": detail})
	confirm_dialog.popup_centered()


func _on_delete_char_pressed() -> void:
	if _selected_world == "" or _selected_char == "":
		return
	_pending_action = "char"
	confirm_dialog.title       = LocaleManager.t("UI_WORLDSELECT_DELETE_CHAR_TITLE")
	confirm_dialog.dialog_text = LocaleManager.t("UI_WORLDSELECT_DELETE_CHAR_TEXT", {"name": _selected_char})
	confirm_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	match _pending_action:
		"world":
			WorldSaveManager.delete_world(_selected_world)
		"char":
			SaveManager.delete_character_save(_selected_world, _selected_char)
	_pending_action = ""
	open()
