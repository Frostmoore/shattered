extends Node

var world_name:     String = ""
var character_name: String = ""
var permadeath:     bool   = false

# ── World seed (set at generation, restored on load) ─────────────────────────
var world_seed:    int    = 0
var danger_rating: int    = 1
var budget_curve:  String = "rising"

var current_map_id:  String   = "overworld"
var player_position: Vector2i = Vector2i(5, 5)

# ── Attributi (modello non-cumulativo) ────────────────────────────────────────
# base_attributes: crescono con i level-up (via LevelSystem)
# class_bonus:     bonus fisso della classe corrente (sostituito, mai accumulato)
# effective_attributes: base + class_bonus, usati da tutto il gioco
var base_attributes: Dictionary = {
	"str": 5, "dex": 5, "int": 5, "vit": 5, "wil": 5
}
var class_bonus: Dictionary = {
	"str": 0, "dex": 0, "int": 0, "vit": 0, "wil": 0
}
var effective_attributes: Dictionary = {
	"str": 5, "dex": 5, "int": 5, "vit": 5, "wil": 5
}

var current_class: String     = "noob"
var run_milestones: Dictionary = {}
var permanent_allies: Array   = []   # [{type, display_name, hp, max_hp, atk_mult}]

var player_stats: Dictionary = {
	"hp": 25, "max_hp": 25, "mp": 20, "max_mp": 20,
	"stamina": 20, "max_stamina": 20, "attack": 4, "defense": 1, "gold": 0
}

var world_flags: Dictionary = {
	"intro_completed":        false,
	"dungeon_boss_defeated":  false,
	"village_quest_completed": false
}

var active_quests:    Array = []
var ready_quests:     Array = []
var completed_quests: Array = []
var inventory:        Array = []

var equipped: Dictionary = {
	"head": "", "body": "", "left_hand": "", "right_hand": "",
	"ring_1": "", "ring_2": "", "neck": "", "feet": "",
	"cloak": "", "trinket": "", "hands": ""
}

var quick_slots: Array = ["", "", ""]

var level: int = 1
var xp:    int = 0

var total_minutes: int = 480   # contatore assoluto, mai resettato

# ── Bisogni (Needs System) ────────────────────────────────────────────────────
var food:            float = 100.0   # 100 = sazio,    0 = affamato
var water:           float = 100.0   # 100 = idratato, 0 = assetato
var exhaustion:      float = 0.0     # 0 = riposato,   100 = collasso
var temperature:     float = 0.0     # 0 = comodo, <0 = freddo, >0 = caldo
var active_diseases: Array = []      # [{id, stage_index, elapsed_minutes}]
var needs_modifiers: Dictionary = {} # derivato da NeedsManager._update_modifiers()

var world_time: int:
	get: return total_minutes % 1440

var character_faction_rep:        Dictionary = {} # faction_id → int
var character_faction_membership: Dictionary = {} # faction_id → {rank, join_date}
var faction_passive_flags:        Dictionary = {} # derived from membership — recalculated on load
var current_location_faction_id:  String     = "" # signoria of the current city/village; cleared on leave
var current_city_id:              String     = "" # root city JSON id (stable across floors); "" outside cities
var crime_state:                  Dictionary = {} # {city_id: int} levels: 0=none 1=active 2=arrested; NOT saved
var criminal_record:              Array      = [] # [{city_id, city_name, turn}]; persisted in save
var known_faction_members:        Dictionary = {} # {faction_id: {npc_id: npc_name}}


func recalculate_effective_attributes() -> void:
	for attr: String in base_attributes:
		effective_attributes[attr] = int(base_attributes[attr]) + int(class_bonus.get(attr, 0))


func recalculate_derived_stats() -> void:
	recalculate_effective_attributes()
	var vit:   int = int(effective_attributes["vit"])
	var str_a: int = int(effective_attributes["str"])
	var dex:   int = int(effective_attributes["dex"])
	var int_a: int = int(effective_attributes["int"])
	var wil:   int = int(effective_attributes["wil"])

	var int_m: float = 1.0 + float(needs_modifiers.get("int_mult", 0.0))
	var wil_m: float = 1.0 + float(needs_modifiers.get("wil_mult", 0.0))
	player_stats["max_hp"]      = vit * 5
	player_stats["max_mp"]      = roundi((float(int_a) * int_m + float(wil) * wil_m) * 2.0)
	player_stats["max_stamina"] = (str_a + dex) * 2
	player_stats["attack"]      = 2 + int(str_a * 0.5)
	player_stats["defense"]     = int(vit * 0.25)

	player_stats["hp"]      = mini(int(player_stats["hp"]),      int(player_stats["max_hp"]))
	player_stats["mp"]      = mini(int(player_stats["mp"]),      int(player_stats["max_mp"]))
	player_stats["stamina"] = mini(int(player_stats["stamina"]), int(player_stats["max_stamina"]))


