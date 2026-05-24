extends Node

const SETTINGS_PATH := "user://settings.json"

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]
const ZOOM_LEVELS: Array[float] = [1.0, 1.5, 2.0, 3.0]

var window_mode: int       = 0    # 0=windowed, 1=fullscreen
var window_size_index: int = 1    # index into WINDOW_SIZES
var master_volume: float   = 1.0  # 0.0–1.0
var zoom_level: float      = 2.0
var language: String       = "it"


func _ready() -> void:
	load_settings()
	apply_all()


func apply_all() -> void:
	_apply_window()
	_apply_volume()
	LocaleManager.set_language(language)
	EventBus.settings_changed.emit()


func _apply_window() -> void:
	var idx: int = clampi(window_size_index, 0, WINDOW_SIZES.size() - 1)
	if window_mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var target: Vector2i = WINDOW_SIZES[idx]
	DisplayServer.window_set_size(target)
	var screen: Vector2i = DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen - target) / 2)


func _apply_volume() -> void:
	var db: float = linear_to_db(master_volume) if master_volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(0, db)


func save_settings() -> void:
	var data: Dictionary = {
		"window_mode":       window_mode,
		"window_size_index": window_size_index,
		"master_volume":     master_volume,
		"zoom_level":        zoom_level,
		"language":          language,
	}
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed as Dictionary
	window_mode       = int(d.get("window_mode",       0))
	window_size_index = int(d.get("window_size_index", 1))
	master_volume     = float(d.get("master_volume",   1.0))
	zoom_level        = float(d.get("zoom_level",      2.0))
	language          = str(d.get("language",          "it"))
