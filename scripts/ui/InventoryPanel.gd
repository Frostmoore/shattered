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
@onready var tooltip_lbl: RichTextLabel = $Tooltip/TooltipLabel

var _is_open: bool = false
var _selected_item: String = ""
var _pending_identify_scroll: String = ""
var _slot_assign_btns: Array[Button] = []
var _doll_btns: Dictionary = {}
var _bag_btns: Array[Button] = []

var _filter_category: String = ""   # "" = tutti
var _sort_mode: int = 0             # 0 = nessuno, 1 = qualità, 2 = nome
var _gold_lbl: Label = null
var _filter_btns: Array[Button] = []
var _sort_btn: Button = null
var _junk_row: HBoxContainer = null
var _junk_btn: Button = null

const SORT_LABELS: Array[String] = ["↕", "★↓", "A-Z"]
const QUALITY_SORT_ORDER: Dictionary = {
	"unico": 6, "leggendario": 5, "epico": 4, "raro": 3, "magico": 2, "normale": 1
}
const FILTER_DEFS: Array = [
	{ "key": "",           "label": "Tutti",  "label_key": "UI_INV_FILTER_ALL" },
	{ "key": "weapon",     "label": "⚔" },
	{ "key": "armor",      "label": "🛡" },
	{ "key": "accessory",  "label": "💍" },
	{ "key": "consumable", "label": "🧪" },
	{ "key": "materiali",  "label": "%" },
]

const DOLL_LAYOUT: Array[String] = [
	"",          "head",    "",
	"cloak",     "body",    "neck",
	"left_hand", "",        "right_hand",
	"ring_1",    "feet",    "ring_2",
	"hands",     "trinket", ""
]

const SLOT_ICONS: Dictionary = {
	"head":       "^",
	"body":       "[",
	"left_hand":  "(",
	"right_hand": "/",
	"ring_1":     "o",
	"ring_2":     "o",
	"neck":       "+",
	"feet":       "u",
	"cloak":      "~",
	"trinket":    "*",
	"hands":      "]"
}

const SLOT_NAMES: Dictionary = {
	"head":       "Testa",
	"body":       "Corpo",
	"left_hand":  "Mano sinistra",
	"right_hand": "Mano destra",
	"ring_1":     "Anello 1",
	"ring_2":     "Anello 2",
	"neck":       "Collo",
	"feet":       "Piedi",
	"cloak":      "Mantello",
	"trinket":    "Oggetto",
	"hands":      "Mani"
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
	_build_filter_row()


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
	_pending_identify_scroll = ""


func _refresh(_arg: Variant = null) -> void:
	_refresh_paper_doll()
	_rebuild_bag_grid()
	_update_action_area()
	_update_gold_display()
	_update_filter_btns()


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
			var data: Dictionary = Equipment.get_base_data(item_id)
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

	var visible_entries: Array = []
	for entry: Dictionary in GameState.inventory:
		if _matches_filter(entry):
			visible_entries.append(entry)
	visible_entries = _sort_entries(visible_entries)

	for entry: Dictionary in visible_entries:
		var key: String     = _get_entry_key(entry)
		var base_id: String = _get_entry_base_id(entry)
		var data: Dictionary = ItemDB.get_item(base_id)
		var quality: String = str(entry.get("quality", "normale")) if entry.has("instance_id") else "normale"
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(44.0, 44.0)
		btn.add_theme_font_size_override("font_size", 16)
		btn.text = data.get("icon", "?")
		_style_bag_btn(btn, key, quality)
		var qty: int = int(entry.get("qty", 1))
		if not entry.has("instance_id") and qty > 1:
			var qty_lbl := Label.new()
			qty_lbl.text = str(qty)
			qty_lbl.add_theme_font_size_override("font_size", 9)
			qty_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			qty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			qty_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(qty_lbl)
		var k := key
		btn.pressed.connect(func() -> void: _on_bag_item_pressed(k))
		btn.mouse_entered.connect(func() -> void: _on_bag_hover_enter(k))
		btn.mouse_exited.connect(func() -> void: _hide_tooltip())
		bag_grid.add_child(btn)
		_bag_btns.append(btn)


func _refresh_bag_styles() -> void:
	for i: int in mini(_bag_btns.size(), GameState.inventory.size()):
		var entry: Dictionary = GameState.inventory[i]
		var quality: String = str(entry.get("quality", "normale")) if entry.has("instance_id") else "normale"
		_style_bag_btn(_bag_btns[i], _get_entry_key(entry), quality)


func _style_doll_btn(btn: Button, filled: bool) -> void:
	if filled:
		btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.35, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55, 1.0))


