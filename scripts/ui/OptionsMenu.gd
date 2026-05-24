extends CanvasLayer
class_name OptionsMenu

signal back_requested()

var _orig_window_mode: int       = 0
var _orig_window_size_index: int = 1
var _orig_master_volume: float   = 1.0
var _orig_zoom_level: float      = 2.0
var _orig_language: String       = "it"

@onready var window_size_option: OptionButton = $Panel/VBox/WindowSizeOption
@onready var fullscreen_check: CheckButton    = $Panel/VBox/FullscreenCheck
@onready var volume_slider: HSlider           = $Panel/VBox/VolumeSlider
@onready var zoom_option: OptionButton        = $Panel/VBox/ZoomOption
@onready var language_option: OptionButton    = $Panel/VBox/LanguageOption


func _ready() -> void:
	visible = false
	_populate_options()
	window_size_option.item_selected.connect(_on_window_size_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	zoom_option.item_selected.connect(_on_zoom_selected)
	language_option.item_selected.connect(_on_language_selected)
	$Panel/VBox/ApplyButton.pressed.connect(_on_apply)
	$Panel/VBox/BackButton.pressed.connect(_on_back)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _populate_options() -> void:
	window_size_option.clear()
	for s: Vector2i in SettingsManager.WINDOW_SIZES:
		window_size_option.add_item("%dx%d" % [s.x, s.y])
	zoom_option.clear()
	for z: float in SettingsManager.ZOOM_LEVELS:
		zoom_option.add_item("x%.1f" % z)
	language_option.clear()
	for code: String in LocaleManager.SUPPORTED_LANGUAGES:
		language_option.add_item(LocaleManager.get_display_name(code))


func show_options() -> void:
	_orig_window_mode       = SettingsManager.window_mode
	_orig_window_size_index = SettingsManager.window_size_index
	_orig_master_volume     = SettingsManager.master_volume
	_orig_zoom_level        = SettingsManager.zoom_level
	_orig_language          = SettingsManager.language
	visible = true
	window_size_option.selected = SettingsManager.window_size_index
	fullscreen_check.button_pressed = (SettingsManager.window_mode == 1)
	volume_slider.value = SettingsManager.master_volume
	var zi: int = SettingsManager.ZOOM_LEVELS.find(SettingsManager.zoom_level)
	zoom_option.selected = zi if zi >= 0 else 2
	var li: int = LocaleManager.SUPPORTED_LANGUAGES.find(SettingsManager.language)
	language_option.selected = li if li >= 0 else 0


func _on_window_size_selected(idx: int) -> void:
	SettingsManager.window_size_index = idx
	SettingsManager.window_mode = 1 if fullscreen_check.button_pressed else 0
	SettingsManager.apply_all()


func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.window_mode = 1 if pressed else 0
	SettingsManager.apply_all()


func _on_volume_changed(value: float) -> void:
	SettingsManager.master_volume = value
	SettingsManager.apply_all()


func _on_zoom_selected(idx: int) -> void:
	SettingsManager.zoom_level = SettingsManager.ZOOM_LEVELS[idx]
	SettingsManager.apply_all()


func _on_language_selected(idx: int) -> void:
	SettingsManager.language = LocaleManager.SUPPORTED_LANGUAGES[idx]
	SettingsManager.apply_all()


func _on_apply() -> void:
	SettingsManager.save_settings()
	back_requested.emit()


func _on_back() -> void:
	SettingsManager.window_mode       = _orig_window_mode
	SettingsManager.window_size_index = _orig_window_size_index
	SettingsManager.master_volume     = _orig_master_volume
	SettingsManager.zoom_level        = _orig_zoom_level
	SettingsManager.language          = _orig_language
	SettingsManager.apply_all()
	back_requested.emit()
