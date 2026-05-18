extends PanelContainer
class_name Toast

signal finished()

@onready var _label: Label = $Label


func setup(n: Notification) -> void:
	_label.text = n.text
	_label.add_theme_color_override("font_color", n.color)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.12, 0.93)
	style.border_width_left = 3
	style.border_color = n.color
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

	_animate(n.duration)


func _animate(duration: float) -> void:
	modulate.a = 0.0
	position.x = 24.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(self, "position:x", 0.0, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(false)
	tw.tween_interval(duration)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: finished.emit())
