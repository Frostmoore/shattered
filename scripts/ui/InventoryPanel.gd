extends CanvasLayer
class_name InventoryPanel

@onready var panel: PanelContainer     = $Panel
@onready var paper_doll: GridContainer = $Panel/VBox/ContentHBox/DollSection/PaperDoll
@onready var bag_grid: GridContainer   = $Panel/VBox/ContentHBox/BagSection/BagGrid
@onready var action_row: HBoxContainer = $Panel/VBox/ContentHBox/BagSection/ActionRow
@onready var action_btn: Button        = $Panel/VBox/ContentHBox/BagSection/ActionRow/ActionButton
@onready var slot_row: HBoxContainer   = $Panel/VBox/ContentHBox/BagSection/SlotRow
@onready var slot1_btn: Button         = $Panel/VBox/ContentHBox/BagSection/SlotRow/Slot1Btn
@onready var slot2_btn: Button         = $Panel/VBox/ContentHBox/BagSection/SlotRow/Slot2Btn
@onready var slot3_btn: Button         = $Panel/VBox/ContentHBox/BagSection/SlotRow/Slot3Btn
@onready var tooltip: PanelContainer   = $Tooltip
@onready var tooltip_lbl: Label        = $Tooltip/TooltipLabel

var _is_open: bool = false
var _selected_item: String = ""
var _slot_assign_btns: Array[Button] = []
var _doll_btns: Dictionary = {}
var _bag_btns: Array[Button] = []

const DOLL_LAYOUT: Array[String] = [
	"",          "helm",      "",
	"cloak",     "armor",     "amulet",
	"left_hand", "",          "right_hand",
	"ring_1",    "boots",     "ring_2",
	"",          "accessory", ""
]

const SLOT_ICONS: Dictionary = {
	"helm":       "^",
	"armor":      "[",
	"left_hand":  "(",
	"right_hand": "/",
	"ring_1":     "o",
	"ring_2":     "o",
	"amulet":     "+",
	"boots":      "u",
	"cloak":      "~",
	"accessory":  "*"
}

const SLOT_NAMES: Dictionary = {
	"helm":       "Elmo",
	"armor":      "Armatura",
	"left_hand":  "Mano sinistra",
	"right_hand": "Mano destra",
	"ring_1":     "Anello 1",
	"ring_2":     "Anello 2",
	"amulet":     "Amuleto",
	"boots":      "Stivali",
	"cloak":      "Mantello",
	"accessory":  "Accessorio"
}


func _ready() -> void:
	EventBus.inventory_changed.connect(_refresh_if_open)
	EventBus.equipment_changed.connect(_refresh_if_open)
	EventBus.quick_slots_changed.connect(_refresh_if_open)
	panel.visible = false
	tooltip.visible = false
	$Panel/VBox/TitleRow/CloseButton.pressed.connect(_close)
	action_btn.pressed.connect(_on_action_pressed)
	_slot_assign_btns = [slot1_btn, slot2_btn, slot3_btn]
	for i: int in 3:
		var idx := i
		_slot_assign_btns[i].pressed.connect(func() -> void: _assign_slot(idx))
	_build_paper_doll()


func _process(_delta: float) -> void:
	if not tooltip.visible:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var mp: Vector2 = get_viewport().get_mouse_position()
	var pos: Vector2 = mp + Vector2(14.0, 14.0)
	if tooltip.size.x > 0.0:
		if pos.x + tooltip.size.x > vp.x:
			pos.x = mp.x - tooltip.size.x - 14.0
		if pos.y + tooltip.size.y > vp.y:
			pos.y = mp.y - tooltip.size.y - 14.0
	tooltip.position = pos


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		get_viewport().set_input_as_handled()
		if _is_open:
			_close()
		else:
			_open()
	elif event.is_action_pressed("ui_cancel") and _is_open:
		get_viewport().set_input_as_handled()
		_close()


func open() -> void:
	_open()


func _open() -> void:
	_refresh()
	panel.visible = true
	_is_open = true


