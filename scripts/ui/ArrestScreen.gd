extends CanvasLayer

@onready var _bg:         ColorRect = $BgRect
@onready var _panel:      Panel     = $Panel
@onready var _city_label: Label     = $Panel/Margin/VBox/CityLabel
@onready var _fine_label: Label     = $Panel/Margin/VBox/FineLabel

const FADE_IN_TIME:  float = 0.5
const FADE_OUT_TIME: float = 0.45

var _waiting: bool = false


func _ready() -> void:
	visible = false
	EventBus.player_arrested.connect(_on_arrested)


func _on_arrested(city_id: String, fine_amount: int) -> void:
	var city_name: String = city_id
	var record: Array = CrimeSystem.get_criminal_record()
	if not record.is_empty():
		city_name = str(record[-1].get("city_name", city_id))

	_city_label.text = LocaleManager.t_or("UI_ARREST_CITY",
		"Città: {city}", {"city": city_name})
	_fine_label.text = LocaleManager.t_or("UI_ARREST_FINE",
		"Multa: {fine}g confiscata.", {"fine": str(fine_amount)})

	visible       = true
	_waiting      = false
	_bg.modulate.a    = 0.0
	_panel.modulate.a = 0.0

	var tw: Tween = create_tween()
	tw.tween_property(_bg,    "modulate:a", 1.0, FADE_IN_TIME)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: _waiting = true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _waiting:
		return
	var is_key: bool = event is InputEventKey \
		and (event as InputEventKey).is_pressed() \
		and not (event as InputEventKey).is_echo()
	if is_key or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	_waiting = false
	var tw: Tween = create_tween()
	tw.tween_property(_bg, "modulate:a", 0.0, FADE_OUT_TIME)
	tw.parallel().tween_property(_panel, "modulate:a", 0.0, FADE_OUT_TIME * 0.7)
	tw.tween_callback(func() -> void: visible = false)