func _style_bag_btn(btn: Button, item_id: String, quality: String = "normale") -> void:
	if item_id == _selected_item:
		btn.add_theme_color_override("font_color", Color(0.35, 0.95, 0.35, 1.0))
	elif Equipment.is_equipped(item_id):
		btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.35, 1.0))
	elif quality != "normale":
		btn.add_theme_color_override("font_color", ItemGenerator.get_quality_color(quality))
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
	if _pending_identify_scroll != "":
		_try_identify_with_scroll(item_id)
		return
	_selected_item = item_id
	_update_action_area()
	_refresh_bag_styles()


func _update_action_area() -> void:
	if _pending_identify_scroll != "":
		action_row.visible = true
		slot_row.visible = false
		action_btn.text = LocaleManager.t("UI_BTN_CANCEL")
		action_btn.disabled = false
		return
	if _selected_item == "" or not _item_in_inventory(_selected_item):
		_selected_item = ""
		action_row.visible = false
		slot_row.visible = false
		return

	var _sel_entry_v: Variant = _get_inventory_entry(_selected_item)
	var _sel_base: String = _get_entry_base_id(
		(_sel_entry_v as Dictionary) if _sel_entry_v != null else {"id": _selected_item})
	var data: Dictionary = ItemDB.get_item(_sel_base)
	var item_type: String = str(data.get("type", data.get("item_category", "")))
	if item_type in ["weapon", "armor", "accessory"]:
		item_type = "equipment"
	action_row.visible = true

	match item_type:
		"consumable":
			action_btn.text = LocaleManager.t("UI_INV_ACTION_USE")
			action_btn.disabled = false
			slot_row.visible = true
			_refresh_slot_btns()
		"equipment":
			action_btn.text = LocaleManager.t("UI_INV_ACTION_UNEQUIP") if Equipment.is_equipped(_selected_item) else LocaleManager.t("UI_INV_ACTION_EQUIP")
			action_btn.disabled = false
			slot_row.visible = false
		"key":
			action_btn.text = LocaleManager.t("UI_INV_ACTION_KEY")
			action_btn.disabled = true
			slot_row.visible = false
		"class_license":
			action_btn.text = LocaleManager.t("UI_INV_ACTION_LICENSE")
			action_btn.disabled = false
			slot_row.visible = false
		_:
			action_btn.text = LocaleManager.t("UI_INV_ACTION_NONE")
			action_btn.disabled = true
			slot_row.visible = false


func _refresh_slot_btns() -> void:
	for i: int in 3:
		var assigned: bool = str(GameState.quick_slots[i]) == _selected_item
		_slot_assign_btns[i].text = "[%d]✓" % (i + 1) if assigned else "[%d]" % (i + 1)


func _assign_slot(slot_idx: int) -> void:
	if _selected_item == "":
		return
	var _e_v: Variant = _get_inventory_entry(_selected_item)
	var _e_base: String = _get_entry_base_id(
		(_e_v as Dictionary) if _e_v != null else {"id": _selected_item})
	var data: Dictionary = ItemDB.get_item(_e_base)
	if str(data.get("type", data.get("item_category", ""))) != "consumable":
		return
	if str(GameState.quick_slots[slot_idx]) == _selected_item:
		GameState.quick_slots[slot_idx] = ""
	else:
		GameState.quick_slots[slot_idx] = _selected_item
	EventBus.quick_slots_changed.emit()
	_refresh_slot_btns()


