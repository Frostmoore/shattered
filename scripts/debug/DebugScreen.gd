extends CanvasLayer

const REFRESH_INTERVAL := 0.5
const BG_COLOR         := Color(0.0, 0.0, 0.0, 0.75)
const PANEL_COLOR      := Color(0.06, 0.06, 0.10, 0.97)
const BORDER_COLOR     := Color(0.25, 0.35, 0.55, 1.0)
const MARGIN           := 15
const KEY_EGRAVE       := 232  # 'è'

const TIER_COLORS: Array[Color] = [
	Color(0.35, 0.30, 0.22),
	Color(0.38, 0.38, 0.38),
	Color(0.16, 0.50, 0.26),
	Color(0.13, 0.30, 0.60),
	Color(0.40, 0.16, 0.56),
	Color(0.70, 0.26, 0.10),
	Color(0.62, 0.52, 0.06),
]

const VALIDATOR_PATHS := {
	"Items":        "res://scripts/tools/validators/validate_items.gd",
	"Affissi":      "res://scripts/tools/validators/validate_affixes.gd",
	"Loot Tables":  "res://scripts/tools/validators/validate_loot_tables.gd",
	"Classi":       "res://scripts/tools/validators/validate_classes.gd",
}

const STATE_HEX := {
	"enemy_sworn": "#d92525",
	"hostile":     "#d97325",
	"neutral":     "#aaaaaa",
	"friendly":    "#66d877",
	"allied":      "#4db3ff",
	"trusted":     "#e5cc33",
}

const JOINABLE_FACTIONS: Array[String] = [
	"corporazione_camere", "cacciatori_rogna", "collegio_cartografi",
	"compagnia_ponti", "corrieri_sigillo", "congregazione_officine", "tavola_senza_nome",
]

const TILE_DEFS: Array[Dictionary] = [
	{"id": "player",        "title": "PLAYER",        "color": Color(0.08, 0.20, 0.45)},
	{"id": "combattimento", "title": "COMBATTIMENTO",  "color": Color(0.42, 0.08, 0.10)},
	{"id": "tempo",         "title": "TEMPO",          "color": Color(0.08, 0.25, 0.38)},
	{"id": "classi",        "title": "CLASSI",         "color": Color(0.38, 0.28, 0.04)},
	{"id": "fazioni",       "title": "FAZIONI",        "color": Color(0.26, 0.08, 0.42)},
	{"id": "crimini",       "title": "CRIMINI",        "color": Color(0.46, 0.16, 0.04)},
	{"id": "loot",          "title": "LOOT / ITEM",    "color": Color(0.08, 0.28, 0.14)},
	{"id": "bisogni",       "title": "BISOGNI",        "color": Color(0.38, 0.18, 0.04)},
]

# ── Stato UI ─────────────────────────────────────────────────────────────────

var _sections: Dictionary = {}
var _timer:    Timer

var _switcher_current_lbl: Label
var _val_result_lbl:       RichTextLabel
var _faction_rep_rtl:      RichTextLabel = null
var _faction_member_rtl:   RichTextLabel = null
var _faction_rep_opt:      OptionButton  = null
var _faction_propagate_cb: CheckButton   = null

# Tile navigation
var _active_tile:       String     = ""
var _tile_btns:         Dictionary = {}
var _tile_bodies:       Dictionary = {}   # VBoxContainer per tile (tool panels)
var _sections_grids:    Dictionary = {}   # GridContainer 2-col per tile (DebugSection)
var _content_host:      PanelContainer
var _content_title_lbl: Label

# Status bar
var _sb_sistema: RichTextLabel
var _sb_player:  RichTextLabel
var _sb_tempo:   RichTextLabel
var _sb_bisogni: RichTextLabel


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	layer   = 100
	visible = false
	_build_ui()
	_setup_timer()

	# ── PLAYER ──────────────────────────────────────────────────────────────
	var p_sg: Node = _sections_grids["player"]
	_add_section("game_state",      "GameState",         p_sg)
	_add_section("class_runtime",   "ClassRuntime",      p_sg)
	_add_section("class_special",   "ClassSpecial",      p_sg)
	_add_section("ability_tracker", "AbilityUseTracker", p_sg)
	_add_section("class_picker",    "ClassPicker",       p_sg)
	_add_section("milestones",      "Milestones",        p_sg)
	_add_section("respec",          "Respec",            p_sg)

	# ── COMBATTIMENTO ────────────────────────────────────────────────────────
	var c_sg: Node = _sections_grids["combattimento"]
	_add_section("damage_pipe",    "DamagePipeline", c_sg)
	_add_section("status_effects", "StatusEffects",  c_sg)
	_add_section("targeting",      "Targeting",      c_sg)
	_add_section("ally_manager",   "AllyManager",    c_sg)
	_add_section("druid_form",     "DruidForm",      c_sg)

	# ── TEMPO ────────────────────────────────────────────────────────────────
	var t_sg: Node = _sections_grids["tempo"]
	_add_section("sistema",     "Sistema",     t_sg)
	_add_section("time_system", "Time System", t_sg)
	_build_time_tools(_tile_bodies["tempo"])

	# ── CLASSI ───────────────────────────────────────────────────────────────
	_add_section("class_db", "ClassRegistry", _sections_grids["classi"])
	_build_class_switcher(_tile_bodies["classi"])

	# ── FAZIONI ──────────────────────────────────────────────────────────────
	_add_section("faction_db", "FactionDB", _sections_grids["fazioni"])
	_build_faction_tools(_tile_bodies["fazioni"])

	# ── CRIMINI ──────────────────────────────────────────────────────────────
	_add_section("crime", "CrimeSystem", _sections_grids["crimini"])
	_build_crime_tools(_tile_bodies["crimini"])

	# ── LOOT / ITEM ──────────────────────────────────────────────────────────
	_add_section("loot_db", "LootDB", _sections_grids["loot"])
	_build_loot_tools(_tile_bodies["loot"])
	_build_validation_tools(_tile_bodies["loot"])

	# ── BISOGNI ──────────────────────────────────────────────────────────────
	_add_section("needs", "Needs System", _sections_grids["bisogni"])
	_build_needs_tools(_tile_bodies["bisogni"])

	_refresh()


# ── Costruzione UI ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = BG_COLOR
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = PANEL_COLOR
	pstyle.border_color = BORDER_COLOR
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(3)
	pstyle.content_margin_left   = 10.0
	pstyle.content_margin_right  = 10.0
	pstyle.content_margin_top    = 8.0
	pstyle.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left   = MARGIN
	panel.offset_right  = -MARGIN
	panel.offset_top    = MARGIN
	panel.offset_bottom = -MARGIN
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	panel.add_child(outer)

	# Titolo
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title_lbl := Label.new()
	title_lbl.text = "  DEBUG"
	title_lbl.add_theme_color_override("font_color", Color(0.45, 0.70, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = "È per chiudere"
	hint_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	hint_lbl.add_theme_font_size_override("font_size", 10)
	title_row.add_child(hint_lbl)

	outer.add_child(HSeparator.new())

	# Status bar
	var sb := HBoxContainer.new()
	sb.add_theme_constant_override("separation", 6)
	outer.add_child(sb)
	_sb_sistema = _make_status_panel(sb, Color(0.06, 0.08, 0.18))
	_sb_player  = _make_status_panel(sb, Color(0.06, 0.16, 0.06))
	_sb_tempo   = _make_status_panel(sb, Color(0.10, 0.06, 0.20))
	_sb_bisogni = _make_status_panel(sb, Color(0.20, 0.10, 0.04))

	outer.add_child(HSeparator.new())

	# Azioni rapide
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	outer.add_child(controls)

	var lvup_btn := Button.new()
	lvup_btn.text = "+ Livello"
	lvup_btn.add_theme_font_size_override("font_size", 10)
	lvup_btn.pressed.connect(_do_level_up)
	controls.add_child(lvup_btn)

	var sim_btn := Button.new()
	sim_btn.text = "TTK Sim"
	sim_btn.add_theme_font_size_override("font_size", 10)
	sim_btn.pressed.connect(_do_ttk_sim)
	controls.add_child(sim_btn)

	outer.add_child(HSeparator.new())

	# Area principale scrollabile
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(scroll_vbox)

	# Griglia tile 4×2
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_child(grid)

	for tile: Dictionary in TILE_DEFS:
		_build_tile(grid, tile)

	# Content host (accordion)
	_content_host = PanelContainer.new()
	_content_host.visible = false
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ch_style := StyleBoxFlat.new()
	ch_style.bg_color = Color(0.04, 0.04, 0.08)
	ch_style.border_color = BORDER_COLOR
	ch_style.set_border_width_all(1)
	ch_style.set_corner_radius_all(4)
	ch_style.content_margin_left   = 10.0
	ch_style.content_margin_right  = 10.0
	ch_style.content_margin_top    = 8.0
	ch_style.content_margin_bottom = 8.0
	_content_host.add_theme_stylebox_override("panel", ch_style)
	scroll_vbox.add_child(_content_host)

	var host_vbox := VBoxContainer.new()
	host_vbox.add_theme_constant_override("separation", 5)
	_content_host.add_child(host_vbox)

	_content_title_lbl = Label.new()
	_content_title_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 1.0))
	_content_title_lbl.add_theme_font_size_override("font_size", 11)
	host_vbox.add_child(_content_title_lbl)

	host_vbox.add_child(HSeparator.new())

	var content_scroll := ScrollContainer.new()
	content_scroll.custom_minimum_size = Vector2(0, 380)
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host_vbox.add_child(content_scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 3)
	content_scroll.add_child(content_vbox)

	for tile: Dictionary in TILE_DEFS:
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 4)
		body.visible = false
		content_vbox.add_child(body)
		_tile_bodies[str(tile["id"])] = body

		var sg := GridContainer.new()
		sg.columns = 2
		sg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sg.add_theme_constant_override("h_separation", 10)
		sg.add_theme_constant_override("v_separation", 2)
		body.add_child(sg)
		_sections_grids[str(tile["id"])] = sg


func _build_tile(parent: GridContainer, tile: Dictionary) -> void:
	var tid:   String = str(tile["id"])
	var title: String = str(tile["title"])
	var col:   Color  = tile["color"] as Color

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 58)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = title
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal",  _tile_style(col, false))
	btn.add_theme_stylebox_override("hover",   _tile_style(col.lightened(0.18), false))
	btn.add_theme_stylebox_override("pressed", _tile_style(col.darkened(0.15), false))
	btn.pressed.connect(_toggle_tile.bind(tid))
	parent.add_child(btn)
	_tile_btns[tid] = btn


