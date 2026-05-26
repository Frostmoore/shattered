class_name HUDV2
extends CanvasLayer

signal use_item_requested()
signal open_menu_requested()

const _SCENE_STATUS:    String = "res://scenes/ui/hud/components/PlayerStatusPanel.tscn"
const _SCENE_WORLDINFO: String = "res://scenes/ui/hud/components/WorldInfoPanel.tscn"
const _SCENE_QUEST:     String = "res://scenes/ui/hud/components/QuestTracker.tscn"
const _SCENE_MINIMAP:   String = "res://scenes/ui/hud/components/MinimapPanel.tscn"
const _SCENE_LOG:       String = "res://scenes/ui/hud/components/MessageLog.tscn"
const _SCENE_ACTIONBAR: String = "res://scenes/ui/hud/components/ActionBar.tscn"
const _SCENE_SLOTS:     String = "res://scenes/ui/hud/components/QuickSlotBar.tscn"

var _state:    HUDState          = null
var _settings: HUDSettings       = null
var _status:   PlayerStatusPanel = null
var _worldinfo: WorldInfoPanel   = null
var _quest:    QuestTracker      = null
var _minimap:  MinimapPanel      = null
var _log:      MessageLog        = null
var _actionbar: ActionBar        = null
var _slots:    QuickSlotBar      = null


func _ready() -> void:
	_state    = $HUDState as HUDState
	_settings = $HUDSettings as HUDSettings
	_build_components()
	_apply_settings_visibility()
	_init_minimap_position()
	_minimap.position_changed.connect(_settings.save_minimap_pos)
	_actionbar.use_item_requested.connect(use_item_requested.emit)
	_actionbar.open_menu_requested.connect(open_menu_requested.emit)
	_quest.expand_requested.connect(_on_quest_expand)
	_wire_eventbus()
	_refresh_all()


func set_wait_screen(_node: Node) -> void:
	pass  # ActionBar localizza WaitScreen via get_node_or_null("/root/Main/WaitScreen")


# ── Costruzione UI ────────────────────────────────────────────────────────────

func _build_components() -> void:
	var root := Control.new()
	root.name = "Components"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# WorldInfoPanel — top full-width, 16px
	_worldinfo = (load(_SCENE_WORLDINFO) as PackedScene).instantiate() as WorldInfoPanel
	root.add_child(_worldinfo)

	# PlayerStatusPanel — top full-width, offset_top=16, 26px
	_status = (load(_SCENE_STATUS) as PackedScene).instantiate() as PlayerStatusPanel
	root.add_child(_status)

	# QuestTracker — floating (4, 46)
	_quest = (load(_SCENE_QUEST) as PackedScene).instantiate() as QuestTracker
	root.add_child(_quest)

	# MinimapPanel — posizione caricata da SettingsManager in _init_minimap_position()
	_minimap = (load(_SCENE_MINIMAP) as PackedScene).instantiate() as MinimapPanel
	root.add_child(_minimap)

	# BottomStrip — anchor bottom full-width, 38px
	var strip := _build_bottom_strip()
	root.add_child(strip)


