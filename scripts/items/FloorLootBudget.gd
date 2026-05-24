class_name FloorLootBudget
extends RefCounted

# Per-floor sub-budget derived from a DungeonLootBudget.
# Controls how many drops are allowed from each source on this floor.

var dungeon_budget: DungeonLootBudget = null

var chest_equipment_slots:  int = 2
var enemy_equipment_slots:  int = 1
var ground_equipment_slots: int = 1

var _chest_equipment:  int = 0
var _enemy_equipment:  int = 0
var _ground_equipment: int = 0


# Factory: derives per-floor limits from the dungeon budget and floor index.
# floor_index is 0-based (floor 0 = first floor of dungeon).
static func for_floor(dungeon_budget: DungeonLootBudget, floor_index: int, tier: int) -> FloorLootBudget:
	var f := FloorLootBudget.new()
	f.dungeon_budget = dungeon_budget
	# Later floors get progressively better odds
	var bias: float = 1.0 + floor_index * 0.2
	f.chest_equipment_slots  = maxi(1, roundi(2 * bias))
	f.enemy_equipment_slots  = maxi(0, roundi((tier - 1) * 0.5 * bias))
	f.ground_equipment_slots = 0   # ground loot never gives equipment on its own
	return f


func chest_equipment_ok() -> bool:
	if dungeon_budget != null and not dungeon_budget.equipment_ok():
		return false
	return _chest_equipment < chest_equipment_slots


func enemy_equipment_ok() -> bool:
	if dungeon_budget != null and not dungeon_budget.equipment_ok():
		return false
	return _enemy_equipment < enemy_equipment_slots


func consume_equipment(source: String) -> void:
	match source:
		"chest":  _chest_equipment += 1
		"enemy":  _enemy_equipment += 1
		"ground": _ground_equipment += 1
	if dungeon_budget != null:
		dungeon_budget.consume_equipment()


func consume_consumable() -> void:
	if dungeon_budget != null:
		dungeon_budget.consume_consumable()


func unique_ok() -> bool:
	return dungeon_budget == null or dungeon_budget.unique_ok()


func consume_unique() -> void:
	if dungeon_budget != null:
		dungeon_budget.consume_unique()
