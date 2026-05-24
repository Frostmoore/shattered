class_name DungeonLootBudget
extends RefCounted

# Per-dungeon loot caps. Instantiate once when entering a dungeon,
# pass via drop_context["budget"] to LootResolver on every resolve() call.
# Limits prevent degenerate all-equipment or all-empty runs.

var max_equipment:   int  = 6   # total equipment drops allowed in this dungeon
var max_consumables: int  = 20  # total consumable drops allowed
var max_unique:      int  = 1   # at most 1 unique per dungeon

var _equipment:   int  = 0
var _consumables: int  = 0
var _unique_used: int  = 0


# Factory: build a budget scaled to the dungeon's average tier.
static func for_tier(tier: int) -> DungeonLootBudget:
	var b := DungeonLootBudget.new()
	b.max_equipment   = 3 + tier * 2        # tier1=5, tier6=15
	b.max_consumables = 10 + tier * 3       # tier1=13, tier6=28
	b.max_unique      = 1
	return b


func equipment_ok() -> bool:
	return _equipment < max_equipment


func consumable_ok() -> bool:
	return _consumables < max_consumables


func unique_ok() -> bool:
	return _unique_used < max_unique


func consume_equipment() -> void:
	_equipment += 1


func consume_consumable() -> void:
	_consumables += 1


func consume_unique() -> void:
	_unique_used += 1


func remaining_equipment() -> int:
	return max_equipment - _equipment