func _tile_style(col: Color, active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	if active:
		s.border_color = Color(0.60, 0.70, 1.0)
		s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 6.0
	s.content_margin_bottom = 6.0
	return s


func _toggle_tile(id: String) -> void:
	if _active_tile == id:
		_active_tile = ""
		_content_host.visible = false
		_update_tile_visuals()
		return
	_active_tile = id
	for tid: String in _tile_bodies.keys():
		(_tile_bodies[tid] as VBoxContainer).visible = (tid == id)
	for tile: Dictionary in TILE_DEFS:
		if str(tile["id"]) == id:
			_content_title_lbl.text = "  %s" % str(tile["title"])
			break
	_content_host.visible = true
	_update_tile_visuals()


func _update_tile_visuals() -> void:
	for tile: Dictionary in TILE_DEFS:
		var tid: String = str(tile["id"])
		if not _tile_btns.has(tid):
			continue
		var btn: Button = _tile_btns[tid] as Button
		var col: Color  = tile["color"] as Color
		var active: bool = (_active_tile == tid)
		btn.add_theme_stylebox_override("normal",
			_tile_style(col.lightened(0.15) if active else col, active))


func _set_tile_subtitle(id: String, status: String) -> void:
	if not _tile_btns.has(id):
		return
	var title: String = ""
	for t: Dictionary in TILE_DEFS:
		if str(t["id"]) == id:
			title = str(t["title"])
			break
	(_tile_btns[id] as Button).text = title + "\n" + status


func _make_status_panel(parent: HBoxContainer, bg: Color) -> RichTextLabel:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(4)
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 5.0
	s.content_margin_bottom = 5.0
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content    = true
	rtl.scroll_active  = false
	rtl.add_theme_font_size_override("normal_font_size", 10)
	p.add_child(rtl)
	return rtl


# ── Timer e input ─────────────────────────────────────────────────────────────

func _setup_timer() -> void:
	_timer = Timer.new()
	_timer.wait_time  = REFRESH_INTERVAL
	_timer.autostart  = false
	_timer.timeout.connect(_refresh)
	add_child(_timer)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.unicode == KEY_EGRAVE:
			visible = not visible
			if visible:
				_refresh()
				_timer.start()
			else:
				_timer.stop()
			get_viewport().set_input_as_handled()


# ── Sezioni ───────────────────────────────────────────────────────────────────

func _add_section(key: String, title: String, parent: Node) -> DebugSection:
	var section := DebugSection.new()
	section.setup(title)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	_sections[key] = section
	return section


func get_section(key: String) -> DebugSection:
	return _sections.get(key, null)


func has_section(key: String) -> bool:
	return _sections.has(key)


# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh(_arg: Variant = null) -> void:
	_update_status_bar()
	_update_tile_statuses()
	_update_sistema()
	_update_class_registry()
	_update_game_state()
	_update_class_picker()
	_update_damage_pipeline()
	_update_class_runtime()
	_update_ability_tracker()
	_update_class_special()
	_update_status_effects()
	_update_targeting()
	_update_ally_manager()
	_update_druid_form()
	_update_milestones()
	_update_respec()
	_update_loot_db()
	_update_faction_db()
	_update_faction_rep_table()
	_update_faction_member_table()
	_update_switcher()
	_update_crime()
	_update_time_system()
	_update_needs()


# ── Status bar ────────────────────────────────────────────────────────────────

func _update_status_bar() -> void:
	if is_instance_valid(_sb_sistema):
		var vi: Dictionary = Engine.get_version_info()
		var vp: Vector2    = get_viewport().get_visible_rect().size
		_sb_sistema.text = (
			"[b]SISTEMA[/b]\n[color=#888888]FPS: %d  |  %dx%d  |  Godot %s[/color]" % [
				Engine.get_frames_per_second(),
				int(vp.x), int(vp.y),
				vi.get("string", "4.x"),
			]
		)

	if is_instance_valid(_sb_player):
		var ps: Dictionary = GameState.player_stats
		_sb_player.text = (
			"[b]PLAYER[/b]\n[color=#888888]%s  Lv%d  |  HP:[color=#cc4444]%d/%d[/color]  MP:[color=#4488cc]%d/%d[/color][/color]" % [
				str(GameState.current_class), GameState.level,
				int(ps.get("hp", 0)), int(ps.get("max_hp", 1)),
				int(ps.get("mp", 0)), int(ps.get("max_mp", 1)),
			]
		)

	if is_instance_valid(_sb_tempo):
		var tm: Node = get_node_or_null("/root/TimeManager")
		var t_str: String = tm.call("format_time")    if tm else "--:--"
		var d_str: String = "Gg%d" % tm.call("get_absolute_day") if tm else "—"
		_sb_tempo.text = (
			"[b]TEMPO[/b]\n[color=#888888]%s  %s  |  min: %d[/color]" % [
				t_str, d_str, GameState.total_minutes
			]
		)

	if is_instance_valid(_sb_bisogni):
		_sb_bisogni.text = (
			"[b]BISOGNI[/b]\n[color=%s]F:%.0f[/color]  [color=%s]A:%.0f[/color]  [color=%s]E:%.0f[/color]  [color=#888888]|  %d mal.[/color]" % [
				_cn_f(GameState.food),       GameState.food,
				_cn_w(GameState.water),      GameState.water,
				_cn_e(GameState.exhaustion), GameState.exhaustion,
				GameState.active_diseases.size(),
			]
		)


func _update_tile_statuses() -> void:
	var ps: Dictionary = GameState.player_stats
	_set_tile_subtitle("player",
		"Lv%d %s  HP:%d/%d" % [
			GameState.level, str(GameState.current_class),
			int(ps.get("hp", 0)), int(ps.get("max_hp", 1)),
		])

	var sem: Node = get_node_or_null("/root/StatusEffectManager")
	var eff_count: int = (sem.get("_effects") as Dictionary).size() if sem else 0
	var am: Node = get_node_or_null("/root/AllyManager")
	var ally_count: int = am.call("get_allies").size() if am else 0
	_set_tile_subtitle("combattimento", "Effetti: %d  Alleati: %d" % [eff_count, ally_count])

	var tm: Node = get_node_or_null("/root/TimeManager")
	_set_tile_subtitle("tempo",
		"%s  Gg%d" % [
			tm.call("format_time") if tm else "--:--",
			tm.call("get_absolute_day") if tm else 0,
		])

	var reg: Node = get_node_or_null("/root/ClassRegistry")
	var impl_n: int = reg.call("get_implemented").size() if reg else 0
	_set_tile_subtitle("classi", "Impl: %d  Attiva: %s" % [impl_n, str(GameState.current_class)])

	var freg: Node = get_node_or_null("/root/FactionRegistry")
	var total_f: int = freg.call("get_all_factions").size() if freg else 0
	var memb_n: int = 0
	for fid: String in JOINABLE_FACTIONS:
		if FactionMembership.is_member(fid): memb_n += 1
	_set_tile_subtitle("fazioni", "%d fazioni  Membro: %d" % [total_f, memb_n])

	var city_id: String = GameState.current_city_id
	var crime_on: bool  = city_id != "" and CrimeSystem.is_crime_active(city_id)
	var rec_n: int = CrimeSystem.get_criminal_record().size()
	_set_tile_subtitle("crimini",
		"%s  Fedina: %d" % [("RICERCATO" if crime_on else "pulito"), rec_n])

	var idb: Node = get_node_or_null("/root/ItemDB")
	var item_n: int = (idb.get("_items") as Dictionary).size() if idb else 0
	var iadb: Node = get_node_or_null("/root/ItemAffixDB")
	var affix_n: int = (iadb.get("_affixes") as Dictionary).size() if iadb else 0
	_set_tile_subtitle("loot", "Item: %d  Affissi: %d" % [item_n, affix_n])

	_set_tile_subtitle("bisogni",
		"F:%.0f  A:%.0f  E:%.0f  Mal:%d" % [
			GameState.food, GameState.water,
			GameState.exhaustion, GameState.active_diseases.size(),
		])


func _cn_f(v: float) -> String:
	if v <= 0.0:  return "#ff3333"
	if v <= 24.0: return "#ff7777"
	if v <= 49.0: return "#ffaa44"
	return "#66bb66"

func _cn_w(v: float) -> String:
	if v <= 0.0:  return "#ff3333"
	if v <= 24.0: return "#ff7777"
	if v <= 49.0: return "#ffaa44"
	return "#66aadd"

func _cn_e(v: float) -> String:
	if v >= 100.0: return "#ff3333"
	if v >= 76.0:  return "#ff7777"
	if v >= 31.0:  return "#ffaa44"
	return "#66bb66"


# ── Sezioni informative ───────────────────────────────────────────────────────

func _update_sistema() -> void:
	var s: DebugSection = get_section("sistema")
	if not s: return
	var vi: Dictionary = Engine.get_version_info()
	var vp: Vector2    = get_viewport().get_visible_rect().size
	var tm: Node = get_node_or_null("/root/TimeManager")
	var time_line: String
	if tm:
		time_line = "Ora:          %02d:%02d  (tot %d min)" % [
			tm.call("get_hour"), tm.call("get_minute"), GameState.total_minutes
		]
	else:
		time_line = "Ora:          TimeManager non caricato"
	s.update([
		"FPS:          %d"    % Engine.get_frames_per_second(),
		"Godot:        %s"    % vi.get("string", "4.x"),
		"Build:        debug",
		"Piattaforma:  %s"    % OS.get_name(),
		"Risoluzione:  %dx%d" % [int(vp.x), int(vp.y)],
		time_line,
	])


func _update_class_registry() -> void:
	var s: DebugSection = get_section("class_db")
	if not s: return
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		s.update(["ClassRegistry: non caricato"])
		return
	var lines: Array[String] = []
	for tier: int in range(0, 7):
		var tier_classes: Array = reg.call("get_by_tier", tier)
		lines.append("Tier %d: %d classi" % [tier, tier_classes.size()])
	var impl: Array = reg.call("get_implemented")
	lines.append("Implementate: %d" % impl.size())
	s.update(lines)


func _update_class_picker() -> void:
	var s: DebugSection = get_section("class_picker")
	if not s: return
	var picker: Node = get_node_or_null("/root/Main/_class_picker")
	if not picker:
		var main: Node = get_node_or_null("/root/Main")
		if main:
			for child: Node in main.get_children():
				if child.get_script() and str(child.get_script().resource_path).ends_with("ClassPickerPanel.gd"):
					picker = child
					break
	if not picker:
		s.update(["ClassPickerPanel: non trovato"])
		return
	var gs: Node = get_node_or_null("/root/GameState")
	var current: String = ""
	if gs: current = str(gs.get("current_class"))
	s.update([
		"Visibile: %s"          % str(picker.visible),
		"Classe attuale: %s"    % current,
		"Classi in griglia: %d" % picker.call("_get_card_count"),
	])


func _update_game_state() -> void:
	var s: DebugSection = get_section("game_state")
	if not s: return
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs:
		s.update(["GameState: non caricato"])
		return
	var ba: Dictionary = gs.get("base_attributes")
	var cb: Dictionary = gs.get("class_bonus")
	var ea: Dictionary = gs.get("effective_attributes")
	var lines: Array[String] = [
		"Classe:  %s"  % str(gs.get("current_class")),
		"Livello: %d"  % int(gs.get("level")),
		"",
		"attr  | base | bonus | eff",
		"------+------+-------+----",
	]
	for attr: String in ["str", "dex", "int", "vit", "wil"]:
		lines.append("%-5s | %-4d | %-5d | %d" % [
			attr,
			int(ba.get(attr, 0)),
			int(cb.get(attr, 0)),
			int(ea.get(attr, 0)),
		])
	var ps: Dictionary = gs.get("player_stats")
	lines.append("")
	lines.append("HP %d/%d  MP %d/%d" % [
		int(ps.get("hp", 0)), int(ps.get("max_hp", 0)),
		int(ps.get("mp", 0)), int(ps.get("max_mp", 0)),
	])
	s.update(lines)


func _update_damage_pipeline() -> void:
	var s: DebugSection = get_section("damage_pipe")
	if not s: return
	var pipe: Node = get_node_or_null("/root/DamagePipeline")
	if not pipe:
		s.update(["DamagePipeline: non caricato"])
		return
	s.update(["DamagePipeline: OK", "Pronto a ricevere DamageContext"])


func _update_class_runtime() -> void:
	var s: DebugSection = get_section("class_runtime")
	if not s: return
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if not rt:
		s.update(["ClassRuntime: non caricato"])
		return
	var counters: Dictionary = rt.get("hook_counters")
	var active_id: String    = str(rt.call("get_active_special_id"))
	var has_special: bool    = rt.get("_active_special") != null
	s.update([
		"Classe attiva: %s"     % active_id,
		"Special caricata: %s"  % ("sì" if has_special else "no (planned)"),
		"",
		"Hook invocazioni:",
		"  before_attack:  %d"  % int(counters.get("before_attack",  0)),
		"  after_attack:   %d"  % int(counters.get("after_attack",   0)),
		"  before_damaged: %d"  % int(counters.get("before_damaged", 0)),
		"  after_damaged:  %d"  % int(counters.get("after_damaged",  0)),
		"  enemy_killed:   %d"  % int(counters.get("enemy_killed",   0)),
	])


func _update_ability_tracker() -> void:
	var s: DebugSection = get_section("ability_tracker")
	if not s: return
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if not rt:
		s.update(["ClassRuntime: non caricato"])
		return
	var tracker: Object = rt.call("get_tracker")
	if not tracker:
		s.update(["Tracker: non attivo (classe senza limite)"])
		return
	s.update([
		"Descrizione: %s"  % str(tracker.call("describe")),
		"Può usare:   %s"  % ("sì" if bool(tracker.call("can_use")) else "NO"),
		"Usi rimasti: %d"  % int(tracker.call("get_uses_remaining")),
		"Cooldown:    %dt" % int(tracker.call("get_cooldown_remaining")),
	])


func _update_class_special() -> void:
	var s: DebugSection = get_section("class_special")
	if not s: return
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if not rt:
		s.update(["ClassRuntime: non caricato"])
		return
	var special: Object = rt.get("_active_special")
	if not special:
		s.update(["Special: non caricata (classe planned)"])
		return
	var gs: Node = get_node_or_null("/root/GameState")
	var script_name: String = special.get_script().resource_path.get_file().trim_suffix(".gd")
	var lines: Array[String] = ["Tipo: %s" % script_name]
	if gs:
		var stats: Dictionary = gs.get("player_stats")
		var ea: Dictionary    = gs.get("effective_attributes")
		var hp: int     = int(stats.get("hp",     0))
		var max_hp: int = int(stats.get("max_hp", 1))
		var vit: int    = int(ea.get("vit", 0))
		var dex: int    = int(ea.get("dex", 0))
		var _int_s: int  = int(ea.get("int", 0))
		var miss: float = 1.0 - float(hp) / float(maxf(1.0, float(max_hp)))
		lines.append("HP: %d/%d (%.0f%% mancanti)" % [hp, max_hp, miss * 100.0])
		lines.append("")
		match script_name:
			"WarriorFury":
				lines.append("Furia: %s" % ("ATTIVA" if miss > 0.70 else "inattiva (HP > 30%)"))
			"MonkDodge":
				lines.append("Schivata: %.0f%%" % (minf(float(dex) / 100.0, 0.40) * 100.0))
			"PaladinLayOnHands":
				lines.append("Cura disponibile: %d HP (VIT×3)" % (vit * 3))
			"BardSong":
				var turns: int = int(special.get("_turns_left"))
				lines.append("Ballata: %s" % ("%dt rimasti" % turns if turns > 0 else "inattiva"))
			"GuardianShield":
				var shield: int = int(special.get("_shield_hp"))
				lines.append("Scudo: %s" % ("%d HP rimasti" % shield if shield > 0 else "inattivo"))
			"SpellbladeEnchant":
				var charges: int = int(special.get("_charges"))
				lines.append("Cariche: %d/%d" % [charges, 3])
			"WarlockDarkPact":
				var bonus: float = int(miss * 10.0) * 5.0
				lines.append("Bonus ATK passivo: +%.0f%%" % bonus)
				lines.append("Costo Q: 5 HP → 5 MP")
			"RogueBackstab":
				lines.append("Primo attacco: %s" % ("PRONTO" if bool(special.get("_first_attack")) else "usato"))
			"BarbarianWarcry":
				lines.append("Usa Q per debuffare tutti i nemici in combattimento")
			"CorsairDirtyHit":
				lines.append("Stun chance: %.0f%%" % (0.35 * 100.0))
			"BerserkerFrenzy":
				var tm_node: Node = get_node_or_null("/root/TurnManager")
				var in_combat: bool = tm_node != null and bool(tm_node.get("is_active"))
				lines.append("In combattimento: %s" % ("sì → ATK ×1.4" if in_combat else "no"))
				lines.append("Oggetti bloccati: %s" % ("SÌ" if in_combat else "no"))
			"SentinelGuard":
				var stacks: int = int(special.get("_guard_stacks"))
				lines.append("Guard stacks: %d/%d → DEF ×%d" % [stacks, 3, stacks + 1])
	s.update(lines)


func _update_status_effects() -> void:
	var s: DebugSection = get_section("status_effects")
	if not s: return
	var sem: Node = get_node_or_null("/root/StatusEffectManager")
	if not sem:
		s.update(["StatusEffectManager: non caricato"])
		return
	var all_effects: Dictionary = sem.get("_effects")
	if all_effects.is_empty():
		s.update(["Nessun effetto attivo"])
		return
	var lines: Array[String] = []
	for tid: int in all_effects:
		var effects: Array = all_effects[tid]
		if effects.is_empty(): continue
		var entity_name: String = "id:%d" % tid
		var instance = instance_from_id(tid)
		if is_instance_valid(instance) and instance.has_method("get"):
			entity_name = str(instance.get("display_name"))
		var parts: Array[String] = []
		for fx: Variant in effects:
			if fx is Dictionary:
				var d: Dictionary = fx as Dictionary
				parts.append("%s(%dt)" % [str(d.get("id", "?")), int(d.get("duration_turns", 0))])
		lines.append("%s: %s" % [entity_name, ", ".join(parts)])
	s.update(lines)


func _update_targeting() -> void:
	var s: DebugSection = get_section("targeting")
	if not s: return
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if not rt:
		s.update(["ClassRuntime: non caricato"])
		return
	var overlay: Node = rt.get("_targeting_overlay")
	if not overlay:
		s.update(["TargetingOverlay: non registrato"])
		return
	var active: bool    = bool(overlay.call("is_active"))
	var player: Variant = rt.get("_targeting_player")
	var lines: Array[String] = [
		"Overlay attivo: %s"     % ("SÌ" if active else "no"),
		"Player in attesa: %s"   % ("sì" if (player != null and is_instance_valid(player)) else "no"),
	]
	if active:
		var valid_tiles: Array = overlay.get("_valid_tiles")
		var hover: Vector2i   = overlay.get("_hover_tile")
		lines.append("Tile valide: %d" % valid_tiles.size())
		lines.append("Hover: (%d,%d)" % [hover.x, hover.y])
	var special: Object = rt.get("_active_special")
	if special:
		lines.append("Special: %s" % special.get_script().resource_path.get_file())
	s.update(lines)


func _update_ally_manager() -> void:
	var s: DebugSection = get_section("ally_manager")
	if not s: return
	var am: Node = get_node_or_null("/root/AllyManager")
	if not am:
		s.update(["AllyManager: non caricato"])
		return
	var allies: Array = am.call("get_allies")
	if allies.is_empty():
		s.update(["Nessun alleato attivo"])
		return
	var lines: Array[String] = ["Alleati: %d" % allies.size(), ""]
	for ally: Variant in allies:
		if ally is Dictionary:
			var a: Dictionary = ally as Dictionary
			var tl: int = int(a.get("turns_left", -1))
			var dur_str: String = "permanente" if tl < 0 else "%dt" % tl
			lines.append("• %s  HP:%d/%d  ATK×%.1f  [%s]" % [
				str(a.get("display_name", "?")),
				int(a.get("hp", 0)), int(a.get("max_hp", 0)),
				float(a.get("atk_mult", 0.5)),
				dur_str
			])
	s.update(lines)


func _update_druid_form() -> void:
	var s: DebugSection = get_section("druid_form")
	if not s: return
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if not rt:
		s.update(["ClassRuntime: non caricato"])
		return
	var special: Object = rt.get("_active_special")
	if not special or not special.has_method("get_wolf_form"):
		s.update(["DruidShapeshift: non attivo"])
		return
	var bear: bool = bool(special.call("get_bear_form")) if special.has_method("get_bear_form") else false
	var wolf: bool = bool(special.call("get_wolf_form"))
	var turns: int = int(special.call("get_form_turns_left")) if special.has_method("get_form_turns_left") else 0
	var form_str: String
	if bear:
		form_str = "Orso (ATK x1.5)"
	elif wolf:
		form_str = "Lupo (schivata+20%)"
	else:
		form_str = "Umana"
	s.update([
		"Forma:   %s" % form_str,
		"Turni:   %s" % (str(turns) if turns > 0 else "—"),
	])


func _update_milestones() -> void:
	var s: DebugSection = get_section("milestones")
	if not s: return
	var gmt: Node = get_node_or_null("/root/GlobalMilestoneTracker")
	if not gmt:
		s.update(["GlobalMilestoneTracker: non caricato"])
		return
	var data: Dictionary = gmt.call("get_all_data")
	var unlocked: Array  = gmt.call("get_unlocked_classes")
	var completed: Array = gmt.call("get_completed_classes")
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	var total: int = reg.call("get_all").size() if reg else 60
	var lines: Array[String] = [
		"Sbloccate:   %d / %d" % [unlocked.size(), total],
		"Completate:  %d / %d" % [completed.size(), total],
		"──────────────────",
		"kills_total:      %d" % int(data.get("kills_total",           0)),
		"kills_boss:       %d" % int(data.get("kills_boss",            0)),
		"deaths_total:     %d" % int(data.get("deaths_total",          0)),
		"dungeon_floors:   %d" % int(data.get("dungeon_floors_total",  0)),
		"chests_opened:    %d" % int(data.get("chests_opened",         0)),
		"save_points:      %d" % int(data.get("save_points_used",      0)),
		"dmg_dealt:        %d" % int(data.get("damage_dealt_total",    0)),
		"dmg_taken:        %d" % int(data.get("damage_taken_total",    0)),
		"──────────────────",
		"Run corrente:",
		"  kills:     %d" % int(GameState.run_milestones.get("kills_total",           0)),
		"  floors:    %d" % int(GameState.run_milestones.get("dungeon_floors_total",   0)),
		"  dmg dealt: %d" % int(GameState.run_milestones.get("damage_dealt_total",    0)),
	]
	s.update(lines)


func _update_respec() -> void:
	var s: DebugSection = get_section("respec")
	if not s: return
	var svc: Node = get_node_or_null("/root/ClassRespecService")
	var gmt: Node = get_node_or_null("/root/GlobalMilestoneTracker")
	var gs: Node  = get_node_or_null("/root/GameState")
	if not svc:
		s.update(["ClassRespecService: non caricato"])
		return
	var respec_count: int = gmt.call("get_value", "class_respec_count") if gmt else 0
	var current: String   = str(gs.get("current_class")) if gs else "—"
	var ba: Dictionary = gs.get("base_attributes")      if gs else {}
	var cb: Dictionary = gs.get("class_bonus")          if gs else {}
	var ea: Dictionary = gs.get("effective_attributes") if gs else {}
	var lines: Array[String] = [
		"Classe attiva:  %s" % current,
		"Respec count:   %d" % respec_count,
		"",
		"attr  | base | bonus | eff",
		"------+------+-------+----",
	]
	for attr: String in ["str", "dex", "int", "vit", "wil"]:
		lines.append("%-5s | %-4d | %-5d | %d" % [
			attr,
			int(ba.get(attr, 0)),
			int(cb.get(attr, 0)),
			int(ea.get(attr, 0)),
		])
	s.update(lines)


# ── DevClassSwitch ────────────────────────────────────────────────────────────

func _build_class_switcher(parent: VBoxContainer) -> void:
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg: return

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var header := Button.new()
	header.text = "▼ DevClassSwitch"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	header.add_theme_font_size_override("font_size", 11)
	wrapper.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	wrapper.add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼ " if body.visible else "► ") + "DevClassSwitch"
	)

	_switcher_current_lbl = Label.new()
	_switcher_current_lbl.add_theme_font_size_override("font_size", 10)
	_switcher_current_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	body.add_child(_switcher_current_lbl)

	body.add_child(HSeparator.new())

	var all_classes: Array[Dictionary] = reg.call("get_all")
	for tier: int in range(0, 7):
		var tier_classes: Array = all_classes.filter(
			func(d: Dictionary) -> bool: return int(d.get("tier", 0)) == tier
		)
		if tier_classes.is_empty(): continue

		var tier_lbl := Label.new()
		tier_lbl.text = "Tier %d" % tier
		tier_lbl.add_theme_font_size_override("font_size", 9)
		tier_lbl.add_theme_color_override("font_color", TIER_COLORS[tier].lightened(0.4))
		body.add_child(tier_lbl)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 3)
		flow.add_theme_constant_override("v_separation", 3)
		body.add_child(flow)

		for data: Dictionary in tier_classes:
			var class_id: String      = str(data.get("id", ""))
			var class_name_str: String = str(data.get("name", class_id))
			var is_impl: bool = str((data.get("implementation", {}) as Dictionary) \
				.get("status", "")) == "implemented"

			var btn := Button.new()
			btn.text = class_name_str
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 9)
			btn.tooltip_text = "[Tier %d]  %s%s" % [
				tier, class_id, "" if is_impl else "  (planned)"
			]
			var bg_col: Color = TIER_COLORS[tier] if is_impl else TIER_COLORS[tier].darkened(0.5)
			var style_btn := StyleBoxFlat.new()
			style_btn.bg_color = bg_col
			style_btn.set_corner_radius_all(3)
			style_btn.content_margin_left   = 6.0
			style_btn.content_margin_right  = 6.0
			style_btn.content_margin_top    = 2.0
			style_btn.content_margin_bottom = 2.0
			btn.add_theme_stylebox_override("normal",   style_btn)
			btn.add_theme_stylebox_override("hover",    _btn_hover_style(bg_col))
			btn.add_theme_stylebox_override("pressed",  _btn_pressed_style(bg_col))
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.pressed.connect(_do_class_switch.bind(class_id))
			flow.add_child(btn)


