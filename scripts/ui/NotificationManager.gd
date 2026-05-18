extends CanvasLayer
class_name NotificationManager

const MAX_VISIBLE: int = 5
const TOAST_SCENE: PackedScene = preload("res://scenes/ui/Toast.tscn")

@onready var _vbox: VBoxContainer = $VBox

var _queue: Array[Notification] = []
var _active: int = 0


func _ready() -> void:
	EventBus.notification_shown.connect(_on_notification)


func _on_notification(n: Notification) -> void:
	if _active < MAX_VISIBLE:
		_show(n)
	else:
		_queue.append(n)


func _show(n: Notification) -> void:
	_active += 1
	var toast: Toast = TOAST_SCENE.instantiate() as Toast
	_vbox.add_child(toast)
	toast.setup(n)
	toast.finished.connect(_on_toast_finished.bind(toast))


func _on_toast_finished(toast: Toast) -> void:
	_active -= 1
	toast.queue_free()
	if not _queue.is_empty():
		_show(_queue.pop_front())
