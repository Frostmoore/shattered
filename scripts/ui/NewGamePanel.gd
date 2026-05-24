extends CanvasLayer
class_name NewGamePanel

signal class_selection_requested(world_name: String, char_name: String, permadeath: bool)
signal cancelled()

const NEW_WORLD_LABEL: String = "[ + Nuovo mondo ]"

@onready var world_list: ItemList          = $Panel/VBox/WorldList
@onready var new_world_row: HBoxContainer  = $Panel/VBox/NewWorldRow
@onready var new_world_input: LineEdit     = $Panel/VBox/NewWorldRow/NewWorldInput
@onready var char_input: LineEdit          = $Panel/VBox/CharRow/CharInput
@onready var permadeath_check: CheckBox    = $Panel/VBox/PermadeathRow/PermadeathCheck
@onready var confirm_btn: Button           = $Panel/VBox/Buttons/ConfirmButton
@onready var cancel_btn: Button            = $Panel/VBox/Buttons/CancelButton
@onready var error_label: Label            = $Panel/VBox/ErrorLabel


func _ready() -> void:
	visible = false
	confirm_btn.pressed.connect(_on_confirm)
	cancel_btn.pressed.connect(_on_cancel)
	world_list.item_selected.connect(_on_world_selected)
	new_world_input.text_changed.connect(func(_t: String) -> void: error_label.text = "")
	char_input.text_changed.connect(func(_t: String) -> void: error_label.text = "")


func open() -> void:
	world_list.clear()
	world_list.add_item(NEW_WORLD_LABEL)
	for w: String in WorldSaveManager.list_worlds():
		world_list.add_item(w)
	world_list.select(0)
	_on_world_selected(0)
	new_world_input.text     = ""
	char_input.text          = LocaleManager.t("UI_NEWGAME_DEFAULT_CHAR_NAME")
	permadeath_check.button_pressed = false
	error_label.text         = ""
	visible = true
	new_world_input.grab_focus()


func close() -> void:
	visible = false


func _on_world_selected(index: int) -> void:
	var is_new: bool = (index == 0)
	new_world_row.visible = is_new
	error_label.text = ""
	if is_new:
		new_world_input.grab_focus()
	else:
		char_input.grab_focus()


func _on_confirm() -> void:
	var selected: PackedInt32Array = world_list.get_selected_items()
	if selected.is_empty():
		error_label.text = LocaleManager.t("UI_NEWGAME_ERR_SELECT_WORLD")
		return

	var index: int    = selected[0]
	var is_new: bool  = (index == 0)
	var wn: String    = ""

	if is_new:
		wn = _sanitize(new_world_input.text.strip_edges())
		if wn == "":
			error_label.text = LocaleManager.t("UI_NEWGAME_ERR_WORLD_NAME_EMPTY")
			return
		if WorldSaveManager.has_world(wn):
			error_label.text = LocaleManager.t("UI_NEWGAME_ERR_WORLD_EXISTS")
			return
	else:
		wn = world_list.get_item_text(index)

	var cn: String = _sanitize(char_input.text.strip_edges())
	if cn == "":
		error_label.text = LocaleManager.t("UI_NEWGAME_ERR_CHAR_NAME_EMPTY")
		return
	if SaveManager.list_characters(wn).has(cn):
		error_label.text = LocaleManager.t("UI_NEWGAME_ERR_CHAR_EXISTS")
		return

	close()
	class_selection_requested.emit(wn, cn, permadeath_check.button_pressed)


func _on_cancel() -> void:
	close()
	cancelled.emit()


func _sanitize(s: String) -> String:
	var result: String = ""
	for ch: String in s:
		if ch != "/" and ch != "\\" and ch != ":" and ch != "*" \
				and ch != "?" and ch != "\"" and ch != "<" \
				and ch != ">" and ch != "|":
			result += ch
	return result
