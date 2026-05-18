extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var advance_hint: Label = $Panel/VBox/AdvanceHint

var _is_open: bool = false


func _ready() -> void:
	DialogueManager.dialogue_line_ready.connect(_show_line)
	DialogueManager.dialogue_finished.connect(_close)
	panel.visible = false


func _show_line(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	text_label.text = text
	advance_hint.text = "[E / Spazio per continuare]"
	panel.visible = true
	_is_open = true


func _close() -> void:
	panel.visible = false
	_is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		DialogueManager.advance()
