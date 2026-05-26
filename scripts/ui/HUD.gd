extends CanvasLayer

@onready var _hp_bar: ProgressBar = $Panel/VBox/HPRow/HPBar
@onready var _hp_val: Label       = $Panel/VBox/HPRow/HPVal
@onready var _mp_bar: ProgressBar = $Panel/VBox/MPRow/MPBar
@onready var _mp_val: Label       = $Panel/VBox/MPRow/MPVal
@onready var _st_bar: ProgressBar = $Panel/VBox/STRow/STBar
@onready var _st_val: Label       = $Panel/VBox/STRow/STVal
@onready var _xp_tag: Label       = $Panel/VBox/XPRow/XPTag
@onready var _xp_bar: ProgressBar = $Panel/VBox/XPRow/XPBar
@onready var _xp_val: Label       = $Panel/VBox/XPRow/XPVal
@onready var gold_label:       Label         = $Panel/VBox/GoldLabel
@onready var stats_label:      Label         = $Panel/VBox/StatsLabel
@onready var map_label:        Label         = $Panel/VBox/MapLabel
@onready var quest_label:      Label         = $Panel/VBox/QuestLabel
@onready var _needs_rtl:       RichTextLabel = $Panel/VBox/NeedsRTL
@onready var _diseases_label:  Label         = $Panel/VBox/DiseasesLabel
@onready var _time_label:      Label         = $TimeLabel

var _needs_hud_visible: bool = true


func _ready() -> void:
	_setup_bar_colors()
	EventBus.player_stats_changed.connect(_refresh)
	EventBus.equipment_changed.connect(_refresh)
	EventBus.xp_gained.connect(_refresh)
	EventBus.player_leveled_up.connect(_refresh)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.quest_started.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.time_advanced.connect(_on_time_advanced)
	EventBus.needs_changed.connect(_refresh_needs)
	EventBus.disease_acquired.connect(
		func(_id: String, _name: String) -> void: _refresh_diseases())
	EventBus.disease_cured.connect(
		func(_id: String) -> void: _refresh_diseases())
	EventBus.disease_progressed.connect(
		func(_id: String, _n: String, _s: String) -> void: _refresh_diseases())
	EventBus.disease_regressed.connect(
		func(_id: String, _n: String, _s: String) -> void: _refresh_diseases())
	_time_label.text = TimeManager.format_time()
	_refresh()
	_refresh_needs()


func _setup_bar_colors() -> void:
	_set_bar_fill(_hp_bar, Color(0.78, 0.12, 0.12))
	_set_bar_fill(_mp_bar, Color(0.12, 0.38, 0.82))
	_set_bar_fill(_st_bar, Color(0.82, 0.52, 0.08))
	_set_bar_fill(_xp_bar, Color(0.48, 0.12, 0.78))


func _set_bar_fill(bar: ProgressBar, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)


func _refresh(_arg: Variant = null) -> void:
	var hp: int     = int(GameState.player_stats["hp"])
	var max_hp: int = int(GameState.player_stats["max_hp"])
	var mp: int     = int(GameState.player_stats.get("mp", 0))
	var max_mp: int = int(GameState.player_stats.get("max_mp", 1))
	var st: int     = int(GameState.player_stats.get("stamina", 0))
	var max_st: int = int(GameState.player_stats.get("max_stamina", 1))

	_hp_bar.max_value = max_hp
	_hp_bar.value     = hp
	_hp_val.text      = "%d/%d" % [hp, max_hp]

	_mp_bar.max_value = max_mp
	_mp_bar.value     = mp
	_mp_val.text      = "%d/%d" % [mp, max_mp]

	_st_bar.max_value = max_st
	_st_bar.value     = st
	_st_val.text      = "%d/%d" % [st, max_st]

	var xp_next: int = LevelSystem.xp_for_next_level(GameState.level)
	_xp_tag.text      = LocaleManager.t("UI_HUD_LEVEL_TAG", {"level": GameState.level})
	_xp_bar.max_value = maxf(1.0, float(xp_next))
	_xp_bar.value     = GameState.xp
	if GameState.level >= LevelSystem.MAX_LEVEL:
		_xp_val.text = LocaleManager.t("UI_HUD_MAX_LEVEL")
	else:
		_xp_val.text = "%d/%d" % [GameState.xp, xp_next]

	gold_label.text  = LocaleManager.t("UI_HUD_GOLD", {"amount": int(GameState.player_stats["gold"])})
	stats_label.text = LocaleManager.t("UI_HUD_STATS", {
		"atk": int(GameState.player_stats["attack"]) + Equipment.get_attack_bonus(),
		"def": int(GameState.player_stats["defense"]) + Equipment.get_defense_bonus(),
	})
	var quest_title: String = QuestManager.get_active_quest_title()
	quest_label.text = LocaleManager.t("UI_HUD_QUEST", {"title": quest_title}) \
		if quest_title != "" else LocaleManager.t("UI_HUD_QUEST_NONE")


