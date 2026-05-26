class_name QuickSlotBar
extends HBoxContainer

const SLOT_COUNT := 5
const _FONT_MED: String = "res://assets/fonts/Roboto-Medium.ttf"

var _btns: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_build_ui()
	refresh()


func _build_ui() -> void:
	var font: Font = load(_FONT_MED)
	for i: int in range(SLOT_COUNT):
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 16)
		btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 11)

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.10, 0.10, 0.12)
		normal_style.border_color = Color(0.50, 0.42, 0.14, 0.5)
		normal_style.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.14, 0.14, 0.16)
		hover_style.border_color = Color(0.75, 0.62, 0.20, 0.9)
		hover_style.set_border_width_all(1)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("focus", hover_style)

		var idx: int = i
		btn.pressed.connect(func(): _on_slot_pressed(idx))
		_btns.append(btn)
		add_child(btn)


func refresh() -> void:
	for i: int in range(SLOT_COUNT):
		var item_id: String = GameState.quick_slots[i] if i < GameState.quick_slots.size() else ""
		_btns[i].text = "[%d:%s]" % [i + 1, item_id if item_id != "" else "——"]


func _on_slot_pressed(idx: int) -> void:
	if idx >= GameState.quick_slots.size():
		return
	var item_id: String = GameState.quick_slots[idx]
	if item_id != "":
		Inventory.use_item(item_id)


func _unhandled_input(event: InputEvent) -> void:
	for i: int in range(SLOT_COUNT):
		if event.is_action_pressed("quick_slot_%d" % (i + 1)):
			_on_slot_pressed(i)
			get_viewport().set_input_as_handled()
			return
