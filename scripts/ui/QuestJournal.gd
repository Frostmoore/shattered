extends CanvasLayer
class_name QuestJournal


func _ready() -> void:
	visible = false
	$Overlay.gui_input.connect(_on_overlay_input)
	$Panel/VBox/Header/CloseButton.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_ESCAPE and ke.is_pressed() and not ke.is_echo():
			get_viewport().set_input_as_handled()
			close()


func open() -> void:
	_rebuild()
	visible = true


func close() -> void:
	visible = false


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()


func _rebuild() -> void:
	var list := $Panel/VBox/Scroll/QuestList as VBoxContainer
	for child: Node in list.get_children():
		child.queue_free()

	_add_section(list, "IN CORSO", GameState.active_quests, Color(0.4, 0.85, 0.45), "active")
	_add_section(list, "DA CONSEGNARE", GameState.ready_quests, Color(1.0, 0.6, 0.1), "ready")
	_add_section(list, "COMPLETATE", GameState.completed_quests, Color(0.55, 0.55, 0.55), "completed")

	if list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Nessuna quest nel diario."
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		empty.add_theme_font_size_override("font_size", 13)
		list.add_child(empty)


func _add_section(list: VBoxContainer, title: String, quest_ids: Array, color: Color, status: String) -> void:
	if quest_ids.is_empty():
		return
	var header := Label.new()
	header.text = "— " + title + " —"
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", 12)
	list.add_child(header)
	for qid_raw: Variant in quest_ids:
		_add_quest_entry(list, str(qid_raw), status)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	list.add_child(spacer)


func _add_quest_entry(list: VBoxContainer, quest_id: String, status: String) -> void:
	var quest: Dictionary = QuestManager.get_quest_data(quest_id)
	var is_completed: bool = status == "completed"
	var is_ready: bool = status == "ready"

	var title_lbl := Label.new()
	title_lbl.text = ("✓ " if is_completed else "● ") + quest.get("title", quest_id)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color",
		Color(0.55, 0.55, 0.55) if is_completed else Color(0.95, 0.90, 0.70))
	list.add_child(title_lbl)

	var desc: String = quest.get("description", "")
	if desc != "" and not is_completed:
		var desc_lbl := Label.new()
		desc_lbl.text = "  " + desc
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		list.add_child(desc_lbl)

	if is_ready:
		var hint_lbl := Label.new()
		hint_lbl.text = "  → Torna a consegnare la quest"
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		list.add_child(hint_lbl)

	if not is_completed:
		var raw_obj: Variant = quest.get("objectives", [])
		if raw_obj is Array:
			for obj_raw: Variant in (raw_obj as Array):
				if obj_raw is Dictionary:
					_add_objective(list, quest_id, obj_raw as Dictionary, is_ready)


func _add_objective(list: VBoxContainer, quest_id: String, obj: Dictionary, force_done: bool) -> void:
	var type: String = obj.get("type", "")
	var required: int = int(obj.get("required", 1))
	var target_id: String = obj.get("target_id", "")
	var progress: int = required if force_done else QuestManager.get_progress(quest_id, target_id)
	var done: bool = progress >= required

	var text: String = "  • "
	if type == "kill_enemy":
		text += "Sconfiggi [%s]: %d/%d" % [target_id, mini(progress, required), required]
	else:
		text += type
	if done:
		text += " ✓"

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color",
		Color(0.45, 0.80, 0.45) if done else Color(0.72, 0.72, 0.72))
	list.add_child(lbl)
