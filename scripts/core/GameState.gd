extends Node

var world_name:     String = ""
var character_name: String = ""
var permadeath:     bool   = false

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
	"helm": "", "armor": "", "left_hand": "", "right_hand": "",
	"ring_1": "", "ring_2": "", "amulet": "", "boots": "",
	"cloak": "", "accessory": ""
}

var quick_slots: Array = ["", "", ""]

var level: int = 1
var xp:    int = 0


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

	player_stats["max_hp"]      = vit * 5
	player_stats["max_mp"]      = (int_a + wil) * 2
	player_stats["max_stamina"] = (str_a + dex) * 2
	player_stats["attack"]      = 2 + int(str_a * 0.5)
	player_stats["defense"]     = int(vit * 0.25)

	player_stats["hp"]      = mini(int(player_stats["hp"]),      int(player_stats["max_hp"]))
	player_stats["mp"]      = mini(int(player_stats["mp"]),      int(player_stats["max_mp"]))
	player_stats["stamina"] = mini(int(player_stats["stamina"]), int(player_stats["max_stamina"]))


func apply_level_up_growth() -> void:
	var growth: Dictionary = _get_class_field(current_class, "growth")
	for attr: String in base_attributes:
		base_attributes[attr] = int(base_attributes[attr]) + int(growth.get(attr, 1))


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


func damage_player(amount: int) -> void:
	player_stats["hp"] = maxi(0, int(player_stats["hp"]) - amount)
	EventBus.player_stats_changed.emit()
	if int(player_stats["hp"]) <= 0:
		EventBus.player_died.emit()