func _close() -> void:
	panel.visible = false
	tooltip.visible = false
	_is_open = false
	_selected_item = ""


func _refresh(_arg: Variant = null) -> void:
	_refresh_paper_doll()
	_rebuild_bag_grid()
	_update_action_area()


func _build_paper_doll() -> void:
	for slot_name: String in DOLL_LAYOUT:
		if slot_name == "":
			var spacer: Control = Control.new()
			spacer.custom_minimum_size = Vector2(44.0, 44.0)
			paper_doll.add_child(spacer)
		else:
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(44.0, 44.0)
			btn.add_theme_font_size_override("font_size", 16)
			btn.text = SLOT_ICONS.get(slot_name, "?")
			_style_doll_btn(btn, false)
			var sn := slot_name
			btn.pressed.connect(func() -> void: _on_doll_slot_pressed(sn))
			btn.mouse_entered.connect(func() -> void: _on_doll_hover_enter(sn))
			btn.mouse_exited.connect(func() -> void: _hide_tooltip())
			_doll_btns[slot_name] = btn
			paper_doll.add_child(btn)


func _refresh_paper_doll() -> void:
	for slot_name: String in _doll_btns:
		var btn: Button = _doll_btns[slot_name] as Button
		var item_id: String = str(GameState.equipped.get(slot_name, ""))
		if item_id != "":
			var data: Dictionary = ItemDB.get_item(item_id)
			btn.text = data.get("icon", SLOT_ICONS.get(slot_name, "?"))
			_style_doll_btn(btn, true)
		else:
			btn.text = SLOT_ICONS.get(slot_name, "?")
			_style_doll_btn(btn, false)


func _rebuild_bag_grid() -> void:
	for btn in _bag_btns:
		bag_grid.remove_child(btn)
		btn.queue_free()
	_bag_btns.clear()

	for entry: Dictionary in GameState.inventory:
		var item_id: String = str(entry["id"])
		var data: Dictionary = ItemDB.get_item(item_id)
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(44.0, 44.0)
		btn.add_theme_font_size_override("font_size", 16)
		btn.text = data.get("icon", "?")
		_style_bag_btn(btn, item_id)
		var iid := item_id
		btn.pressed.connect(func() -> void: _on_bag_item_pressed(iid))
		btn.mouse_entered.connect(func() -> void: _on_bag_hover_enter(iid))
		btn.mouse_exited.connect(func() -> void: _hide_tooltip())
		bag_grid.add_child(btn)
		_bag_btns.append(btn)


func _refresh_bag_styles() -> void:
	for i: int in mini(_bag_btns.size(), GameState.inventory.size()):
		_style_bag_btn(_bag_btns[i], str(GameState.inventory[i]["id"]))


func _style_doll_btn(btn: Button, filled: bool) -> void:
	if filled:
		btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.35, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55, 1.0))


func _style_bag_btn(btn: Button, item_id: String) -> void:
	if item_id == _selected_item:
		btn.add_theme_color_override("font_color", Color(0.35, 0.95, 0.35, 1.0))
	elif Equipment.is_equipped(item_id):
		btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.35, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.92, 1.0))


func _on_doll_slot_pressed(slot_name: String) -> void:
	var item_id: String = str(GameState.equipped.get(slot_name, ""))
	if item_id == "":
		return
	Equipment.unequip(slot_name)
	if _selected_item == item_id:
		_selected_item = ""
	_update_action_area()


func _on_bag_item_pressed(item_id: String) -> void:
	_selected_item = item_id
	_update_action_area()
	_refresh_bag_styles()


func _update_action_area() -> void:
	if _selected_item == "" or not _item_in_inventory(_selected_item):
		_selected_item = ""
		action_row.visible = false
		slot_row.visible = false
		return

	var data: Dictionary = ItemDB.get_item(_selected_item)
	var item_type: String = data.get("type", "")
	action_row.visible = true

	match item_type:
		"consumable":
			action_btn.text = "Usa"
			action_btn.disabled = false
			slot_row.visible = true
			_refresh_slot_btns()
		"equipment":
			action_btn.text = "Rimuovi" if Equipment.is_equipped(_selected_item) else "Equipaggia"
			action_btn.disabled = false
			slot_row.visible = false
		"key":
			action_btn.text = "Chiave"
			action_btn.disabled = true
			slot_row.visible = false
		"class_license":
			action_btn.text = "Usa Licenza"
			action_btn.disabled = false
			slot_row.visible = false
		_:
			action_btn.text = "Nessuna azione"
			action_btn.disabled = true
			slot_row.visible = false


