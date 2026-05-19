class_name BalanceLoot

const _Math = preload("res://scripts/core/game_balance/BalanceMath.gd")

# ─── Chest count ──────────────────────────────────────────────────────────────
const CHEST_COUNT_WEIGHT_LEVELS: Array = [1, 4, 6, 9, 11, 14, 17, 19, 22, 24, 27, 30, 32, 35, 37, 40, 43, 45, 48, 50]

## One row per chest count (0–3); one column per level breakpoint.
## At low levels floors are mostly empty; at high levels more chests appear.
const CHEST_COUNT_WEIGHTS: Array = [
	#    1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  50, 47, 44, 41, 40, 36, 33, 31, 28, 26, 24, 22, 21, 19, 18, 16, 14, 13, 11, 10 ],  # 0 chests
	[  30, 31, 32, 33, 33, 33, 34, 34, 34, 34, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25 ],  # 1 chest
	[  15, 16, 17, 18, 18, 20, 21, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35 ],  # 2 chests
	[   5,  6,  7,  8,  9, 11, 12, 13, 14, 15, 16, 18, 19, 21, 22, 24, 26, 27, 29, 30 ],  # 3 chests
]

static func roll_chest_count(rng: RandomNumberGenerator, player_level: int) -> int:
	return _Math.weighted_roll(rng, player_level, CHEST_COUNT_WEIGHT_LEVELS, CHEST_COUNT_WEIGHTS)

# ─── Leveled loot table ───────────────────────────────────────────────────────
## Each entry unlocks when player level >= min_level.
## Weight is relative within the pool of all currently-eligible entries.
##
## Morrowind-style: low-tier items remain available at high levels but become
## proportionally rarer as higher-tier entries expand the pool.
## 15 tiers spread across levels 1–50. Add entries here — no code changes needed.
## Items marked TODO need real item_id values when the item system is designed.
const CHEST_LOOT_TABLE: Array = [
	# ── Tier 1 (level 1+) ───────────────────────────────────────────────────────
	{ "item_id": "small_potion",    "weight": 50, "min_level": 1  },
	{ "item_id": "rusty_sword",     "weight": 15, "min_level": 1  },
	{ "item_id": "leather_helm",    "weight": 15, "min_level": 1  },
	{ "item_id": "leather_boots",   "weight": 15, "min_level": 1  },
	# ── Tier 2 (level 4+) ───────────────────────────────────────────────────────
	{ "item_id": "medium_potion",   "weight": 45, "min_level": 4  },
	{ "item_id": "leather_armor",   "weight": 20, "min_level": 4  },
	{ "item_id": "iron_sword",      "weight": 20, "min_level": 4  },
	# ── Tier 3 (level 7+) ───────────────────────────────────────────────────────
	{ "item_id": "iron_shield",     "weight": 15, "min_level": 7  },
	{ "item_id": "lucky_ring",      "weight": 10, "min_level": 7  },
	# ── Tier 4 (level 10+) ──────────────────────────────────────────────────────
	{ "item_id": "large_potion",    "weight": 40, "min_level": 10 },
	{ "item_id": "iron_helm",       "weight": 18, "min_level": 10 },
	{ "item_id": "iron_boots",      "weight": 18, "min_level": 10 },
	# ── Tier 5 (level 14+) ──────────────────────────────────────────────────────
	{ "item_id": "steel_sword",     "weight": 22, "min_level": 14 },
	{ "item_id": "chain_armor",     "weight": 22, "min_level": 14 },
	# ── Tier 6 (level 18+) ──────────────────────────────────────────────────────
	{ "item_id": "steel_shield",    "weight": 18, "min_level": 18 },
	{ "item_id": "mana_ring",       "weight": 12, "min_level": 18 },
	# ── Tier 7 (level 22+) ──────────────────────────────────────────────────────
	{ "item_id": "elixir",          "weight": 35, "min_level": 22 },
	{ "item_id": "steel_helm",      "weight": 16, "min_level": 22 },
	{ "item_id": "steel_boots",     "weight": 16, "min_level": 22 },
	# ── Tier 8 (level 26+) ──────────────────────────────────────────────────────
	{ "item_id": "silver_sword",    "weight": 20, "min_level": 26 },
	{ "item_id": "plate_armor",     "weight": 20, "min_level": 26 },
	# ── Tier 9 (level 30+) ──────────────────────────────────────────────────────
	{ "item_id": "plate_shield",    "weight": 16, "min_level": 30 },
	{ "item_id": "ring_of_strength","weight": 10, "min_level": 30 },
	# ── Tier 10 (level 34+) ─────────────────────────────────────────────────────
	{ "item_id": "super_elixir",    "weight": 30, "min_level": 34 },
	{ "item_id": "silver_helm",     "weight": 14, "min_level": 34 },
	{ "item_id": "silver_boots",    "weight": 14, "min_level": 34 },
	# ── Tier 11 (level 37+) ─────────────────────────────────────────────────────
	{ "item_id": "enchanted_sword", "weight": 18, "min_level": 37 },
	{ "item_id": "enchanted_armor", "weight": 18, "min_level": 37 },
	# ── Tier 12 (level 40+) ─────────────────────────────────────────────────────
	{ "item_id": "enchanted_shield","weight": 14, "min_level": 40 },
	{ "item_id": "ring_of_wisdom",  "weight": 10, "min_level": 40 },
	# ── Tier 13 (level 44+) ─────────────────────────────────────────────────────
	{ "item_id": "golden_sword",    "weight": 16, "min_level": 44 },
	{ "item_id": "golden_armor",    "weight": 16, "min_level": 44 },
	# ── Tier 14 (level 47+) ─────────────────────────────────────────────────────
	{ "item_id": "phoenix_potion",  "weight": 25, "min_level": 47 },
	{ "item_id": "golden_shield",   "weight": 12, "min_level": 47 },
	# ── Tier 15 (level 50+) ─────────────────────────────────────────────────────
	{ "item_id": "legendary_sword", "weight": 14, "min_level": 50 },
	{ "item_id": "ancient_ring",    "weight": 10, "min_level": 50 },
]