func _on_action_pressed() -> void:
	if _pending_identify_scroll != "":
		_pending_identify_scroll = ""
		_selected_item = ""
		_update_action_area()
		return
	if _selected_item == "":
		return
	var _act_entry_v: Variant = _get_inventory_entry(_selected_item)
	var _act_base: String = _get_entry_base_id(
		(_act_entry_v as Dictionary) if _act_entry_v != null else {"id": _selected_item})
	var data: Dictionary = ItemDB.get_item(_act_base)
	var item_type: String = str(data.get("type", data.get("item_category", "")))
	if item_type in ["weapon", "armor", "accessory"]:
		item_type = "equipment"
	match item_type:
		"consumable":
			var eff: Dictionary = data.get("effect", {}) as Dictionary
			if eff.has("identify"):
				_enter_identify_mode(_selected_item)
				return
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


func _enter_identify_mode(scroll_id: String) -> void:
	_pending_identify_scroll = scroll_id
	_selected_item = ""
	_update_action_area()
	EventBus.notification_shown.emit(
		Notification.warning(LocaleManager.t("UI_INV_IDENTIFY_SELECT")))


func _try_identify_with_scroll(item_id: String) -> void:
	var entry_v: Variant = _get_inventory_entry(item_id)
	if entry_v == null:
		return
	var entry: Dictionary = entry_v as Dictionary
	if not entry.has("instance_id"):
		EventBus.notification_shown.emit(
			Notification.warning(LocaleManager.t("UI_INV_IDENTIFY_INVALID")))
		return
	if bool(entry.get("identified", false)):
		EventBus.notification_shown.emit(
			Notification.warning(LocaleManager.t("UI_INV_IDENTIFY_ALREADY")))
		return
	var scroll_id: String = _pending_identify_scroll
	_pending_identify_scroll = ""
	Inventory.identify_instance(str(entry["instance_id"]), GameState.level)
	Inventory.remove_item(scroll_id, 1)
	_selected_item = ""
	_update_action_area()
	EventBus.notification_shown.emit(
		Notification.identify_item(Equipment.get_display_name(str(entry["instance_id"]))))


func _on_doll_hover_enter(slot_name: String) -> void:
	var item_id: String = str(GameState.equipped.get(slot_name, ""))
	if item_id != "":
		_show_equipped_tooltip(item_id)
	else:
		_show_tooltip(ItemTooltipBuilder.build_empty_slot(LocaleManager.t("SLOT_" + slot_name.to_upper())))


func _show_equipped_tooltip(item_id: String) -> void:
	var instance: Dictionary = Equipment.find_instance(item_id)
	if not instance.is_empty():
		_show_tooltip(ItemTooltipBuilder.build_instance(instance))
	else:
		var data: Dictionary = ItemDB.get_item(item_id)
		_show_tooltip(ItemTooltipBuilder.build_legacy(item_id, data))


func _on_bag_hover_enter(key: String) -> void:
	_show_item_tooltip(key)


func _hide_tooltip() -> void:
	tooltip.visible = false


func _show_item_tooltip(key: String) -> void:
	var entry_v: Variant = _get_inventory_entry(key)
	if entry_v == null:
		return
	var entry: Dictionary = entry_v as Dictionary
	var bbcode: String
	if entry.has("instance_id"):
		bbcode = ItemTooltipBuilder.build_instance_compare(entry, -1, _get_compare_stats(entry))
	else:
		var item_id: String = str(entry.get("id", key))
		var data: Dictionary = ItemDB.get_item(item_id)
		var qty: int = int(entry.get("qty", 1))
		bbcode = ItemTooltipBuilder.build_legacy(item_id, data, qty)
	_show_tooltip(bbcode)


