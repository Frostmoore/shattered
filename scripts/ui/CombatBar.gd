extends CanvasLayer
class_name CombatBar

signal use_item_requested()
signal open_menu_requested()

@onready var log_label: Label      = $BG/HBox/LogLabel
@onready var wait_btn: Button      = $BG/HBox/WaitButton
@onready var flee_btn: Button      = $BG/HBox/FleeButton
@onready var inventory_btn: Button = $BG/HBox/InventoryButton
@onready var menu_btn: Button      = $BG/HBox/MenuButton
@onready var _slot1_btn: Button    = $BG/HBox/QuickSlot1
@onready var _slot2_btn: Button    = $BG/HBox/QuickSlot2
@onready var _slot3_btn: Button    = $BG/HBox/QuickSlot3

var _in_combat: bool = false
var _slot_btns: Array[Button] = []


func _ready() -> void:
	visible = false
	_slot_btns = [_slot1_btn, _slot2_btn, _slot3_btn]

	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.combat_log.connect(_on_combat_log)
	EventBus.player_turn_started.connect(_on_player_turn_started)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.inventory_changed.connect(_refresh_slots)
	EventBus.quick_slots_changed.connect(_refresh_slots)

	wait_btn.pressed.connect(_on_wait)
	flee_btn.pressed.connect(_on_flee)
	inventory_btn.pressed.connect(func() -> void: use_item_requested.emit())
	menu_btn.pressed.connect(func() -> void: open_menu_requested.emit())

	for i: int in 3:
		var idx := i
		_slot_btns[i].pressed.connect(func() -> void: _use_slot(idx))

	_set_combat_buttons_active(false)
	_refresh_slots()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.is_pressed() and not ke.is_echo():
			match ke.keycode:
				KEY_1:
					get_viewport().set_input_as_handled()
					_use_slot(0)
				KEY_2:
					get_viewport().set_input_as_handled()
					_use_slot(1)
				KEY_3:
					get_viewport().set_input_as_handled()
					_use_slot(2)
	if event.is_action_pressed("action_wait") and _in_combat:
		get_viewport().set_input_as_handled()
		_on_wait()
	elif event.is_action_pressed("action_flee") and _in_combat:
		get_viewport().set_input_as_handled()
		_on_flee()


func _on_combat_started() -> void:
	_in_combat = true
	log_label.text = LocaleManager.t("UI_COMBATBAR_COMBAT")
	_set_combat_buttons_active(true)


func _on_combat_ended() -> void:
	_in_combat = false
	log_label.text = LocaleManager.t("UI_COMBATBAR_EXPLORE")
	_set_combat_buttons_active(false)


func _on_combat_log(text: String) -> void:
	log_label.text = text


func _on_player_turn_started() -> void:
	if _in_combat:
		_set_combat_buttons_active(true)


func _on_map_changed(map_id: String) -> void:
	_in_combat = false
	_set_combat_buttons_active(false)
	if map_id == "dungeon":
		log_label.text = LocaleManager.t("UI_COMBATBAR_DUNGEON")
	else:
		log_label.text = LocaleManager.t("UI_COMBATBAR_EXPLORE")


func _set_combat_buttons_active(active: bool) -> void:
	wait_btn.disabled = not active
	flee_btn.disabled = not active


func _refresh_slots(_arg: Variant = null) -> void:
	for i: int in 3:
		var item_id: String = str(GameState.quick_slots[i])
		if item_id == "":
			_slot_btns[i].text = "[%d] —" % (i + 1)
			_slot_btns[i].disabled = true
		else:
			var data: Dictionary = ItemDB.get_item(item_id)
			var name: String = data.get("name", item_id)
			if name.length() > 8:
				name = name.substr(0, 7) + "…"
			var qty: int = Inventory.get_quantity(item_id)
			var qty_str: String = " x%d" % qty if qty > 0 else ""
			_slot_btns[i].text = "[%d] %s%s" % [i + 1, name, qty_str]
			_slot_btns[i].disabled = qty == 0


func _use_slot(idx: int) -> void:
	var item_id: String = str(GameState.quick_slots[idx])
	if item_id == "" or not Inventory.has_item(item_id):
		return
	Inventory.use_item(item_id)


func _on_wait() -> void:
	if not TurnManager.is_player_turn:
		return
	_set_combat_buttons_active(false)
	TurnManager.on_player_action_done()


func _on_flee() -> void:
	if not TurnManager.is_player_turn:
		return
	_set_combat_buttons_active(false)
	var map: BaseMap = WorldManager.get_current_map() as BaseMap
	if map == null:
		return
	var player: Player = map.get_player()
	if player == null:
		return
	player.flee_attempt()
