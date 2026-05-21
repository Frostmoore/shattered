class_name GameBalance

## Central balance entrypoint.
## All constants live in scripts/core/game_balance/ and are re-exported here
## so the rest of the codebase can keep using GameBalance.X without changes.
##
## Sub-files are loaded via preload() rather than class_name references to avoid
## parse-order errors (GDScript resolves class_name registrations lazily, but
## preload paths are resolved deterministically at compile time).

const _Fov     = preload("res://scripts/core/game_balance/BalanceFov.gd")
const _Dungeon = preload("res://scripts/core/game_balance/BalanceDungeon.gd")
const _Enemy   = preload("res://scripts/core/game_balance/BalanceEnemy.gd")
const _Loot    = preload("res://scripts/core/game_balance/BalanceLoot.gd")
const _Math    = preload("res://scripts/core/game_balance/BalanceMath.gd")
const _Combat  = preload("res://scripts/core/game_balance/BalanceCombat.gd")

# ─── Combat ───────────────────────────────────────────────────────────────────
const DAMAGE_K:     float = _Combat.DAMAGE_K
const DAMAGE_MIN:   int   = _Combat.DAMAGE_MIN
const DAMAGE_SCALE: float = _Combat.DAMAGE_SCALE

# ─── FOV ──────────────────────────────────────────────────────────────────────
const FOV_RADIUS:            int   = _Fov.FOV_RADIUS
const FOV_MEMORY_ALPHA:      float = _Fov.FOV_MEMORY_ALPHA
const FOV_DOORS_BLOCK_SIGHT: bool  = _Fov.FOV_DOORS_BLOCK_SIGHT

# ─── Dungeon ──────────────────────────────────────────────────────────────────
const DUNGEON_SIZE_CATEGORIES:    Array = _Dungeon.DUNGEON_SIZE_CATEGORIES
const DUNGEON_SIZE_WEIGHT_LEVELS: Array = _Dungeon.DUNGEON_SIZE_WEIGHT_LEVELS
const DUNGEON_SIZE_WEIGHT_TABLE:  Array = _Dungeon.DUNGEON_SIZE_WEIGHT_TABLE
const ROOM_MIN_SIZE_LO:           int   = _Dungeon.ROOM_MIN_SIZE_LO
const ROOM_MIN_SIZE_HI:           int   = _Dungeon.ROOM_MIN_SIZE_HI
const ROOM_MAX_SIZE_LO:           int   = _Dungeon.ROOM_MAX_SIZE_LO
const ROOM_MAX_SIZE_HI:           int   = _Dungeon.ROOM_MAX_SIZE_HI
const ROOM_RNG_VARIANCE:          int   = _Dungeon.ROOM_RNG_VARIANCE
const BSP_LEAF_EXTRA:             int   = _Dungeon.BSP_LEAF_EXTRA
const CORRIDOR_LOOP_MIN:          float = _Dungeon.CORRIDOR_LOOP_MIN
const CORRIDOR_LOOP_MAX:          float = _Dungeon.CORRIDOR_LOOP_MAX
const DUNGEON_FLOORS_MIN:         int   = _Dungeon.DUNGEON_FLOORS_MIN
const DUNGEON_FLOORS_MAX:         int   = _Dungeon.DUNGEON_FLOORS_MAX
const FLOOR_WEIGHT_LEVELS:        Array = _Dungeon.FLOOR_WEIGHT_LEVELS
const FLOOR_WEIGHT_TABLE:         Array = _Dungeon.FLOOR_WEIGHT_TABLE
const FLOOR_SEED_STRIDE:          int   = _Dungeon.FLOOR_SEED_STRIDE

# ─── Loot ─────────────────────────────────────────────────────────────────────
const CHEST_COUNT_WEIGHTS: Array = _Loot.CHEST_COUNT_WEIGHTS
const CHEST_LOOT_TABLE:    Array = _Loot.CHEST_LOOT_TABLE

static func roll_chest_count(rng: RandomNumberGenerator, player_level: int) -> int:
	var lv: Array = [1, 4, 6, 9, 11, 14, 17, 19, 22, 24, 27, 30, 32, 35, 37, 40, 43, 45, 48, 50]
	return _Math.weighted_roll(rng, player_level, lv, CHEST_COUNT_WEIGHTS)

# ─── Enemy ────────────────────────────────────────────────────────────────────
static func get_enemy_table() -> Array:
	return _Enemy.get_enemy_table()

## Rolls all enemy-balance parameters for a dungeon in one pass.
## Call once per dungeon (not per floor) so difficulty is consistent across floors.
static func roll_enemy_balance(rng: RandomNumberGenerator, player_level: int) -> Dictionary:
	return _Enemy.roll_balance(rng, player_level)

# ─── Dungeon rolls ────────────────────────────────────────────────────────────
static func roll_floor_count(rng: RandomNumberGenerator, player_level: int) -> int:
	return DUNGEON_FLOORS_MIN + _Math.weighted_roll(rng, player_level, FLOOR_WEIGHT_LEVELS, FLOOR_WEIGHT_TABLE)

static func roll_dungeon_size(rng: RandomNumberGenerator, player_level: int) -> Dictionary:
	var idx: int        = _Math.weighted_roll(rng, player_level, DUNGEON_SIZE_WEIGHT_LEVELS, DUNGEON_SIZE_WEIGHT_TABLE)
	var cat: Dictionary = DUNGEON_SIZE_CATEGORIES[idx] as Dictionary
	return {
		"width":  rng.randi_range(int(cat["width_min"]),  int(cat["width_max"])),
		"height": rng.randi_range(int(cat["height_min"]), int(cat["height_max"])),
		"label":  cat["label"],
	}
