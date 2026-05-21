extends Node

const SAVE_PATH := "user://saves/global_milestones.json"
const TEMP_PATH := "user://saves/global_milestones.tmp"

const _DEFAULTS: Dictionary = {
	"kills_total":                 0,
	"kills_boss":                  0,
	"dungeons_completed":          0,
	"dungeons_completed_no_death": 0,
	"deaths_total":                0,
	"damage_dealt_total":          0,
	"damage_taken_total":          0,
	"dungeon_floors_total":        0,
	"chests_opened":               0,
	"quests_completed":            0,
	"npcs_spoken":                 0,
	"consumables_used":            0,
	"save_points_used":            0,
	"class_respec_count":          0,
	"completed_classes":           [],
	"unlocked_classes":            ["noob"],
}

var _data: Dictionary = {}


func _ready() -> void:
	_load()
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.damage_taken.connect(_on_damage_taken)
	EventBus.chest_opened.connect(_on_chest_opened)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.save_point_used.connect(_on_save_point_used)
	EventBus.game_completed.connect(_on_game_completed)


# ── API pubblica ──────────────────────────────────────────────────────────────

func increment(key: String, amount: int = 1) -> void:
	if not _data.has(key):
		_data[key] = 0
	_data[key] = int(_data[key]) + amount
	_save()
	EventBus.milestone_updated.emit(key, int(_data[key]))


func get_value(key: String) -> int:
	return int(_data.get(key, 0))


func unlock_class(class_id: String) -> void:
	var unlocked: Array = _data.get("unlocked_classes", []) as Array
	if not unlocked.has(class_id):
		unlocked.append(class_id)
		_data["unlocked_classes"] = unlocked
		_save()


func is_class_unlocked(class_id: String) -> bool:
	return (_data.get("unlocked_classes", []) as Array).has(class_id)


func complete_class(class_id: String) -> void:
	var completed: Array = _data.get("completed_classes", []) as Array
	if not completed.has(class_id):
		completed.append(class_id)
		_data["completed_classes"] = completed
		_save()


func is_class_completed(class_id: String) -> bool:
	return (_data.get("completed_classes", []) as Array).has(class_id)


func get_unlocked_classes() -> Array:
	return (_data.get("unlocked_classes", ["noob"]) as Array).duplicate()


func get_completed_classes() -> Array:
	return (_data.get("completed_classes", []) as Array).duplicate()


func get_all_data() -> Dictionary:
	return _data.duplicate(true)


# ── Connessioni EventBus ──────────────────────────────────────────────────────

func _on_enemy_died(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	increment("kills_total")
	GameState.run_milestones["kills_total"] = int(GameState.run_milestones.get("kills_total", 0)) + 1
	if bool(enemy.get("is_boss")):
		increment("kills_boss")
		GameState.run_milestones["kills_boss"] = int(GameState.run_milestones.get("kills_boss", 0)) + 1


func _on_player_died() -> void:
	increment("deaths_total")
	GameState.run_milestones = {}


func _on_map_changed(_map_id: String) -> void:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if not wm:
		return
	var map: Node = wm.call("get_current_map")
	if map == null:
		return
	if str(map.get("map_type")) == "dungeon":
		increment("dungeon_floors_total")
		GameState.run_milestones["dungeon_floors_total"] = int(GameState.run_milestones.get("dungeon_floors_total", 0)) + 1


func _on_damage_dealt(amount: int, _source: String) -> void:
	increment("damage_dealt_total", amount)
	GameState.run_milestones["damage_dealt_total"] = int(GameState.run_milestones.get("damage_dealt_total", 0)) + amount


func _on_damage_taken(amount: int) -> void:
	increment("damage_taken_total", amount)
	GameState.run_milestones["damage_taken_total"] = int(GameState.run_milestones.get("damage_taken_total", 0)) + amount


func _on_chest_opened() -> void:
	increment("chests_opened")
	GameState.run_milestones["chests_opened"] = int(GameState.run_milestones.get("chests_opened", 0)) + 1


func _on_quest_completed(_quest_id: String) -> void:
	increment("quests_completed")
	GameState.run_milestones["quests_completed"] = int(GameState.run_milestones.get("quests_completed", 0)) + 1


func _on_save_point_used() -> void:
	increment("save_points_used")


func _on_game_completed(class_id: String) -> void:
	complete_class(class_id)


# ── Save/Load atomico ─────────────────────────────────────────────────────────

func _load() -> void:
	_data = _DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	for key: String in (parsed as Dictionary):
		_data[key] = (parsed as Dictionary)[key]


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves/")
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if not file:
		push_error("GlobalMilestoneTracker: cannot write temp file")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
