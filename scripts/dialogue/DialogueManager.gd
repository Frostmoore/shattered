extends Node

var _dialogues: Dictionary = {}
var _current_id: String = ""
var _current_lines: Array[Dictionary] = []
var _current_line_index: int = 0

signal dialogue_line_ready(speaker: String, text: String)
signal dialogue_finished()


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir: DirAccess = DirAccess.open("res://data/dialogue/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			_load_file("res://data/dialogue/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed as Dictionary
	_dialogues[d["id"]] = d


func start_dialogue(dialogue_id: String) -> void:
	if not _dialogues.has(dialogue_id):
		push_error("DialogueManager: dialogue not found: " + dialogue_id)
		return
	_current_id = dialogue_id
	_current_lines = []
	var raw_lines: Variant = (_dialogues[dialogue_id] as Dictionary).get("lines", [])
	if raw_lines is Array:
		for line: Variant in (raw_lines as Array):
			if line is Dictionary:
				_current_lines.append(line as Dictionary)
	_current_line_index = 0
	EventBus.dialogue_started.emit(dialogue_id)
	_emit_current_line()


func advance() -> void:
	_current_line_index += 1
	if _current_line_index >= _current_lines.size():
		_finish()
	else:
		_emit_current_line()


func _emit_current_line() -> void:
	var line: Dictionary = _current_lines[_current_line_index]
	dialogue_line_ready.emit(line.get("speaker", ""), line.get("text", ""))


func _finish() -> void:
	var data: Dictionary = _dialogues.get(_current_id, {})
	var start_id: String = data.get("starts_quest", "")
	if start_id != "":
		QuestManager.start_quest(start_id)
	var complete_id: String = data.get("completes_quest", "")
	if complete_id != "":
		QuestManager.try_complete_quest(complete_id)
	EventBus.dialogue_ended.emit(_current_id)
	dialogue_finished.emit()
	_current_id = ""
	_current_lines = []
