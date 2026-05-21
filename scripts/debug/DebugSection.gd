extends VBoxContainer
class_name DebugSection

const FONT_SIZE      := 10
const HEADER_COLOR   := Color(0.65, 0.85, 1.0)
const BODY_COLOR     := Color(0.88, 0.88, 0.88)

var _title:    String
var _header:   Button
var _body:     Label
var _expanded: bool = true


func setup(title: String) -> void:
	_title = title


func _ready() -> void:
	add_theme_constant_override("separation", 0)

	_header = Button.new()
	_header.text      = "▼ " + _title
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.flat      = true
	_header.focus_mode = Control.FOCUS_NONE
	_header.add_theme_color_override("font_color", HEADER_COLOR)
	_header.add_theme_font_size_override("font_size", FONT_SIZE + 1)
	_header.pressed.connect(_toggle)
	add_child(_header)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", FONT_SIZE)
	_body.add_theme_color_override("font_color", BODY_COLOR)
	add_child(_body)


func update(lines: Array) -> void:
	if is_instance_valid(_body):
		_body.text = "\n".join(lines)


func _toggle() -> void:
	_expanded      = not _expanded
	_body.visible  = _expanded
	_header.text   = ("▼ " if _expanded else "► ") + _title