func _build_bottom_strip() -> Control:
	var strip := PanelContainer.new()
	strip.name = "BottomStrip"
	strip.anchor_left   = 0.0
	strip.anchor_right  = 1.0
	strip.anchor_top    = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top    = -38.0
	strip.offset_bottom = 0.0

	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.08, 0.08, 0.10, 0.93)
	strip.add_theme_stylebox_override("panel", strip_style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	strip.add_child(rows)

	# Riga 1: MessageLog + ActionBar
	var row1 := HBoxContainer.new()
	row1.custom_minimum_size = Vector2(0.0, 19.0)
	row1.add_theme_constant_override("separation", 0)
	rows.add_child(row1)

	_log = (load(_SCENE_LOG) as PackedScene).instantiate() as MessageLog
	row1.add_child(_log)

	_actionbar = (load(_SCENE_ACTIONBAR) as PackedScene).instantiate() as ActionBar
	row1.add_child(_actionbar)

	# Riga 2: QuickSlotBar
	var row2 := HBoxContainer.new()
	row2.custom_minimum_size = Vector2(0.0, 19.0)
	row2.add_theme_constant_override("separation", 0)
	rows.add_child(row2)

	_slots = (load(_SCENE_SLOTS) as PackedScene).instantiate() as QuickSlotBar
	row2.add_child(_slots)

	return strip


func _init_minimap_position() -> void:
	var pos: Vector2 = _settings.get_minimap_pos()
	if pos == Vector2(-4.0, -4.0):
		var vp: Vector2 = get_viewport().get_visible_rect().size
		pos = Vector2(vp.x - 166.0 - 4.0, vp.y - 185.0 - 4.0)
	_minimap.load_position(pos)


# ── Visibilità e modalità ─────────────────────────────────────────────────────

func _apply_settings_visibility() -> void:
	_status.visible    = _settings.show_status()
	_worldinfo.visible = _settings.show_worldinfo()
	_quest.visible     = _settings.show_quest()
	_minimap.visible   = _settings.show_minimap() and _is_minimap_map(GameState.current_map_id)
	_status.set_needs_visible(_settings.show_needs())
	_status.apply_ui_mode(_settings.get_ui_mode())


# ── EventBus wiring ───────────────────────────────────────────────────────────

func _wire_eventbus() -> void:
	EventBus.player_stats_changed.connect(func(): _status.refresh())
	EventBus.equipment_changed.connect(func(): _status.refresh())
	EventBus.xp_gained.connect(func(_a: int): _status.refresh())
	EventBus.player_leveled_up.connect(func(_a: int): _status.refresh())
	EventBus.needs_changed.connect(func(): _status.refresh_needs())
	EventBus.disease_acquired.connect(func(_id: String, _name: String): _status.refresh_needs())
	EventBus.disease_cured.connect(func(_id: String): _status.refresh_needs())

	EventBus.map_changed.connect(_on_map_changed)
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.time_advanced.connect(func(_m: int): _worldinfo.refresh_time())

	EventBus.inventory_changed.connect(func(): _slots.refresh())
	EventBus.quick_slots_changed.connect(func(): _slots.refresh())

	EventBus.quest_started.connect(func(_id: String): _quest.refresh())
	EventBus.quest_completed.connect(func(_id: String): _quest.refresh())
	EventBus.quest_ready.connect(func(_id: String): _quest.refresh())

	EventBus.combat_log.connect(func(t: String): _push_log(t, HUDState.LogCategory.COMBAT))
	EventBus.quest_started.connect(func(id: String):
		_push_log("Quest: " + QuestManager.get_quest_data(id).get("title", id),
			HUDState.LogCategory.QUEST))
	EventBus.loot_screen_open.connect(func(drops: Array, _src: String):
		for item_id: Variant in drops:
			_push_log("Trovato: " + str(item_id), HUDState.LogCategory.LOOT))

	EventBus.combat_started.connect(func(): _actionbar.set_combat_mode(true))
	EventBus.combat_ended.connect(func(): _actionbar.set_combat_mode(false))

	EventBus.settings_changed.connect(_apply_settings_visibility)


# ── Log ───────────────────────────────────────────────────────────────────────

func _push_log(text: String, cat: int) -> void:
	_state.push(text, cat)
	var entry: HUDState.LogEntry = _state.get_latest()
	if entry:
		_log.show_entry(entry, HUDState.get_color(cat))


# ── Handler mappa e movimento ─────────────────────────────────────────────────

func _on_map_changed(map_id: String) -> void:
	_worldinfo.refresh_zone(map_id)
	var minimap_on: bool = _is_minimap_map(map_id) and _settings.show_minimap()
	_minimap.visible = minimap_on
	if minimap_on:
		_minimap.refresh_full()
	_refresh_all()


func _on_player_moved(_pos: Vector2i) -> void:
	if _minimap.visible:
		_minimap.mark_explored(GameState.player_position)
		_minimap.refresh_image()


func _is_minimap_map(map_id: String) -> bool:
	if map_id == "":
		return false
	var data: MapData = LocationRegistry.get_or_generate(map_id)
	if data == null:
		return false
	return bool(data.metadata.get("minimap_enabled", false))


# ── Refresh globale ───────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_status.refresh()
	_status.refresh_needs()
	_worldinfo.refresh_zone(GameState.current_map_id)
	_worldinfo.refresh_time()
	_slots.refresh()
	_quest.refresh()


# ── Handler componenti ────────────────────────────────────────────────────────

func _on_quest_expand() -> void:
	var qj: Node = get_node_or_null("/root/Main/QuestJournal")
	if qj != null:
		qj.call("open")
