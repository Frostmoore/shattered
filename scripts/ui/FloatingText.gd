extends Node2D

# dir_x: direzione laterale dell'arco.
#  1.0 = arco verso destra (danno al nemico)
# -1.0 = arco verso sinistra (danno al giocatore)
#  0.0 = sale dritto (miss / schivato)
func setup(text: String, color: Color, dir_x: float = 0.0) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(80, 16)
	lbl.position = Vector2(-40, -20)

	var font := load("res://assets/fonts/PressStart2P.ttf") as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE

	var settings := LabelSettings.new()
	settings.font          = font
	settings.font_size     = 8
	settings.font_color    = color
	settings.outline_size  = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	lbl.label_settings = settings
	add_child(lbl)

	var drift_x: float = dir_x * randf_range(14.0, 24.0)
	var rise_y:  float = randf_range(28.0, 42.0)

	var tween_move := create_tween()
	# Y ease-out: sale veloce poi rallenta
	tween_move.tween_property(self, "position:y", position.y - rise_y, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# X ease-in: parte lento poi curva lateralmente → arco naturale
	tween_move.parallel().tween_property(self, "position:x", position.x + drift_x, 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	var tween_fade := create_tween()
	tween_fade.tween_interval(0.5)
	tween_fade.tween_property(lbl, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween_fade.tween_callback(queue_free)