func _do_ttk_sim() -> void:
	CombatSimulator.run_validation()


func _do_level_up() -> void:
	if GameState.level >= 100: return
	GameState.level += 1
	var ls: Node = get_node_or_null("/root/LevelSystem")
	if ls: ls.call("_apply_level_up")
	_refresh()


func _btn_hover_style(base: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = base.lightened(0.25)
	s.set_corner_radius_all(3)
	s.content_margin_left = 6.0; s.content_margin_right  = 6.0
	s.content_margin_top  = 2.0; s.content_margin_bottom = 2.0
	return s


func _btn_pressed_style(base: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = base.darkened(0.2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 6.0; s.content_margin_right  = 6.0
	s.content_margin_top  = 2.0; s.content_margin_bottom = 2.0
	return s


func _do_class_switch(class_id: String) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs: return
	if str(gs.get("character_name")) == "":
		var rt: Node = get_node_or_null("/root/ClassRuntime")
		if rt: rt.call("set_active_class", class_id)
		return
	gs.call("apply_class", class_id)
	_refresh()


func _update_loot_db() -> void:
	var s: DebugSection = get_section("loot_db")
	if not s: return
	var idb:  Node = get_node_or_null("/root/ItemDB")
	var iadb: Node = get_node_or_null("/root/ItemAffixDB")
	var ltdb: Node = get_node_or_null("/root/LootTableDB")
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	var lres: Node = get_node_or_null("/root/LootResolver")
	s.update([
		"ItemDB:        %s  (%d item)"    % [("OK" if idb  else "NON CARICATO"), (idb.get("_items")   as Dictionary).size() if idb  else 0],
		"ItemAffixDB:   %s  (%d affissi)" % [("OK" if iadb else "NON CARICATO"), (iadb.get("_affixes") as Dictionary).size() if iadb else 0],
		"LootTableDB:   %s  (%d cache)"   % [("OK" if ltdb else "NON CARICATO"), (ltdb.get("_cache")  as Dictionary).size() if ltdb else 0],
		"ItemGenerator: %s"               %  ("OK" if igen else "NON CARICATO"),
		"LootResolver:  %s"               %  ("OK" if lres else "NON CARICATO"),
	])


func _build_loot_tools(parent: VBoxContainer) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var header := Button.new()
	header.text = "▼ LootTools"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	header.add_theme_font_size_override("font_size", 11)
	wrapper.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	wrapper.add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼ " if body.visible else "► ") + "LootTools"
	)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	body.add_child(row1)

	var btn_enemy := Button.new()
	btn_enemy.text = "Simula nemico"
	btn_enemy.add_theme_font_size_override("font_size", 10)
	btn_enemy.pressed.connect(_debug_loot_enemy)
	row1.add_child(btn_enemy)

	var btn_chest := Button.new()
	btn_chest.text = "Simula chest"
	btn_chest.add_theme_font_size_override("font_size", 10)
	btn_chest.pressed.connect(_debug_loot_chest)
	row1.add_child(btn_chest)

	var btn_ground := Button.new()
	btn_ground.text = "Simula ground"
	btn_ground.add_theme_font_size_override("font_size", 10)
	btn_ground.pressed.connect(_debug_loot_ground)
	row1.add_child(btn_ground)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	body.add_child(row2)

	var btn_drop := Button.new()
	btn_drop.text = "Drop spada_corta"
	btn_drop.add_theme_font_size_override("font_size", 10)
	btn_drop.pressed.connect(_debug_drop_item.bind("spada_corta"))
	row2.add_child(btn_drop)

	var btn_drop_unique := Button.new()
	btn_drop_unique.text = "Drop unico"
	btn_drop_unique.add_theme_font_size_override("font_size", 10)
	btn_drop_unique.pressed.connect(_debug_drop_item.bind("spada_dell_alba"))
	row2.add_child(btn_drop_unique)

	var btn_open_screen := Button.new()
	btn_open_screen.text = "Apri LootScreen"
	btn_open_screen.add_theme_font_size_override("font_size", 10)
	btn_open_screen.pressed.connect(_debug_open_loot_screen)
	row2.add_child(btn_open_screen)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	body.add_child(row3)

	var btn_id_test := Button.new()
	btn_id_test.text = "Test identificazione"
	btn_id_test.add_theme_font_size_override("font_size", 10)
	btn_id_test.pressed.connect(_debug_identify_test)
	row3.add_child(btn_id_test)

	var btn_reload := Button.new()
	btn_reload.text = "Invalida cache loot"
	btn_reload.add_theme_font_size_override("font_size", 10)
	btn_reload.pressed.connect(_debug_invalidate_loot_cache)
	row3.add_child(btn_reload)


func _debug_loot_enemy() -> void:
	var lres: Node = get_node_or_null("/root/LootResolver")
	if not lres: print("[LootTools] LootResolver non caricato"); return
	var ctx: Dictionary = {
		"source_type": "enemy", "loot_profile": "humanoid_low",
		"player_class": str(GameState.current_class), "player_level": GameState.level, "floor": 1,
	}
	var drops: Array = lres.call("resolve", ctx)
	print("[LootTools] enemy drops (%d):" % drops.size())
	for d: Variant in drops: print("  ", d)


func _debug_loot_chest() -> void:
	var lres: Node = get_node_or_null("/root/LootResolver")
	if not lres: print("[LootTools] LootResolver non caricato"); return
	for variant: String in ["comune", "ricca", "abbondante", "boss", "segreto"]:
		var ctx: Dictionary = {
			"source_type": "chest", "chest_variant": variant,
			"player_class": str(GameState.current_class), "player_level": GameState.level, "floor": 1,
		}
		var drops: Array = lres.call("resolve", ctx)
		print("[LootTools] chest[%s] drops (%d):" % [variant, drops.size()])
		for d: Variant in drops: print("  ", d)


func _debug_loot_ground() -> void:
	var lres: Node = get_node_or_null("/root/LootResolver")
	if not lres: print("[LootTools] LootResolver non caricato"); return
	var ctx: Dictionary = {
		"source_type": "ground",
		"player_class": str(GameState.current_class), "player_level": GameState.level, "floor": 1,
	}
	var drops: Array = lres.call("resolve", ctx)
	print("[LootTools] ground drops (%d):" % drops.size())
	for d: Variant in drops: print("  ", d)


func _debug_drop_item(base_id: String) -> void:
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	if not igen: print("[LootTools] ItemGenerator non caricato"); return
	var instance: Dictionary = igen.call("drop", base_id, GameState.level, null, 0)
	print("[LootTools] drop '%s': %s" % [base_id, instance])
	if not bool(instance.get("identified", false)):
		var identified: Dictionary = igen.call("identify", instance, GameState.level)
		print("[LootTools] identified: %s" % identified)
		print("[LootTools] stats: %s" % igen.call("resolve_stats", identified, GameState.level))


func _debug_identify_test() -> void:
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	if not igen: print("[LootTools] ItemGenerator non caricato"); return
	var instance: Dictionary = igen.call("drop", "spada_corta", 15, null, 2)
	instance["quality"] = "raro"
	print("[LootTools] seed: %d" % int(instance.get("affix_seed", 0)))
	var id1: Dictionary = igen.call("identify", instance.duplicate(true), 15)
	var id2: Dictionary = igen.call("identify", instance.duplicate(true), 15)
	var match_result: bool = str(id1.get("affixes")) == str(id2.get("affixes"))
	print("[LootTools] identify idempotente: %s" % ("SI ✓" if match_result else "NO ✗"))
	print("[LootTools]   pass1 affissi: %s  name: %s" % [id1.get("affixes"), id1.get("name")])
	print("[LootTools]   pass2 affissi: %s  name: %s" % [id2.get("affixes"), id2.get("name")])


func _debug_open_loot_screen() -> void:
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	if not igen: return
	var test_drops: Array = [
		igen.call("drop", "spada_corta",     GameState.level, null, 1),
		igen.call("drop", "armatura_cuoio",  GameState.level, null, 0),
		igen.call("drop", "anello_base",     GameState.level, null, 2),
		igen.call("drop", "pozione_piccola", GameState.level, null, 0),
		igen.call("drop", "spada_dell_alba", GameState.level, null, 0),
		{ "type": "gold", "amount": randi_range(5, 50) },
	]
	EventBus.loot_screen_open.emit(test_drops, "Debug Loot Test")


func _debug_invalidate_loot_cache() -> void:
	var ltdb: Node = get_node_or_null("/root/LootTableDB")
	if ltdb:
		ltdb.call("invalidate_cache")
		print("[LootTools] LootTableDB cache invalidata")


func _update_switcher() -> void:
	if not is_instance_valid(_switcher_current_lbl): return
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs:
		_switcher_current_lbl.text = "Nessuna partita in corso"
		return
	var rt: Node        = get_node_or_null("/root/ClassRuntime")
	var current: String = str(gs.get("current_class"))
	var has_sp: bool    = rt != null and rt.get("_active_special") != null
	_switcher_current_lbl.text = "Attiva: %s  |  special: %s" % [
		current, "caricata" if has_sp else "non implementata"
	]


# ── Validatori JSON ───────────────────────────────────────────────────────────

func _build_validation_tools(parent: VBoxContainer) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var header := Button.new()
	header.text = "▼ Validatori JSON"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	header.add_theme_font_size_override("font_size", 11)
	wrapper.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	wrapper.add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼ " if body.visible else "► ") + "Validatori JSON"
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	for label: String in VALIDATOR_PATHS.keys():
		var btn := Button.new()
		btn.text = label
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_run_single_validator.bind(VALIDATOR_PATHS[label], label))
		row.add_child(btn)

	var btn_all := Button.new()
	btn_all.text = "Tutti"
	btn_all.focus_mode = Control.FOCUS_NONE
	btn_all.add_theme_font_size_override("font_size", 10)
	var style_all := StyleBoxFlat.new()
	style_all.bg_color = Color(0.20, 0.45, 0.20)
	style_all.set_corner_radius_all(3)
	style_all.content_margin_left = 6.0; style_all.content_margin_right  = 6.0
	style_all.content_margin_top  = 2.0; style_all.content_margin_bottom = 2.0
	btn_all.add_theme_stylebox_override("normal", style_all)
	btn_all.pressed.connect(_run_all_validators_debug)
	row.add_child(btn_all)

	_val_result_lbl = RichTextLabel.new()
	_val_result_lbl.bbcode_enabled    = true
	_val_result_lbl.fit_content       = true
	_val_result_lbl.scroll_active     = false
	_val_result_lbl.add_theme_font_size_override("normal_font_size", 10)
	_val_result_lbl.text = "[color=#666666]Premi un pulsante per eseguire la validazione.[/color]"
	body.add_child(_val_result_lbl)


func _run_single_validator(script_path: String, _label: String) -> void:
	var v: RefCounted = load(script_path).new()
	var r: Dictionary = v.call("run")
	_print_val_result(r)
	_show_val_results([r])


func _run_all_validators_debug() -> void:
	var results: Array = []
	print("\n╔══════════════════════════════════════╗")
	print("║        VALIDAZIONE JSON — TUTTI      ║")
	print("╚══════════════════════════════════════╝")
	for path: String in VALIDATOR_PATHS.values():
		var v: RefCounted = load(path).new()
		var r: Dictionary = v.call("run")
		results.append(r)
		_print_val_result(r)
	_show_val_results(results)
	var grand_err:  int = results.reduce(func(acc, r): return acc + (r["errors"]   as Array).size(), 0)
	var grand_warn: int = results.reduce(func(acc, r): return acc + (r["warnings"] as Array).size(), 0)
	print("══════════════════════════════════════════")
	if grand_err == 0 and grand_warn == 0:
		print("✓  Tutti i dati validi — nessun problema trovato.")
	else:
		print("TOTALE: %d errori, %d warning" % [grand_err, grand_warn])
	print("══════════════════════════════════════════\n")


func _print_val_result(r: Dictionary) -> void:
	var errors:   Array = r["errors"]   as Array
	var warnings: Array = r["warnings"] as Array
	var title: String   = str(r["title"])
	var checked: int    = int(r["checked"])
	var unit: String    = str(r.get("unit", "item"))
	var bar: String     = "─".repeat(42)
	print("\n┌%s┐" % bar)
	print("│  %-38s  │" % ("Validatore: " + title))
	print("│  %-38s  │" % ("Controllati: %d %s" % [checked, unit]))
	print("└%s┘" % bar)
	if errors.is_empty() and warnings.is_empty():
		print("  ✓  OK — nessun problema trovato.")
		return
	if not errors.is_empty():
		print("  ERRORI (%d):" % errors.size())
		for e: Variant in errors: print("    [ERR]  %s" % str(e))
	if not warnings.is_empty():
		print("  WARNING (%d):" % warnings.size())
		for w: Variant in warnings: print("    [WARN] %s" % str(w))


func _show_val_results(results: Array) -> void:
	if not is_instance_valid(_val_result_lbl): return
	var out: String = ""
	var grand_err: int  = 0
	var grand_warn: int = 0
	for r in results:
		var errors:   Array = r["errors"]   as Array
		var warnings: Array = r["warnings"] as Array
		grand_err  += errors.size()
		grand_warn += warnings.size()
		var header_col: String = "#44dd44" if errors.is_empty() else "#ff5555"
		out += "[color=%s]%s[/color]  [color=#888888]%d %s[/color]" % [
			header_col, str(r["title"]), int(r["checked"]), str(r.get("unit", "item"))
		]
		if errors.is_empty() and warnings.is_empty():
			out += "  [color=#44dd44]OK[/color]"
		else:
			if not errors.is_empty():   out += "  [color=#ff5555]%d ERR[/color]"   % errors.size()
			if not warnings.is_empty(): out += "  [color=#ffaa44]%d WARN[/color]" % warnings.size()
		out += "\n"
		for e: Variant in errors:   out += "  [color=#ff7777]• %s[/color]\n"  % str(e)
		for w: Variant in warnings: out += "  [color=#ffcc66]△ %s[/color]\n" % str(w)
	if results.size() > 1:
		var summary_col: String = "#44dd44" if grand_err == 0 else "#ff5555"
		out += "[color=%s]─── Totale: %d errori, %d warning ───[/color]" % [
			summary_col, grand_err, grand_warn
		]
	_val_result_lbl.text = out.strip_edges()


# ── FactionDB ─────────────────────────────────────────────────────────────────

func _update_faction_db() -> void:
	var s: DebugSection = get_section("faction_db")
	if not s: return
	var reg: Node = get_node_or_null("/root/FactionRegistry")
	if not reg:
		s.update(["FactionRegistry: non caricato"])
		return
	var all: Array = reg.call("get_all_factions")
	var counts: Dictionary = {}
	for data: Dictionary in all:
		var t: String = str(data.get("type", "?"))
		counts[t] = int(counts.get(t, 0)) + 1
	var lines: Array[String] = ["Totale fazioni: %d" % all.size()]
	var sorted_types: Array = counts.keys()
	sorted_types.sort()
	for t: String in sorted_types:
		lines.append("  %-12s %d" % [t + ":", int(counts[t])])
	s.update(lines)


func _build_faction_tools(parent: VBoxContainer) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var header := Button.new()
	header.text = "▼ FactionTools"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	header.add_theme_font_size_override("font_size", 11)
	wrapper.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	wrapper.add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼ " if body.visible else "► ") + "FactionTools"
	)

	var rep_lbl := Label.new()
	rep_lbl.text = "Rep attuale:"
	rep_lbl.add_theme_font_size_override("font_size", 10)
	body.add_child(rep_lbl)

	_faction_rep_rtl = RichTextLabel.new()
	_faction_rep_rtl.bbcode_enabled = true
	_faction_rep_rtl.fit_content   = true
	_faction_rep_rtl.scroll_active = false
	_faction_rep_rtl.add_theme_font_size_override("normal_font_size", 10)
	body.add_child(_faction_rep_rtl)

	body.add_child(HSeparator.new())

	var editor_lbl := Label.new()
	editor_lbl.text = "Editor reputazione:"
	editor_lbl.add_theme_font_size_override("font_size", 10)
	body.add_child(editor_lbl)

	var reg: Node = get_node_or_null("/root/FactionRegistry")
	_faction_rep_opt = OptionButton.new()
	_faction_rep_opt.focus_mode = Control.FOCUS_NONE
	_faction_rep_opt.add_theme_font_size_override("font_size", 10)
	if reg:
		var all: Array = reg.call("get_all_factions")
		all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("id", "")) < str(b.get("id", ""))
		)
		for data: Dictionary in all:
			_faction_rep_opt.add_item(str(data.get("id", "")))
	body.add_child(_faction_rep_opt)

	var delta_row := HBoxContainer.new()
	delta_row.add_theme_constant_override("separation", 4)
	body.add_child(delta_row)

	for d: int in [-50, -25, -10, 10, 25, 50]:
		var btn := Button.new()
		btn.text = "%+d" % d
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 10)
		var bg: Color = Color(0.55, 0.18, 0.18) if d < 0 else Color(0.18, 0.45, 0.18)
		var st := StyleBoxFlat.new()
		st.bg_color = bg
		st.set_corner_radius_all(3)
		st.content_margin_left = 5.0; st.content_margin_right  = 5.0
		st.content_margin_top  = 2.0; st.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("normal", st)
		btn.pressed.connect(_do_rep_delta.bind(d))
		delta_row.add_child(btn)

	var prop_row := HBoxContainer.new()
	prop_row.add_theme_constant_override("separation", 6)
	body.add_child(prop_row)

	_faction_propagate_cb = CheckButton.new()
	_faction_propagate_cb.text = "Propagazione"
	_faction_propagate_cb.button_pressed = true
	_faction_propagate_cb.focus_mode = Control.FOCUS_NONE
	_faction_propagate_cb.add_theme_font_size_override("font_size", 10)
	prop_row.add_child(_faction_propagate_cb)

	var reset_btn := Button.new()
	reset_btn.text = "Reset All Rep"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.add_theme_font_size_override("font_size", 10)
	var rst := StyleBoxFlat.new()
	rst.bg_color = Color(0.55, 0.20, 0.10)
	rst.set_corner_radius_all(3)
	rst.content_margin_left = 6.0; rst.content_margin_right  = 6.0
	rst.content_margin_top  = 2.0; rst.content_margin_bottom = 2.0
	reset_btn.add_theme_stylebox_override("normal", rst)
	reset_btn.pressed.connect(_do_reset_all_rep)
	prop_row.add_child(reset_btn)

	body.add_child(HSeparator.new())

	var memb_lbl := Label.new()
	memb_lbl.text = "Membership:"
	memb_lbl.add_theme_font_size_override("font_size", 10)
	body.add_child(memb_lbl)

	_faction_member_rtl = RichTextLabel.new()
	_faction_member_rtl.bbcode_enabled = true
	_faction_member_rtl.fit_content   = true
	_faction_member_rtl.scroll_active = false
	_faction_member_rtl.add_theme_font_size_override("normal_font_size", 10)
	body.add_child(_faction_member_rtl)

	for fid: String in JOINABLE_FACTIONS:
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 4)
		body.add_child(frow)

		var flbl := Label.new()
		flbl.text = fid
		flbl.add_theme_font_size_override("font_size", 9)
		flbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frow.add_child(flbl)

		var join_btn := Button.new()
		join_btn.text = "Join"
		join_btn.focus_mode = Control.FOCUS_NONE
		join_btn.add_theme_font_size_override("font_size", 9)
		join_btn.pressed.connect(_do_faction_join.bind(fid))
		frow.add_child(join_btn)

		var leave_btn := Button.new()
		leave_btn.text = "Leave"
		leave_btn.focus_mode = Control.FOCUS_NONE
		leave_btn.add_theme_font_size_override("font_size", 9)
		leave_btn.pressed.connect(_do_faction_leave.bind(fid))
		frow.add_child(leave_btn)

		var adv_btn := Button.new()
		adv_btn.text = "+Rank"
		adv_btn.focus_mode = Control.FOCUS_NONE
		adv_btn.add_theme_font_size_override("font_size", 9)
		adv_btn.pressed.connect(_do_faction_advance.bind(fid))
		frow.add_child(adv_btn)


