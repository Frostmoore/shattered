extends CanvasLayer

const REFRESH_INTERVAL := 0.5
const BG_COLOR         := Color(0.0, 0.0, 0.0, 0.75)
const PANEL_COLOR      := Color(0.06, 0.06, 0.10, 0.97)
const BORDER_COLOR     := Color(0.25, 0.35, 0.55, 1.0)
const MARGIN           := 15
const KEY_EGRAVE       := 232  # 'è' — non esiste come costante in Godot 4.4

const TIER_COLORS: Array[Color] = [
	Color(0.35, 0.30, 0.22),   # Tier 0 — marrone (noob)
	Color(0.38, 0.38, 0.38),   # Tier 1 — grigio
	Color(0.16, 0.50, 0.26),   # Tier 2 — verde
	Color(0.13, 0.30, 0.60),   # Tier 3 — blu
	Color(0.40, 0.16, 0.56),   # Tier 4 — viola
	Color(0.70, 0.26, 0.10),   # Tier 5 — arancione
	Color(0.62, 0.52, 0.06),   # Tier 6 — oro
]

const VALIDATOR_PATHS := {
	"Items":        "res://scripts/tools/validators/validate_items.gd",
	"Affissi":      "res://scripts/tools/validators/validate_affixes.gd",
	"Loot Tables":  "res://scripts/tools/validators/validate_loot_tables.gd",
	"Classi":       "res://scripts/tools/validators/validate_classes.gd",
}

var _sections: Dictionary = {}
var _vbox:     VBoxContainer
var _timer:    Timer
var _switcher_current_lbl: Label   # aggiornata da _refresh()
var _val_result_lbl: RichTextLabel


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	layer   = 100
	visible = false
	_build_ui()
	_setup_timer()
	_add_section("sistema",       "Sistema")
	_add_section("class_db",      "ClassRegistry")
	_add_section("game_state",    "GameState")
	_add_section("class_picker",  "ClassPicker")
	_add_section("damage_pipe",   "DamagePipeline")
	_add_section("class_runtime", "ClassRuntime")
	_add_section("ability_tracker",  "AbilityUseTracker")
	_add_section("class_special",    "ClassSpecial")
	_add_section("status_effects",   "StatusEffects")
	_add_section("targeting",        "Targeting")
	_add_section("ally_manager",     "AllyManager")
	_add_section("druid_form",       "DruidForm")
	_add_section("milestones",       "Milestones")
	_add_section("respec",           "Respec")
	_add_section("loot_db",          "LootDB")
	_build_class_switcher()
	_build_loot_tools()
	_build_validation_tools()
	_refresh()


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = BG_COLOR
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left   = MARGIN
	panel.offset_right  = -MARGIN
	panel.offset_top    = MARGIN
	panel.offset_bottom = -MARGIN
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	var title_lbl := Label.new()
	title_lbl.text = "  DEBUG  —  premi È per chiudere"
	title_lbl.add_theme_color_override("font_color", Color(0.45, 0.70, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 11)
	outer.add_child(title_lbl)

	outer.add_child(HSeparator.new())

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

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_vbox)


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


# ── sezioni ──────────────────────────────────────────────────────────────────

func _add_section(key: String, title: String) -> DebugSection:
	var section := DebugSection.new()
	section.setup(title)
	_vbox.add_child(section)
	_sections[key] = section
	return section


func get_section(key: String) -> DebugSection:
	return _sections.get(key, null)


func has_section(key: String) -> bool:
	return _sections.has(key)


# ── refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
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
	_update_switcher()


func _update_sistema() -> void:
	var s: DebugSection = get_section("sistema")
	if not s:
		return
	var vi: Dictionary = Engine.get_version_info()
	var vp: Vector2    = get_viewport().get_visible_rect().size
	s.update([
		"FPS:          %d"    % Engine.get_frames_per_second(),
		"Godot:        %s"    % vi.get("string", "4.x"),
		"Build:        debug",
		"Piattaforma:  %s"    % OS.get_name(),
		"Risoluzione:  %dx%d" % [int(vp.x), int(vp.y)],
	])


func _update_class_registry() -> void:
	var s: DebugSection = get_section("class_db")
	if not s:
		return
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
	if not s:
		return
	var picker: Node = get_node_or_null("/root/Main/_class_picker")
	if not picker:
		# cerca come figlio di Main
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
	if gs:
		current = str(gs.get("current_class"))
	s.update([
		"Visibile: %s"         % str(picker.visible),
		"Classe attuale: %s"   % current,
		"Classi in griglia: %d" % picker.call("_get_card_count"),
	])


