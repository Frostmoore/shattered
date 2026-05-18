extends CanvasLayer

const DURATION: float = 0.35

var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


# Fades to black, calls on_peak (save/respawn/heal), then fades back in.
# Calls on_complete when the fade-in finishes.
func fade(on_peak: Callable = Callable(), on_complete: Callable = Callable()) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_rect, "color:a", 1.0, DURATION)
	tween.tween_callback(func() -> void:
		if on_peak.is_valid():
			on_peak.call()
	)
	tween.tween_property(_rect, "color:a", 0.0, DURATION)
	tween.tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)