# Returns the stats of whatever is equipped in the same slot as this entry, for diff display.
func _get_compare_stats(entry: Dictionary) -> Dictionary:
	if not bool(entry.get("identified", false)):
		return {}
	var base: Dictionary = Equipment.get_base_data(str(entry.get("instance_id", "")))
	var slot: String = str(base.get("slot", ""))
	if slot == "both_hands":
		slot = "right_hand"
	elif base.has("allowed_slots"):
		slot = str((base.get("allowed_slots") as Array)[0])
	if slot == "" or not GameState.equipped.has(slot):
		return {}
	var eq_id: String = str(GameState.equipped.get(slot, ""))
	if eq_id == "" or eq_id == str(entry.get("instance_id", "")):
		return {}
	return Equipment.get_stats(eq_id)


func _show_tooltip(bbcode: String) -> void:
	tooltip_lbl.text = bbcode
	tooltip.visible = true


func _get_entry_key(entry: Dictionary) -> String:
	if entry.has("instance_id"):
		return str(entry["instance_id"])
	return str(entry.get("id", ""))


func _get_entry_base_id(entry: Dictionary) -> String:
	if entry.has("base_id"):
		return str(entry["base_id"])
	return str(entry.get("id", ""))


func _get_inventory_entry(key: String) -> Variant:
	for entry: Dictionary in GameState.inventory:
		if entry.has("instance_id") and str(entry["instance_id"]) == key:
			return entry
		elif entry.has("id") and str(entry["id"]) == key:
			return entry
	return null


func _item_in_inventory(item_id: String) -> bool:
	return _get_inventory_entry(item_id) != null


func _refresh_if_open(_arg: Variant = null) -> void:
	if _is_open:
		_refresh()


# ── filter & sort ─────────────────────────────────────────────────────────────