func _update_game_state() -> void:
	var s: DebugSection = get_section("game_state")
	if not s:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs:
		s.update(["GameState: non caricato"])
		return
	var ba: Dictionary = gs.get("base_attributes")
	var cb: Dictionary = gs.get("class_bonus")
	var ea: Dictionary = gs.get("effective_attributes")
	var lines: Array[String] = [
		"Classe:  %s"   % str(gs.get("current_class")),
		"Livello: %d"   % int(gs.get("level")),
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
	if not s:
		return
	var pipe: Node = get_node_or_null("/root/DamagePipeline")
	if not pipe:
		s.update(["DamagePipeline: non caricato"])
		return
	s.update(["DamagePipeline: OK", "Pronto a ricevere DamageContext"])


func _update_class_runtime() -> void:
	var s: DebugSection = get_section("class_runtime")
	if not s:
		return
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if not rt:
		s.update(["ClassRuntime: non caricato"])
		return
	var counters: Dictionary = rt.get("hook_counters")
	var active_id: String    = str(rt.call("get_active_special_id"))
	var has_special: bool    = rt.get("_active_special") != null
	s.update([
		"Classe attiva: %s"      % active_id,
		"Special caricata: %s"   % ("sì" if has_special else "no (planned)"),
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
	if not s:
		return
	var rt: Node = get_node_or_null("/root/ClassRuntime")
	if not rt:
		s.update(["ClassRuntime: non caricato"])
		return
	var tracker: Object = rt.call("get_tracker")
	if not tracker:
		s.update(["Tracker: non attivo (classe senza limite)"])
		return
	s.update([
		"Descrizione: %s"       % str(tracker.call("describe")),
		"Può usare:   %s"       % ("sì" if bool(tracker.call("can_use")) else "NO"),
		"Usi rimasti: %d"       % int(tracker.call("get_uses_remaining")),
		"Cooldown:    %dt"      % int(tracker.call("get_cooldown_remaining")),
	])


func _update_class_special() -> void:
	var s: DebugSection = get_section("class_special")
	if not s:
		return
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
		# Stato interno specifico per classe
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
				var tm: Node = get_node_or_null("/root/TurnManager")
				var in_combat: bool = tm != null and bool(tm.get("is_active"))
				lines.append("In combattimento: %s" % ("sì → ATK ×1.4" if in_combat else "no"))
				lines.append("Oggetti bloccati: %s" % ("SÌ" if in_combat else "no"))
			"SentinelGuard":
				var stacks: int = int(special.get("_guard_stacks"))
				lines.append("Guard stacks: %d/%d → DEF ×%d" % [stacks, 3, stacks + 1])
	s.update(lines)


func _update_status_effects() -> void:
	var s: DebugSection = get_section("status_effects")
	if not s:
		return
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
		if effects.is_empty():
			continue
		# Tenta di risolvere il nome dell'entità dall'instance_id
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
	if not s:
		return
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
		"Overlay attivo: %s" % ("SÌ" if active else "no"),
		"Player in attesa: %s" % ("sì" if (player != null and is_instance_valid(player)) else "no"),
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
	if not s:
		return
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
	if not s:
		return
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
	if not s:
		return
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
		"kills_total:      %d" % int(data.get("kills_total", 0)),
		"kills_boss:       %d" % int(data.get("kills_boss", 0)),
		"deaths_total:     %d" % int(data.get("deaths_total", 0)),
		"dungeon_floors:   %d" % int(data.get("dungeon_floors_total", 0)),
		"chests_opened:    %d" % int(data.get("chests_opened", 0)),
		"save_points:      %d" % int(data.get("save_points_used", 0)),
		"dmg_dealt:        %d" % int(data.get("damage_dealt_total", 0)),
		"dmg_taken:        %d" % int(data.get("damage_taken_total", 0)),
		"──────────────────",
		"Run corrente:",
		"  kills:     %d" % int(GameState.run_milestones.get("kills_total", 0)),
		"  floors:    %d" % int(GameState.run_milestones.get("dungeon_floors_total", 0)),
		"  dmg dealt: %d" % int(GameState.run_milestones.get("damage_dealt_total", 0)),
	]
	s.update(lines)


func _update_respec() -> void:
	var s: DebugSection = get_section("respec")
	if not s:
		return
	var svc: Node = get_node_or_null("/root/ClassRespecService")
	var gmt: Node = get_node_or_null("/root/GlobalMilestoneTracker")
	var gs: Node  = get_node_or_null("/root/GameState")
	if not svc:
		s.update(["ClassRespecService: non caricato"])
		return
	var respec_count: int = gmt.call("get_value", "class_respec_count") if gmt else 0
	var current: String = str(gs.get("current_class")) if gs else "—"
	var ba: Dictionary = gs.get("base_attributes") if gs else {}
	var cb: Dictionary = gs.get("class_bonus")     if gs else {}
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

func _build_class_switcher() -> void:
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		return

	# Contenitore collassabile (stessa logica di DebugSection, ma con pulsanti)
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	_vbox.add_child(wrapper)

	# Header collassabile
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

	# Riga stato corrente
	_switcher_current_lbl = Label.new()
	_switcher_current_lbl.add_theme_font_size_override("font_size", 10)
	_switcher_current_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	body.add_child(_switcher_current_lbl)

	body.add_child(HSeparator.new())

	# Pulsanti per tier
	var all_classes: Array[Dictionary] = reg.call("get_all")
	for tier: int in range(0, 7):
		var tier_classes: Array = all_classes.filter(
			func(d: Dictionary) -> bool: return int(d.get("tier", 0)) == tier
		)
		if tier_classes.is_empty():
			continue

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
			var class_id: String = str(data.get("id", ""))
			var class_name_str: String = str(data.get("name", class_id))
			var is_impl: bool = str((data.get("implementation", {}) as Dictionary) \
				.get("status", "")) == "implemented"

			var btn := Button.new()
			btn.text = class_name_str
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 9)
			btn.tooltip_text = "[Tier %d]  %s%s" % [
				tier,
				class_id,
				"" if is_impl else "  (planned)"
			]

			# Colore sfondo per tier, più scuro se non implementata
			var bg_col: Color = TIER_COLORS[tier] if is_impl else TIER_COLORS[tier].darkened(0.5)
			var style_btn := StyleBoxFlat.new()
			style_btn.bg_color = bg_col
			style_btn.set_corner_radius_all(3)
			style_btn.content_margin_left  = 6.0
			style_btn.content_margin_right = 6.0
			style_btn.content_margin_top   = 2.0
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
	if GameState.level >= 100:
		return
	GameState.level += 1
	var ls: Node = get_node_or_null("/root/LevelSystem")
	if ls:
		ls.call("_apply_level_up")
	_refresh()


func _btn_hover_style(base: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = base.lightened(0.25)
	s.set_corner_radius_all(3)
	s.content_margin_left = 6.0; s.content_margin_right = 6.0
	s.content_margin_top  = 2.0; s.content_margin_bottom = 2.0
	return s


func _btn_pressed_style(base: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = base.darkened(0.2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 6.0; s.content_margin_right = 6.0
	s.content_margin_top  = 2.0; s.content_margin_bottom = 2.0
	return s


func _do_class_switch(class_id: String) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs:
		return
	if str(gs.get("character_name")) == "":
		# Nessuna partita in corso — aggiorna solo ClassRuntime (utile per debug)
		var rt: Node = get_node_or_null("/root/ClassRuntime")
		if rt:
			rt.call("set_active_class", class_id)
		return
	gs.call("apply_class", class_id)
	# Forza aggiornamento immediato del debug screen
	_refresh()


func _update_loot_db() -> void:
	var s: DebugSection = get_section("loot_db")
	if not s:
		return
	var idb: Node  = get_node_or_null("/root/ItemDB")
	var iadb: Node = get_node_or_null("/root/ItemAffixDB")
	var ltdb: Node = get_node_or_null("/root/LootTableDB")
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	var lres: Node = get_node_or_null("/root/LootResolver")
	var lines: Array[String] = [
		"ItemDB:        %s  (%d item)"   % [("OK" if idb  else "NON CARICATO"), (idb.get("_items")  as Dictionary).size() if idb  else 0],
		"ItemAffixDB:   %s  (%d affissi)"% [("OK" if iadb else "NON CARICATO"), (iadb.get("_affixes") as Dictionary).size() if iadb else 0],
		"LootTableDB:   %s  (%d cache)"  % [("OK" if ltdb else "NON CARICATO"), (ltdb.get("_cache")  as Dictionary).size() if ltdb else 0],
		"ItemGenerator: %s"              %  ("OK" if igen else "NON CARICATO"),
		"LootResolver:  %s"              %  ("OK" if lres else "NON CARICATO"),
	]
	s.update(lines)


func _build_loot_tools() -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	_vbox.add_child(wrapper)

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

	# Row 1: resolve buttons
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

	# Row 2: ItemGenerator tests
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

	# Row 3: identify test
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
	if not lres:
		print("[LootTools] LootResolver non caricato")
		return
	var ctx: Dictionary = {
		"source_type": "enemy", "loot_profile": "humanoid_low",
		"player_class": str(GameState.current_class), "player_level": GameState.level, "floor": 1,
	}
	var drops: Array = lres.call("resolve", ctx)
	print("[LootTools] enemy drops (%d):" % drops.size())
	for d: Variant in drops:
		print("  ", d)


func _debug_loot_chest() -> void:
	var lres: Node = get_node_or_null("/root/LootResolver")
	if not lres:
		print("[LootTools] LootResolver non caricato")
		return
	for variant: String in ["comune", "ricca", "abbondante", "boss", "segreto"]:
		var ctx: Dictionary = {
			"source_type": "chest", "chest_variant": variant,
			"player_class": str(GameState.current_class), "player_level": GameState.level, "floor": 1,
		}
		var drops: Array = lres.call("resolve", ctx)
		print("[LootTools] chest[%s] drops (%d):" % [variant, drops.size()])
		for d: Variant in drops:
			print("  ", d)


func _debug_loot_ground() -> void:
	var lres: Node = get_node_or_null("/root/LootResolver")
	if not lres:
		print("[LootTools] LootResolver non caricato")
		return
	var ctx: Dictionary = {
		"source_type": "ground",
		"player_class": str(GameState.current_class), "player_level": GameState.level, "floor": 1,
	}
	var drops: Array = lres.call("resolve", ctx)
	print("[LootTools] ground drops (%d):" % drops.size())
	for d: Variant in drops:
		print("  ", d)


func _debug_drop_item(base_id: String) -> void:
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	if not igen:
		print("[LootTools] ItemGenerator non caricato")
		return
	var instance: Dictionary = igen.call("drop", base_id, GameState.level, null, 0)
	print("[LootTools] drop '%s': %s" % [base_id, instance])
	if not bool(instance.get("identified", false)):
		var identified: Dictionary = igen.call("identify", instance, GameState.level)
		print("[LootTools] identified: %s" % identified)
		print("[LootTools] stats: %s" % igen.call("resolve_stats", identified, GameState.level))


func _debug_identify_test() -> void:
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	if not igen:
		print("[LootTools] ItemGenerator non caricato")
		return
	# Drop same item twice with same seed — verify same affixes
	var instance: Dictionary = igen.call("drop", "spada_corta", 15, null, 2)
	instance["quality"] = "raro"  # force raro for test
	print("[LootTools] seed: %d" % int(instance.get("affix_seed", 0)))
	var id1: Dictionary = igen.call("identify", instance.duplicate(true), 15)
	var id2: Dictionary = igen.call("identify", instance.duplicate(true), 15)
	var match_result: bool = str(id1.get("affixes")) == str(id2.get("affixes"))
	print("[LootTools] identify idempotente: %s" % ("SI ✓" if match_result else "NO ✗"))
	print("[LootTools]   pass1 affissi: %s  name: %s" % [id1.get("affixes"), id1.get("name")])
	print("[LootTools]   pass2 affissi: %s  name: %s" % [id2.get("affixes"), id2.get("name")])


func _debug_open_loot_screen() -> void:
	var igen: Node = get_node_or_null("/root/ItemGenerator")
	if not igen:
		return
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
	if not is_instance_valid(_switcher_current_lbl):
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs:
		_switcher_current_lbl.text = "Nessuna partita in corso"
		return
	var rt: Node        = get_node_or_null("/root/ClassRuntime")
	var current: String = str(gs.get("current_class"))
	var has_sp: bool    = rt != null and rt.get("_active_special") != null
	_switcher_current_lbl.text = "Attiva: %s  |  special: %s" % [
		current,
		"caricata" if has_sp else "non implementata"
	]


# ── Validatori JSON ───────────────────────────────────────────────────────────

func _build_validation_tools() -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	_vbox.add_child(wrapper)

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

	# Riga pulsanti
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
	style_all.content_margin_left = 6.0; style_all.content_margin_right = 6.0
	style_all.content_margin_top  = 2.0; style_all.content_margin_bottom = 2.0
	btn_all.add_theme_stylebox_override("normal", style_all)
	btn_all.pressed.connect(_run_all_validators_debug)
	row.add_child(btn_all)

	# Label risultati
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
	var grand_err: int  = results.reduce(func(acc, r): return acc + (r["errors"] as Array).size(), 0)
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
		for e: Variant in errors:
			print("    [ERR]  %s" % str(e))
	if not warnings.is_empty():
		print("  WARNING (%d):" % warnings.size())
		for w: Variant in warnings:
			print("    [WARN] %s" % str(w))


func _show_val_results(results: Array) -> void:
	if not is_instance_valid(_val_result_lbl):
		return
	var out: String = ""
	var grand_err: int = 0
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
			if not errors.is_empty():
				out += "  [color=#ff5555]%d ERR[/color]" % errors.size()
			if not warnings.is_empty():
				out += "  [color=#ffaa44]%d WARN[/color]" % warnings.size()
		out += "\n"
		for e: Variant in errors:
			out += "  [color=#ff7777]• %s[/color]\n" % str(e)
		for w: Variant in warnings:
			out += "  [color=#ffcc66]△ %s[/color]\n" % str(w)
	if results.size() > 1:
		var summary_col: String = "#44dd44" if grand_err == 0 else "#ff5555"
		out += "[color=%s]─── Totale: %d errori, %d warning ───[/color]" % [
			summary_col, grand_err, grand_warn
		]
	_val_result_lbl.text = out.strip_edges()