func _update_faction_rep_table() -> void:
	if not is_instance_valid(_faction_rep_rtl): return
	var reg: Node = get_node_or_null("/root/FactionRegistry")
	if not reg:
		_faction_rep_rtl.text = "[color=#666666]FactionRegistry non caricato[/color]"
		return
	var all: Array = reg.call("get_all_factions")
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	var out: String = ""
	for data: Dictionary in all:
		var fid: String   = str(data.get("id", ""))
		var rep: int      = FactionReputation.get_rep(fid)
		var state: String = FactionReputation.get_state_id(fid)
		var col: String   = str(STATE_HEX.get(state, "#aaaaaa"))
		var badges: String = ""
		if FactionMembership.is_member(fid):
			badges = " [color=#ffcc00]M[r%d][/color]" % FactionMembership.get_rank(fid)
		elif FactionMembership.is_supporter(fid):
			badges = " [color=#88aaff]S[/color]"
		out += "[color=%s]%-30s %4d[/color]%s\n" % [col, fid, rep, badges]
	_faction_rep_rtl.text = out.strip_edges()


func _update_faction_member_table() -> void:
	if not is_instance_valid(_faction_member_rtl): return
	var out: String = ""
	for fid: String in JOINABLE_FACTIONS:
		if FactionMembership.is_member(fid):
			out += "[color=#ffcc00]◆ %s  rango %d[/color]\n" % [fid, FactionMembership.get_rank(fid)]
		elif FactionMembership.is_supporter(fid):
			out += "[color=#88aaff]★ %s[/color]\n" % fid
		else:
			out += "[color=#555555]○ %s[/color]\n" % fid
	_faction_member_rtl.text = out.strip_edges()


