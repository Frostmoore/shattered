class_name BalanceDungeon

# ─── Map size ─────────────────────────────────────────────────────────────────
## Floor size is a weighted random roll that picks a size category,
## then rolls width/height within that category's bounds.
## All categories remain possible at every level; only probabilities shift.
##
## Probability at each level:
##   category │ lvl 1   lvl 10   lvl 25   lvl 50
##   ─────────┼────────────────────────────────────
##      tiny  │  50 %    25 %     10 %      5 %
##     small  │  35 %    35 %     20 %     10 %
##    medium  │  12 %    28 %     35 %     20 %
##     large  │   3 %    10 %     28 %     35 %
##      huge  │   0 %     2 %      7 %     30 %

const DUNGEON_SIZE_CATEGORIES: Array = [
	{ "label": "tiny",   "width_min":  35, "width_max":  50, "height_min": 25, "height_max":  38 },
	{ "label": "small",  "width_min":  48, "width_max":  65, "height_min": 36, "height_max":  50 },
	{ "label": "medium", "width_min":  63, "width_max":  82, "height_min": 48, "height_max":  65 },
	{ "label": "large",  "width_min":  80, "width_max": 105, "height_min": 62, "height_max":  82 },
	{ "label": "huge",   "width_min": 100, "width_max": 130, "height_min": 78, "height_max": 100 },
]

const DUNGEON_SIZE_WEIGHT_LEVELS: Array = [1, 10, 25, 50]

const DUNGEON_SIZE_WEIGHT_TABLE: Array = [
	#  lvl1  lvl10  lvl25  lvl50
	[  50,   25,    10,     5  ],  # tiny
	[  35,   35,    20,    10  ],  # small
	[  12,   28,    35,    20  ],  # medium
	[   3,   10,    28,    35  ],  # large
	[   0,    2,     7,    30  ],  # huge
]

# ─── BSP Room Placement ───────────────────────────────────────────────────────
## "min room size" itself varies: each floor rolls a value in [ROOM_MIN_SIZE_LO, ROOM_MIN_SIZE_HI].
## "max room size" varies in [ROOM_MAX_SIZE_LO, ROOM_MAX_SIZE_HI].
## Guarantees: rolled room_max >= rolled room_min + 2.

const ROOM_MIN_SIZE_LO: int = 3
const ROOM_MIN_SIZE_HI: int = 5

const ROOM_MAX_SIZE_LO: int = 7
const ROOM_MAX_SIZE_HI: int = 13

## Per-floor random offset in [−VARIANCE, +VARIANCE] applied to both room size bounds.
## Negative roll → cramped floor; positive roll → spacious floor.
const ROOM_RNG_VARIANCE: int = 1

## Added to the rolled room_max to derive BSP_MIN_LEAF.
## Must be >= 6 to keep leaf large enough for room + walls + clearance.
const BSP_LEAF_EXTRA: int = 6

# ─── Corridors ────────────────────────────────────────────────────────────────
## Extra loop connections beyond MST, as fraction of room count.

const CORRIDOR_LOOP_MIN: float = 0.10
const CORRIDOR_LOOP_MAX: float = 0.45

# ─── Multi-floor ─────────────────────────────────────────────────────────────
## Floor count is a weighted random roll.  All values remain possible at every
## level; only the probability distribution shifts.
##
## FLOOR_WEIGHT_LEVELS: the four level breakpoints used as columns.
## FLOOR_WEIGHT_TABLE:  one row per possible floor count (FLOORS_MIN … FLOORS_MAX).
##                      Each row holds the weight at each breakpoint level.
##                      Weights are linearly interpolated between breakpoints;
##                      any level beyond the last breakpoint uses the last column.
##
## Row sums at each column (must stay consistent for readability — not enforced):
##   lvl  1 → 100   lvl 10 → 100   lvl 25 → 100   lvl 50 → 100
##
## Probability at each level:
##   floors │ lvl 1   lvl 10   lvl 25   lvl 50
##   ───────┼────────────────────────────────────
##        2 │  60 %    35 %     15 %      5 %
##        3 │  30 %    35 %     30 %     15 %
##        4 │   8 %    20 %     30 %     25 %
##        5 │   2 %     8 %     18 %     30 %
##        6 │   0 %     2 %      7 %     25 %

const DUNGEON_FLOORS_MIN: int = 2
const DUNGEON_FLOORS_MAX: int = 6  # must equal FLOORS_MIN + FLOOR_WEIGHT_TABLE.size() - 1

const FLOOR_WEIGHT_LEVELS: Array = [1, 10, 25, 50]

const FLOOR_WEIGHT_TABLE: Array = [
	#  lvl1  lvl10  lvl25  lvl50
	[  60,   35,    15,     5  ],  # 2 floors
	[  30,   35,    30,    15  ],  # 3 floors
	[   8,   20,    30,    25  ],  # 4 floors
	[   2,    8,    18,    30  ],  # 5 floors
	[   0,    2,     7,    25  ],  # 6 floors
]

## RNG seed step between floors (large prime keeps seeds uncorrelated).
const FLOOR_SEED_STRIDE: int = 999983