func _refresh_slot_btns() -> void:
	for i: int in 3:
		var assigned: bool = str(GameState.quick_slots[i]) == _selected_item
		_slot_assign_btns[i].text = "[%d]✓" % (i + 1) if assigned else "[%d]" % (i + 1)


func _assign_slot(slot_idx: int) -> void:
	if _selected_item == "":
		return
	var data: Dictionary = ItemDB.get_item(_selected_item)
	if data.get("type", "") != "consumable":
		return
	if str(GameState.quick_slots[slot_idx]) == _selected_item:
		GameState.quick_slots[slot_idx] = ""
	else:
		GameState.quick_slots[slot_idx] = _selected_item
	EventBus.quick_slots_changed.emit()
	_refresh_slot_btns()


func _on_action_pressed() -> void:
	if _selected_item == "":
		return
	var data: Dictionary = ItemDB.get_item(_selected_item)
	var item_type: String = data.get("type", "")
	match item_type:
		"consumable":
			Inventory.use_item(_selected_item)
			_selected_item = ""
		"equipment":
			if Equipment.is_equipped(_selected_item):
				var slot: String = Equipment.get_equipped_slot(_selected_item)
				Equipment.unequip(slot)
			else:
				Equipment.equip(_selected_item)
		"class_license":
			_close()
			EventBus.respec_screen_requested.emit()
			return
	_update_action_area()


func _on_doll_hover_enter(slot_name: String) -> void:
	var item_id: String = str(GameState.equipped.get(slot_name, ""))
	if item_id != "":
		_show_item_tooltip(item_id)
	else:
		_show_tooltip(SLOT_NAMES.get(slot_name, slot_name) + "\n(vuoto)")


func _on_bag_hover_enter(item_id: String) -> void:
	_show_item_tooltip(item_id)


func _hide_tooltip() -> void:
	tooltip.visible = false


func _show_item_tooltip(item_id: String) -> void:
	var data: Dictionary = ItemDB.get_item(item_id)
	var item_type: String = data.get("type", "")
	var lines: PackedStringArray = PackedStringArray()
	lines.append(data.get("name", item_id))

	var type_line: String = "[" + item_type.capitalize() + "]"
	if item_type == "equipment":
		type_line += "  " + SLOT_NAMES.get(data.get("slot", ""), data.get("slot", ""))
	lines.append(type_line)

	if data.has("description"):
		lines.append(str(data["description"]))

	var atk: int = int(data.get("attack_bonus", 0))
	var def_bonus: int = int(data.get("defense_bonus", 0))
	if atk > 0:
		lines.append("+%d ATK" % atk)
	if def_bonus > 0:
		lines.append("+%d DEF" % def_bonus)

	if item_type == "consumable":
		var eff: Dictionary = data.get("effect", {}) as Dictionary
		if eff.has("heal"):
			lines.append("Cura %d HP" % int(eff["heal"]))

	var entry: Variant = _get_inventory_entry(item_id)
	if entry != null:
		lines.append("Quantità: %d" % int((entry as Dictionary)["qty"]))

	_show_tooltip("\n".join(lines))


func _show_tooltip(text: String) -> void:
	tooltip_lbl.text = text
	tooltip.visible = true


func _get_inventory_entry(item_id: String) -> Variant:
	for entry: Dictionary in GameState.inventory:
		if str(entry["id"]) == item_id:
			return entry
	return null


func _item_in_inventory(item_id: String) -> bool:
	return _get_inventory_entry(item_id) != null


func _refresh_if_open(_arg: Variant = null) -> void:
	if _is_open:
		_refresh()