func _do_rep_delta(d: int) -> void:
	if not is_instance_valid(_faction_rep_opt): return
	var fid: String = _faction_rep_opt.get_item_text(_faction_rep_opt.selected)
	if fid == "": return
	var propagate: bool = is_instance_valid(_faction_propagate_cb) and _faction_propagate_cb.button_pressed
	FactionReputation.add_rep(fid, d, "debug", propagate)
	_refresh()


func _do_reset_all_rep() -> void:
	FactionReputation.initialize_for_new_game()
	_refresh()


func _do_faction_join(fid: String) -> void:
	FactionMembership.join_faction(fid)
	_refresh()


func _do_faction_leave(fid: String) -> void:
	FactionMembership.leave_faction(fid)
	_refresh()


func _do_faction_advance(fid: String) -> void:
	FactionMembership.advance_rank(fid)
	_refresh()


# ── CrimeSystem ───────────────────────────────────────────────────────────────

func _update_crime() -> void:
	var s: DebugSection = get_section("crime")
	if not s: return
	var city_id: String = GameState.current_city_id
	var active: bool    = city_id != "" and CrimeSystem.is_crime_active(city_id)
	var record: Array   = CrimeSystem.get_criminal_record()
	var lines: Array[String] = [
		"current_city_id:  %s"  % (city_id if city_id != "" else "(nessuna)"),
		"crime_attivo:     %s"  % ("SÌ" if active else "no"),
		"witness_cached:   %s"  % str(CrimeSystem._witness_check_result),
		"guard_wave_timer: %d"  % CrimeSystem._guard_wave_timer,
		"record arresti:   %d"  % record.size(),
	]
	for entry: Variant in record:
		var e: Dictionary = entry as Dictionary
		lines.append("  • %s (turno %d)" % [str(e.get("city_name", e.get("city_id", "?"))), int(e.get("turn", 0))])
	s.update(lines)


