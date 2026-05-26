class_name QuestTracker
extends Control

signal expand_requested()

const _FONT_BOLD: String = "res://assets/fonts/Roboto-Bold.ttf"
const _FONT_REG:  String = "res://assets/fonts/Roboto-Regular.ttf"

var _title_lbl:  Label  = null
var _obj_lbl:    Label  = null
var _expand_btn: Button = null


func _ready() -> void:
	custom_minimum_size = Vector2(200.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", load(_FONT_BOLD))
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_title_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.30))
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(_title_lbl)

	_obj_lbl = Label.new()
	_obj_lbl.add_theme_font_override("font", load(_FONT_REG))
	_obj_lbl.add_theme_font_size_override("font_size", 11)
	_obj_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	_obj_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(_obj_lbl)

	_expand_btn = Button.new()
	_expand_btn.text = "[+]"
	_expand_btn.add_theme_font_override("font", load(_FONT_REG))
	_expand_btn.add_theme_font_size_override("font_size", 10)
	_expand_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_expand_btn.flat = true
	_expand_btn.focus_mode = Control.FOCUS_NONE
	_expand_btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	_expand_btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	_expand_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_expand_btn.pressed.connect(func(): expand_requested.emit())
	vbox.add_child(_expand_btn)


func refresh() -> void:
	var title: String = QuestManager.get_active_quest_title()
	if title == "":
		visible = false
		return
	visible = true
	_title_lbl.text = "▸ " + title
	var obj: String = QuestManager.get_active_quest_objective()
	_obj_lbl.text    = "  " + (obj if obj != "" else "—")
	_obj_lbl.visible = obj != ""