func apply_level_up_growth() -> Dictionary:
	var gains: Dictionary = {}
	var data: Dictionary = _get_class_data(current_class)
	var curve: Variant   = data.get("growth_curve", null)
	var idx: int         = level - 2  # level già incrementato; lvl 2 → idx 0
	if curve is Array and idx >= 0 and idx < (curve as Array).size():
		var entry: Variant = (curve as Array)[idx]
		if entry is Dictionary:
			for attr: String in base_attributes:
				var delta: int = int((entry as Dictionary).get(attr, 0))
				if delta != 0:
					base_attributes[attr] = int(base_attributes[attr]) + delta
					gains[attr] = delta
			return gains
	# Fallback: crescita piatta dalla growth dict
	var growth: Dictionary = _get_class_field(current_class, "growth")
	for attr: String in base_attributes:
		var delta: int = int(growth.get(attr, 1))
		if delta != 0:
			base_attributes[attr] = int(base_attributes[attr]) + delta
			gains[attr] = delta
	return gains


func apply_class(class_id: String) -> void:
	var data: Dictionary = _get_class_data(class_id)
	if data.is_empty():
		push_error("GameState.apply_class: classe non trovata: " + class_id)
		return
	current_class = class_id
	var bonus: Variant = data.get("respec_bonus", {})
	if bonus is Dictionary:
		for attr: String in class_bonus:
			class_bonus[attr] = int((bonus as Dictionary).get(attr, 0))
	recalculate_derived_stats()
	var runtime: Node = get_node_or_null("/root/ClassRuntime")
	if runtime:
		runtime.set_active_class(class_id)
	EventBus.player_stats_changed.emit()


# ── helpers per ClassRegistry (workaround finché l'editor non rileva l'autoload) ──

func _get_class_data(class_id: String) -> Dictionary:
	var reg: Node = get_node_or_null("/root/ClassRegistry")
	if not reg:
		return {}
	var result: Variant = reg.call("get_class_data", class_id)
	return result if result is Dictionary else {}


func _get_class_field(class_id: String, field: String) -> Dictionary:
	var data: Dictionary = _get_class_data(class_id)
	var val: Variant = data.get(field, {})
	return val if val is Dictionary else {}


func set_flag(flag_name: String, value: bool) -> void:
	world_flags[flag_name] = value
	EventBus.world_flag_changed.emit(flag_name, value)


func get_flag(flag_name: String) -> bool:
	return world_flags.get(flag_name, false)


func modify_gold(amount: int) -> void:
	player_stats["gold"] = int(player_stats["gold"]) + amount
	EventBus.inventory_changed.emit()
	if amount > 0:
		EventBus.notification_shown.emit(Notification.gold(amount))


func heal_player(amount: int) -> void:
	player_stats["hp"] = mini(int(player_stats["hp"]) + amount, int(player_stats["max_hp"]))
	EventBus.player_stats_changed.emit()


func get_crime_level(city_id: String) -> int:
	return int(crime_state.get(city_id, 0))


func set_crime_level(city_id: String, crime_level: int) -> void:
	if crime_level <= 0:
		crime_state.erase(city_id)
	else:
		crime_state[city_id] = crime_level


func add_arrest_to_record(city_id: String, city_name: String) -> void:
	criminal_record.append({"city_id": city_id, "city_name": city_name, "turn": run_milestones.get("turns", 0)})


func record_known_member(faction_id: String, npc_id: String, npc_name: String) -> void:
	if not known_faction_members.has(faction_id):
		known_faction_members[faction_id] = {}
	(known_faction_members[faction_id] as Dictionary)[npc_id] = npc_name


func damage_player(amount: int) -> void:
	player_stats["hp"] = maxi(0, int(player_stats["hp"]) - amount)
	EventBus.player_stats_changed.emit()
	if int(player_stats["hp"]) <= 0:
		EventBus.player_died.emit()