func _build_crime_tools(parent: VBoxContainer) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var header := Button.new()
	header.text = "▼ CrimeTools"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))
	header.add_theme_font_size_override("font_size", 11)
	wrapper.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	wrapper.add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼ " if body.visible else "► ") + "CrimeTools"
	)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	body.add_child(row1)

	var btn_crime := Button.new()
	btn_crime.text = "Registra crimine"
	btn_crime.add_theme_font_size_override("font_size", 10)
	btn_crime.pressed.connect(func() -> void:
		var cid: String = GameState.current_city_id
		if cid != "": CrimeSystem.register_crime(cid)
		_refresh()
	)
	row1.add_child(btn_crime)

	var btn_arrest := Button.new()
	btn_arrest.text = "Arresta"
	btn_arrest.add_theme_font_size_override("font_size", 10)
	btn_arrest.pressed.connect(func() -> void:
		var cid: String = GameState.current_city_id
		if cid != "": CrimeSystem.arrest_player(cid)
		_refresh()
	)
	row1.add_child(btn_arrest)

	var btn_clear := Button.new()
	btn_clear.text = "Cancella crimine"
	btn_clear.add_theme_font_size_override("font_size", 10)
	btn_clear.pressed.connect(func() -> void:
		var cid: String = GameState.current_city_id
		if cid != "": CrimeSystem.clear_crime(cid)
		_refresh()
	)
	row1.add_child(btn_clear)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	body.add_child(row2)

	for count: int in [1, 3, 6]:
		var btn := Button.new()
		btn.text = "Spawn %d guardie" % count
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func() -> void:
			CrimeSystem.spawn_guards_debug(count)
			_refresh()
		)
		row2.add_child(btn)

	var btn_record := Button.new()
	btn_record.text = "Pulisci fedina"
	btn_record.add_theme_font_size_override("font_size", 10)
	btn_record.pressed.connect(func() -> void:
		GameState.criminal_record.clear()
		_refresh()
	)
	row2.add_child(btn_record)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	body.add_child(row3)

	var btn_witness := Button.new()
	btn_witness.text = "Check testimoni"
	btn_witness.add_theme_font_size_override("font_size", 10)
	btn_witness.pressed.connect(func() -> void:
		CrimeSystem.has_witnesses(GameState.player_position)
		_refresh()
	)
	row3.add_child(btn_witness)

	var btn_amuleto := Button.new()
	btn_amuleto.add_theme_font_size_override("font_size", 10)
	btn_amuleto.pressed.connect(func() -> void:
		if Equipment.is_equipped("amuleto_del_sangue"):
			Equipment.unequip("neck")
		else:
			GameState.equipped["neck"] = "amuleto_del_sangue"
			EventBus.equipment_changed.emit()
		_update_amuleto_btn(btn_amuleto)
		_refresh()
	)
	_update_amuleto_btn(btn_amuleto)
	row3.add_child(btn_amuleto)