func _build_filter_row() -> void:
	var bag_section: VBoxContainer = bag_grid.get_parent() as VBoxContainer

	# Gold row — inserted at index 1 (below BagTitle)
	var gold_row := HBoxContainer.new()
	gold_row.name = "GoldRow"
	var gold_icon := Label.new()
	gold_icon.text = "$"
	gold_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_icon.add_theme_font_size_override("font_size", 13)
	gold_row.add_child(gold_icon)
	_gold_lbl = Label.new()
	_gold_lbl.text = "0"
	_gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_lbl.add_theme_font_size_override("font_size", 13)
	_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_row.add_child(_gold_lbl)
	bag_section.add_child(gold_row)
	bag_section.move_child(gold_row, 1)

	# Filter row — inserted at index 2 (below gold row, above grid)
	var filter_row := HBoxContainer.new()
	filter_row.name = "FilterRow"
	filter_row.add_theme_constant_override("separation", 3)
	for def: Variant in FILTER_DEFS:
		var d: Dictionary = def as Dictionary
		var btn := Button.new()
		var lk: String = str(d.get("label_key", ""))
		btn.text = LocaleManager.t(lk) if lk != "" else str(d["label"])
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size = Vector2(0.0, 22.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = str(d["key"])
		btn.pressed.connect(func() -> void: _set_filter(key))
		filter_row.add_child(btn)
		_filter_btns.append(btn)
	# Sort button on the right
	_sort_btn = Button.new()
	_sort_btn.text = SORT_LABELS[_sort_mode]
	_sort_btn.add_theme_font_size_override("font_size", 11)
	_sort_btn.custom_minimum_size = Vector2(32.0, 22.0)
	_sort_btn.pressed.connect(_cycle_sort)
	filter_row.add_child(_sort_btn)
	bag_section.add_child(filter_row)
	bag_section.move_child(filter_row, 2)

	# Junk row — visible only when materiali filter is active
	_junk_row = HBoxContainer.new()
	_junk_row.name = "JunkRow"
	_junk_btn = Button.new()
	_junk_btn.text = LocaleManager.t("UI_INV_JUNK_BTN")
	_junk_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_junk_btn.add_theme_font_size_override("font_size", 11)
	_junk_btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	_junk_btn.pressed.connect(_on_junk_pressed)
	_junk_row.add_child(_junk_btn)
	_junk_row.visible = false
	bag_section.add_child(_junk_row)
	bag_section.move_child(_junk_row, 3)


func _update_gold_display() -> void:
	if _gold_lbl != null:
		_gold_lbl.text = str(int(GameState.player_stats.get("gold", 0)))


func _update_filter_btns() -> void:
	for i: int in _filter_btns.size():
		var def: Dictionary = FILTER_DEFS[i] as Dictionary
		var active: bool = str(def["key"]) == _filter_category
		_filter_btns[i].add_theme_color_override(
			"font_color",
			Color(0.35, 0.95, 0.55) if active else Color(0.75, 0.75, 0.85))


func _set_filter(category: String) -> void:
	_filter_category = category
	_selected_item = ""
	_rebuild_bag_grid()
	_update_filter_btns()
	_update_action_area()
	if _junk_row != null:
		_junk_row.visible = (_filter_category == "materiali")


func _cycle_sort() -> void:
	_sort_mode = (_sort_mode + 1) % SORT_LABELS.size()
	if _sort_btn != null:
		_sort_btn.text = SORT_LABELS[_sort_mode]
	_rebuild_bag_grid()


func _matches_filter(entry: Dictionary) -> bool:
	if _filter_category == "":
		return true
	var base_id: String = _get_entry_base_id(entry)
	var data: Dictionary = ItemDB.get_item(base_id)
	var cat: String = str(data.get("item_category", data.get("type", "")))
	var subtype: String = str(data.get("item_subtype", ""))
	if _filter_category == "materiali":
		return subtype == "materiali"
	if cat == "equipment":
		return _filter_category in ["weapon", "armor", "accessory"]
	return cat == _filter_category


func _sort_entries(entries: Array) -> Array:
	if _sort_mode == 0:
		return entries
	var copy: Array = entries.duplicate()
	if _sort_mode == 1:
		copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var qa: int = int(QUALITY_SORT_ORDER.get(str(a.get("quality", "normale")), 1))
			var qb: int = int(QUALITY_SORT_ORDER.get(str(b.get("quality", "normale")), 1))
			return qa > qb)
	elif _sort_mode == 2:
		copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var na: String = str(ItemDB.get_item(_get_entry_base_id(a)).get("name", ""))
			var nb: String = str(ItemDB.get_item(_get_entry_base_id(b)).get("name", ""))
			return na < nb)
	return copy


# ── getta ciarpame ────────────────────────────────────────────────────────────

func _on_junk_pressed() -> void:
	var count: int = _count_materiali()
	if count == 0:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = LocaleManager.t("UI_INV_JUNK_TITLE")
	dialog.dialog_text = LocaleManager.t("UI_INV_JUNK_CONFIRM", {"count": count})
	dialog.confirmed.connect(func() -> void:
		_remove_all_materiali()
		dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _count_materiali() -> int:
	var c: int = 0
	for entry: Dictionary in GameState.inventory:
		var data: Dictionary = ItemDB.get_item(_get_entry_base_id(entry))
		if str(data.get("item_subtype", "")) == "materiali":
			c += 1
	return c


func _remove_all_materiali() -> void:
	var i: int = GameState.inventory.size() - 1
	while i >= 0:
		var entry: Dictionary = GameState.inventory[i]
		var data: Dictionary = ItemDB.get_item(_get_entry_base_id(entry))
		if str(data.get("item_subtype", "")) == "materiali":
			GameState.inventory.remove_at(i)
		i -= 1
	_selected_item = ""
	EventBus.inventory_changed.emit()