func _on_map_changed(map_id: String) -> void:
	map_label.text = LocaleManager.t("UI_HUD_ZONE", {"zone": map_id.replace("_", " ").capitalize()})
	_refresh()


func _on_quest_changed(_id: String) -> void:
	_refresh()


func _on_time_advanced(_minutes: int) -> void:
	_time_label.text = TimeManager.format_time()


# ── Bisogni ───────────────────────────────────────────────────────────────────

func _refresh_needs(_arg: Variant = null) -> void:
	if not _needs_hud_visible:
		_needs_rtl.visible      = false
		_diseases_label.visible = false
		return
	_needs_rtl.visible = true
	var f_lbl: String = LocaleManager.t("UI_HUD_NEEDS_F")
	var w_lbl: String = LocaleManager.t("UI_HUD_NEEDS_W")
	var e_lbl: String = LocaleManager.t("UI_HUD_NEEDS_E")
	_needs_rtl.text = (
		"[color=%s][%s:%d][/color]  [color=%s][%s:%d][/color]  [color=%s][%s:%d][/color]" % [
			_color_food(GameState.food),    f_lbl, int(GameState.food),
			_color_water(GameState.water),  w_lbl, int(GameState.water),
			_color_exh(GameState.exhaustion), e_lbl, int(GameState.exhaustion),
		]
	)
	_refresh_diseases()


func _refresh_diseases() -> void:
	var diseases: Array = GameState.active_diseases
	if diseases.is_empty():
		_diseases_label.visible = false
		return
	_diseases_label.visible = true
	var parts: Array = []
	var dis_reg: Node = get_node_or_null("/root/DiseaseRegistry")
	for d: Variant in diseases:
		var entry: Dictionary = d as Dictionary
		var did:       String = entry.get("id", "?")
		var stage_idx: int    = entry.get("stage_index", 0)
		var display:   String = did
		if dis_reg:
			var def: Dictionary = dis_reg.call("get_def", did)
			if def.has("name"):
				display = str(def["name"])
				var stages: Variant = def.get("stages", [])
				if stages is Array and stage_idx < (stages as Array).size():
					var lbl: Variant = ((stages as Array)[stage_idx] as Dictionary).get("label", "")
					if str(lbl) != "":
						display += " [" + str(lbl) + "]"
		parts.append(display)
	_diseases_label.text = "\n".join(parts)


func toggle_needs_hud() -> void:
	_needs_hud_visible = not _needs_hud_visible
	_refresh_needs()


func _color_food(v: float) -> String:
	if v <= 0.0:  return "#ff0000"
	if v <= 24.0: return "#ff4444"
	if v <= 49.0: return "#ffaa22"
	return "#ffffff"


func _color_water(v: float) -> String:
	if v <= 0.0:  return "#ff0000"
	if v <= 24.0: return "#ff4444"
	if v <= 49.0: return "#ffaa22"
	return "#ffffff"


func _color_exh(v: float) -> String:
	if v >= 100.0: return "#ff0000"
	if v >= 76.0:  return "#ff4444"
	if v >= 31.0:  return "#ffaa22"
	return "#ffffff"