func _update_amuleto_btn(btn: Button) -> void:
	btn.text = "Rimuovi amuleto" if Equipment.is_equipped("amuleto_del_sangue") else "Equip amuleto"


# ── Time System ───────────────────────────────────────────────────────────────

func _update_time_system() -> void:
	var s: DebugSection = get_section("time_system")
	if not s: return
	var tm: Node = get_node_or_null("/root/TimeManager")
	if not tm:
		s.update(["TimeManager: non caricato"])
		return
	var map: Node = null
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("get_current_map"):
		map = wm.call("get_current_map")
	var map_type: String = map.get("map_type") if map != null else "—"
	var lines: Array[String] = [
		"total_minutes: %d"      % GameState.total_minutes,
		"world_time:    %d  (%02d:%02d)" % [GameState.world_time, tm.call("get_hour"), tm.call("get_minute")],
		"slot:          %s"      % tm.call("get_slot"),
		"display:       %s"      % tm.call("format_time"),
		"abs_day:       %d"      % tm.call("get_absolute_day"),
		"data:          gg %d  mese %d  anno %d" % [tm.call("get_day_of_month"), int(tm.call("get_month_index")) + 1, tm.call("get_year")],
		"map_type:      %s"      % map_type,
		"action_costs:  M:%d A:%d I:%d W:%d" % [
			tm.call("get_action_cost", map_type, 0),
			tm.call("get_action_cost", map_type, 1),
			tm.call("get_action_cost", map_type, 2),
			tm.call("get_action_cost", map_type, 4),
		],
	]
	var wait_scr: Node = get_node_or_null("/root/Main/WaitScreen")
	if wait_scr != null:
		lines.append("wait_open:     %s" % str(wait_scr.visible))
		if wait_scr.visible:
			lines.append("wait_anim:     %s" % str(wait_scr.get("_animating")))
			lines.append("wait_target:   %d min" % int(wait_scr.get("_target_minutes")))
	var hud_lbl: Label = get_node_or_null("/root/Main/HUD/TimeLabel")
	lines.append("hud_time_label: %s" % (hud_lbl.text if hud_lbl != null else "NON TROVATA ⚠"))
	s.update(lines)


func _build_time_tools(parent: VBoxContainer) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var header := Button.new()
	header.text = "▼ TimeTools"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	header.add_theme_font_size_override("font_size", 11)
	wrapper.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	wrapper.add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼ " if body.visible else "► ") + "TimeTools"
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	for label_text: String in ["+1h", "+8h", "+1 giorno"]:
		var minutes: int = 60 if label_text == "+1h" else (480 if label_text == "+8h" else 1440)
		var btn := Button.new()
		btn.text = label_text
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func() -> void:
			var tm: Node = get_node_or_null("/root/TimeManager")
			if tm: tm.call("advance", minutes)
			_refresh()
		)
		row.add_child(btn)

	var btn_reset := Button.new()
	btn_reset.text = "Reset"
	btn_reset.add_theme_font_size_override("font_size", 10)
	btn_reset.pressed.connect(func() -> void:
		GameState.total_minutes = 480
		_refresh()
	)
	row.add_child(btn_reset)


# ── Needs System ──────────────────────────────────────────────────────────────

func _update_needs() -> void:
	var s: DebugSection = get_section("needs")
	if not s: return
	var nm: Node = get_node_or_null("/root/NeedsManager")
	var mods: Dictionary = GameState.needs_modifiers
	var lines: Array[String] = [
		"food:        %.1f  [%s]" % [GameState.food,       _need_state_label("food")],
		"water:       %.1f  [%s]" % [GameState.water,      _need_state_label("water")],
		"exhaustion:  %.1f  [%s]" % [GameState.exhaustion, _need_state_label("exhaustion")],
		"temperature: %.1f  zona %s" % [GameState.temperature, _temp_zone_label()],
	]
	var diseases: Array = GameState.active_diseases
	if diseases.is_empty():
		lines.append("diseases:    nessuna")
	else:
		lines.append("diseases:    %d attive" % diseases.size())
		for d: Variant in diseases:
			var e: Dictionary = d as Dictionary
			lines.append("  • %s  stage %d  (%d min)" % [
				str(e.get("id", "?")),
				int(e.get("stage_index", 0)),
				int(e.get("elapsed_minutes", 0)),
			])
	if mods.is_empty():
		lines.append("modifiers:   nessuno")
	else:
		for k: String in mods.keys():
			var v: Variant = mods[k]
			if v is float:
				lines.append("  %-26s %.3f" % [k + ":", float(v)])
			else:
				lines.append("  %-26s %s"   % [k + ":", str(v)])
	if nm:
		lines.append("acc food_zero:  %.1f" % nm.get("_food_zero_acc"))
		lines.append("acc water_zero: %.1f" % nm.get("_water_zero_acc"))
		lines.append("acc exh_dmg:    %.1f" % nm.get("_exh_dmg_acc"))
		lines.append("exh_count_90+:  %d"   % nm.get("_high_exhaustion_count"))
	s.update(lines)


func _need_state_label(need: String) -> String:
	match need:
		"food":
			if GameState.food <= 0.0:       return "DEPLETED"
			if GameState.food <= 24.0:      return "critical"
			if GameState.food <= 49.0:      return "warning"
		"water":
			if GameState.water <= 0.0:      return "DEPLETED"
			if GameState.water <= 24.0:     return "critical"
			if GameState.water <= 49.0:     return "warning"
		"exhaustion":
			if GameState.exhaustion >= 100.0: return "COLLASSO"
			if GameState.exhaustion >= 91.0:  return "grave"
			if GameState.exhaustion >= 76.0:  return "critical"
			if GameState.exhaustion >= 56.0:  return "moderato"
			if GameState.exhaustion >= 31.0:  return "warning"
	return "ok"


func _temp_zone_label() -> String:
	var t: float = GameState.temperature
	if t < -75.0:   return "3 cold (IPOTERMIA)"
	if t < -50.0:   return "2 cold (freddissimo)"
	if t < -25.0:   return "1 cold (freddo)"
	if t >  85.0:   return "3 hot (IPERTERMIA)"
	if t >  57.0:   return "3 hot (surriscaldamento)"
	if t >  29.0:   return "2 hot (caldissimo)"
	if t >  25.0:   return "1 hot (caldo)"
	return "0 (comodo)"


func _build_needs_tools(parent: VBoxContainer) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)

	var header := Button.new()
	header.text = "▼ NeedsTools"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	header.add_theme_font_size_override("font_size", 11)
	wrapper.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	wrapper.add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼ " if body.visible else "► ") + "NeedsTools"
	)

	# ── Toggle HUD / Reset ────────────────────────────────────────────────────
	var row0 := HBoxContainer.new()
	row0.add_theme_constant_override("separation", 6)
	body.add_child(row0)

	var toggle_btn := Button.new()
	toggle_btn.text = "Toggle HUD Bisogni"
	toggle_btn.add_theme_font_size_override("font_size", 10)
	toggle_btn.pressed.connect(func() -> void:
		var hud_node: Node = get_node_or_null("/root/Main/HUD")
		if hud_node and hud_node.has_method("toggle_needs_hud"):
			hud_node.call("toggle_needs_hud")
	)
	row0.add_child(toggle_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset tutti"
	reset_btn.add_theme_font_size_override("font_size", 10)
	reset_btn.pressed.connect(func() -> void:
		var nm: Node = get_node_or_null("/root/NeedsManager")
		if nm:
			nm.call("consume", { "food": 999.0, "water": 999.0 })
			GameState.exhaustion  = 0.0
			GameState.temperature = 0.0
			nm.call("rebuild_modifiers")
		_refresh()
	)
	row0.add_child(reset_btn)

	body.add_child(HSeparator.new())

	# ── Set food / water / exhaustion / temperature ────────────────────────
	for cfg: Dictionary in [
		{ "label": "Food",        "prop": "food",        "min": 0.0,    "max": 100.0,  "step": 1.0 },
		{ "label": "Water",       "prop": "water",       "min": 0.0,    "max": 100.0,  "step": 1.0 },
		{ "label": "Exhaustion",  "prop": "exhaustion",  "min": 0.0,    "max": 100.0,  "step": 1.0 },
		{ "label": "Temperature", "prop": "temperature", "min": -100.0, "max": 100.0,  "step": 5.0 },
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		body.add_child(row)

		var lbl := Label.new()
		lbl.text = str(cfg["label"]) + ":"
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = float(cfg["min"])
		spin.max_value = float(cfg["max"])
		spin.step      = float(cfg["step"])
		spin.value     = float(GameState.get(str(cfg["prop"])))
		spin.custom_minimum_size = Vector2(80, 0)
		spin.add_theme_font_size_override("font_size", 10)
		row.add_child(spin)

		var prop: String = str(cfg["prop"])
		var btn := Button.new()
		btn.text = "Set"
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func() -> void:
			var nm: Node = get_node_or_null("/root/NeedsManager")
			GameState.set(prop, clampf(float(spin.value),
				float(cfg["min"]), float(cfg["max"])))
			if nm: nm.call("rebuild_modifiers")
			_refresh()
		)
		row.add_child(btn)

	body.add_child(HSeparator.new())

	# ── Tick N minuti ──────────────────────────────────────────────────────
	var tick_row := HBoxContainer.new()
	tick_row.add_theme_constant_override("separation", 4)
	body.add_child(tick_row)

	var tick_lbl := Label.new()
	tick_lbl.text = "Tick:"
	tick_lbl.add_theme_font_size_override("font_size", 10)
	tick_row.add_child(tick_lbl)

	var tick_spin := SpinBox.new()
	tick_spin.min_value = 1
	tick_spin.max_value = 1440
	tick_spin.value     = 60
	tick_spin.custom_minimum_size = Vector2(70, 0)
	tick_spin.add_theme_font_size_override("font_size", 10)
	tick_row.add_child(tick_spin)

	var tick_btn := Button.new()
	tick_btn.text = "min (needs only)"
	tick_btn.add_theme_font_size_override("font_size", 10)
	tick_btn.pressed.connect(func() -> void:
		var nm: Node = get_node_or_null("/root/NeedsManager")
		var wm: Node = get_node_or_null("/root/WorldManager")
		if nm:
			var map: Node = wm.call("get_current_map") if wm else null
			var map_type: String = map.get("map_type") if map else "building"
			nm.call("tick", int(tick_spin.value), { "map_type": map_type })
		_refresh()
	)
	tick_row.add_child(tick_btn)

	body.add_child(HSeparator.new())

	# ── Simula bioma (target temperatura) ─────────────────────────────────
	var biome_row := HBoxContainer.new()
	biome_row.add_theme_constant_override("separation", 4)
	body.add_child(biome_row)

	var biome_lbl := Label.new()
	biome_lbl.text = "Bioma:"
	biome_lbl.add_theme_font_size_override("font_size", 10)
	biome_row.add_child(biome_lbl)

	var biome_opt := OptionButton.new()
	biome_opt.add_theme_font_size_override("font_size", 10)
	var biome_targets: Dictionary = {
		"plain (0)": 0.0, "forest (-5)": -5.0, "dense_forest (-10)": -10.0,
		"coast (-15)": -15.0, "swamp (+30)": 30.0, "mountain (-40)": -40.0,
		"desert (+60)": 60.0, "mountain_dense (-55)": -55.0, "OFF": 0.0,
	}
	for bname: String in biome_targets.keys():
		biome_opt.add_item(bname)
	biome_row.add_child(biome_opt)

	var biome_btn := Button.new()
	biome_btn.text = "Set target"
	biome_btn.add_theme_font_size_override("font_size", 10)
	biome_btn.pressed.connect(func() -> void:
		var nm: Node = get_node_or_null("/root/NeedsManager")
		if nm:
			var bname: String = biome_opt.get_item_text(biome_opt.selected)
			nm.set("_debug_biome_target", float(biome_targets[bname]))
		_refresh()
	)
	biome_row.add_child(biome_btn)

	body.add_child(HSeparator.new())

	# ── Malattie ───────────────────────────────────────────────────────────
	var dis_row := HBoxContainer.new()
	dis_row.add_theme_constant_override("separation", 4)
	body.add_child(dis_row)

	var dis_opt := OptionButton.new()
	dis_opt.add_theme_font_size_override("font_size", 10)
	for did: String in [
			"malnutrizione", "disidratazione_grave", "ipotermia", "ipertermia",
			"insonnia_cronica", "avvelenamento", "veleno_paralizzante", "putrefazione",
			"febbre_infettiva", "setticemia", "morbo_oscuro", "morso_mannaro",
			"maledizione_vampirica", "corruzione_magica", "corruzione_abissale",
			"corruzione_del_sangue", "raffreddore", "influenza", "morbo_delle_paludi",
			"febbre_desertica", "febbre_necrotica", "spore_fungine", "miasma_sotterraneo",
			"sete_magica", "piaghe", "scorbuto", "anemia", "astenia",
			"shock_termico", "intossicazione_alcolica", "paranoia", "mal_di_viaggio"]:
		dis_opt.add_item(did)
	dis_row.add_child(dis_opt)

	var add_dis_btn := Button.new()
	add_dis_btn.text = "+ Aggiungi"
	add_dis_btn.add_theme_font_size_override("font_size", 10)
	add_dis_btn.pressed.connect(func() -> void:
		var nm: Node = get_node_or_null("/root/NeedsManager")
		if nm: nm.call("add_disease", dis_opt.get_item_text(dis_opt.selected))
		_refresh()
	)
	dis_row.add_child(add_dis_btn)

	var adv_dis_btn := Button.new()
	adv_dis_btn.text = "Avanza"
	adv_dis_btn.add_theme_font_size_override("font_size", 10)
	adv_dis_btn.pressed.connect(func() -> void:
		var did: String = dis_opt.get_item_text(dis_opt.selected)
		for d: Variant in GameState.active_diseases:
			var entry: Dictionary = d as Dictionary
			if str(entry.get("id", "")) == did:
				var def: Dictionary = DiseaseRegistry.get_def(did)
				var stage_max: int = (def.get("stages", []) as Array).size() - 1
				var cur: int = int(entry.get("stage_index", 0))
				if cur < stage_max:
					entry["stage_index"] = cur + 1
					entry["elapsed_minutes"] = 0.0
					var nm: Node = get_node_or_null("/root/NeedsManager")
					if nm: nm.call("rebuild_modifiers")
				break
		_refresh()
	)
	dis_row.add_child(adv_dis_btn)

	var cure_btn := Button.new()
	cure_btn.text = "Cura tutte"
	cure_btn.add_theme_font_size_override("font_size", 10)
	cure_btn.pressed.connect(func() -> void:
		var nm: Node = get_node_or_null("/root/NeedsManager")
		if nm: nm.call("cure_all_diseases")
		_refresh()
	)
	dis_row.add_child(cure_btn)

	body.add_child(HSeparator.new())

	# ── Simula azione combattimento ────────────────────────────────────────
	var combat_row := HBoxContainer.new()
	combat_row.add_theme_constant_override("separation", 4)
	body.add_child(combat_row)

	var combat_opt := OptionButton.new()
	combat_opt.add_theme_font_size_override("font_size", 10)
	for aname: String in ["attacco (+0.1 exh)", "colpo_pesante_subito (+0.2 exh)"]:
		combat_opt.add_item(aname)
	combat_row.add_child(combat_opt)

	var combat_btn := Button.new()
	combat_btn.text = "Simula"
	combat_btn.add_theme_font_size_override("font_size", 10)
	combat_btn.pressed.connect(func() -> void:
		var nm2: Node = get_node_or_null("/root/NeedsManager")
		if nm2:
			var gain: float = 0.1 if combat_opt.selected == 0 else 0.2
			nm2.call("consume", {"exhaustion": gain})
		_refresh()
	)
	combat_row.add_child(combat_btn)

	body.add_child(HSeparator.new())

	# ── Dai / Usa oggetto needs ────────────────────────────────────────────
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 4)
	body.add_child(item_row)

	var item_opt := OptionButton.new()
	item_opt.add_theme_font_size_override("font_size", 10)
	for iid: String in [
			"borraccia_acqua", "zuppa_calda", "falo_portatile", "panno_bagnato",
			"antidoto", "erbe_medicinali", "pane_fresco", "carne_essiccata",
			"zuppa_ossa", "birra_guerriero", "ambrosia", "acqua_fonte_sacra"]:
		item_opt.add_item(iid)
	item_row.add_child(item_opt)

	var give_btn := Button.new()
	give_btn.text = "Dai x3"
	give_btn.add_theme_font_size_override("font_size", 10)
	give_btn.pressed.connect(func() -> void:
		Inventory.add_item(item_opt.get_item_text(item_opt.selected), 3)
		_refresh()
	)
	item_row.add_child(give_btn)

	var use_item_btn := Button.new()
	use_item_btn.text = "Usa"
	use_item_btn.add_theme_font_size_override("font_size", 10)
	use_item_btn.pressed.connect(func() -> void:
		var iid: String = item_opt.get_item_text(item_opt.selected)
		if not Inventory.has_item(iid): Inventory.add_item(iid, 1, false)
		Inventory.use_item(iid)
		_refresh()
	)
	item_row.add_child(use_item_btn)

	body.add_child(HSeparator.new())

	# ── Riposa ────────────────────────────────────────────────────────────────
	var rest_row := HBoxContainer.new()
	rest_row.add_theme_constant_override("separation", 4)
	body.add_child(rest_row)

	var rest_lbl := Label.new()
	rest_lbl.text = "Riposa:"
	rest_lbl.add_theme_font_size_override("font_size", 10)
	rest_row.add_child(rest_lbl)

	var rest_opt := OptionButton.new()
	rest_opt.add_theme_font_size_override("font_size", 10)
	for rtype: String in ["save_point (exh −30)", "inn (exh=0 temp=0)", "camp (exh −50 temp=0)"]:
		rest_opt.add_item(rtype)
	rest_row.add_child(rest_opt)

	var rest_btn := Button.new()
	rest_btn.text = "Riposa"
	rest_btn.add_theme_font_size_override("font_size", 10)
	rest_btn.pressed.connect(func() -> void:
		var nm3: Node = get_node_or_null("/root/NeedsManager")
		if nm3:
			var rtypes: Array[String] = ["save_point", "inn", "camp"]
			nm3.call("rest", rtypes[rest_opt.selected])
		_refresh()
	)
	rest_row.add_child(rest_btn)
