class_name BalanceEnemy

## Enemy balance: difficulty-scaling parameters per dungeon.
## roll_balance() is called once per dungeon so difficulty stays consistent
## across that dungeon's floors.
## Il roster nemici vive ora in data/enemies/ ed è gestito da EnemyRegistry.

const _Math = preload("res://scripts/core/game_balance/BalanceMath.gd")

# ─── Shared level breakpoints (20 points, ~every 2-3 levels) ─────────────────
const BALANCE_LEVELS: Array = [1, 4, 6, 9, 11, 14, 17, 19, 22, 24, 27, 30, 32, 35, 37, 40, 43, 45, 48, 50]

# ─── Danger rating (1-6) ──────────────────────────────────────────────────────
## Maps to BalancePressure budget tier. Low player level → mostly 1-2; high level → 4-6.

const DANGER_RATING_VALUES: Array = [1, 2, 3, 4, 5, 6]
const DANGER_RATING_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[ 40, 35, 28, 20, 16, 12,  9,  7,  5,  4,  3,  2,  2,  2,  1,  1,  1,  1,  1,  0 ],
	[ 35, 35, 35, 33, 30, 26, 22, 19, 16, 14, 11, 10,  8,  7,  6,  5,  4,  4,  3,  2 ],
	[ 18, 20, 24, 27, 28, 28, 27, 26, 24, 23, 21, 20, 18, 17, 15, 14, 12, 11, 10,  8 ],
	[  6,  8, 10, 14, 17, 20, 22, 23, 25, 25, 26, 26, 27, 27, 27, 27, 26, 26, 25, 24 ],
	[  1,  2,  3,  5,  7,  9, 12, 14, 17, 18, 20, 22, 23, 24, 25, 26, 27, 27, 28, 29 ],
	[  0,  0,  0,  1,  2,  5,  8, 11, 13, 16, 19, 20, 22, 23, 26, 27, 30, 31, 33, 37 ],
]

# ─── Budget curve ─────────────────────────────────────────────────────────────
## Distribution of pressure across floors. "rising" is the default (45% probability).

const BUDGET_CURVE_VALUES:  Array = ["rising", "flat", "spiky", "boss_rush", "exhaustion"]
const BUDGET_CURVE_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[ 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45 ],
	[ 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20 ],
	[ 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15 ],
	[ 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 ],
	[ 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 ],
]

# ─── Pressure budget ──────────────────────────────────────────────────────────
## Total enemy budget for floor 1.

const PRESSURE_BASE_VALUES: Array = [18, 26, 35, 46, 60]
const PRESSURE_BASE_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  55, 46, 41, 33, 29, 25, 22, 19, 15, 13, 11, 11, 10,  9,  9,  8,  7,  6,  6,  5 ],
	[  30, 32, 33, 34, 35, 32, 30, 29, 27, 26, 24, 22, 21, 20, 19, 17, 16, 15, 13, 12 ],
	[  12, 16, 19, 24, 25, 27, 28, 29, 31, 31, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22 ],
	[   3,  5,  6,  7,  9, 12, 15, 17, 20, 22, 24, 25, 26, 27, 27, 29, 30, 31, 32, 33 ],
	[   0,  1,  1,  2,  2,  4,  5,  6,  7,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28 ],
]

## Budget increment added per additional floor.

const PRESSURE_PER_FLOOR_VALUES: Array = [7, 10, 14, 19, 25]
const PRESSURE_PER_FLOOR_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  55, 46, 41, 33, 29, 25, 22, 19, 15, 13, 11, 11, 10,  9,  9,  8,  7,  6,  6,  5 ],
	[  30, 32, 33, 34, 35, 32, 30, 29, 27, 26, 24, 22, 21, 20, 19, 17, 16, 15, 13, 12 ],
	[  12, 16, 19, 24, 25, 27, 28, 29, 31, 31, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22 ],
	[   3,  5,  6,  7,  9, 12, 15, 17, 20, 22, 24, 25, 26, 27, 27, 29, 30, 31, 32, 33 ],
	[   0,  1,  1,  2,  2,  4,  5,  6,  7,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28 ],
]

## Hard cap on enemies placed in a single room.

const MAX_PER_ROOM_VALUES: Array = [2, 3, 4, 5]
const MAX_PER_ROOM_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  50, 44, 39, 32, 29, 26, 23, 21, 18, 16, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5 ],
	[  38, 39, 40, 41, 42, 40, 39, 38, 37, 36, 34, 32, 31, 29, 28, 26, 24, 23, 21, 20 ],
	[  10, 14, 17, 21, 23, 25, 28, 30, 32, 34, 35, 36, 36, 37, 37, 38, 39, 39, 40, 40 ],
	[   2,  3,  4,  6,  6,  8, 10, 11, 13, 14, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35 ],
]

# ─── Boss scaling ─────────────────────────────────────────────────────────────
## The boss is the strongest enemy on the floor, scaled by these multipliers.

const BOSS_HP_VALUES: Array = [1.4, 1.6, 1.8, 2.2, 2.8]
const BOSS_HP_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  55, 46, 41, 33, 29, 25, 22, 19, 15, 13, 11, 11, 10,  9,  9,  8,  7,  6,  6,  5 ],
	[  30, 32, 33, 34, 35, 32, 30, 29, 27, 26, 24, 22, 21, 20, 19, 17, 16, 15, 13, 12 ],
	[  12, 16, 19, 24, 25, 27, 28, 29, 31, 31, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22 ],
	[   3,  5,  6,  7,  9, 12, 15, 17, 20, 22, 24, 25, 26, 27, 27, 29, 30, 31, 32, 33 ],
	[   0,  1,  1,  2,  2,  4,  5,  6,  7,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28 ],
]

const BOSS_ATK_VALUES: Array = [1.1, 1.2, 1.3, 1.5, 1.8]
const BOSS_ATK_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  55, 46, 41, 33, 29, 25, 22, 19, 15, 13, 11, 11, 10,  9,  9,  8,  7,  6,  6,  5 ],
	[  30, 32, 33, 34, 35, 32, 30, 29, 27, 26, 24, 22, 21, 20, 19, 17, 16, 15, 13, 12 ],
	[  12, 16, 19, 24, 25, 27, 28, 29, 31, 31, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22 ],
	[   3,  5,  6,  7,  9, 12, 15, 17, 20, 22, 24, 25, 26, 27, 27, 29, 30, 31, 32, 33 ],
	[   0,  1,  1,  2,  2,  4,  5,  6,  7,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28 ],
]

const BOSS_DEF_VALUES: Array = [1.1, 1.2, 1.3, 1.5, 1.7]
const BOSS_DEF_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  55, 46, 41, 33, 29, 25, 22, 19, 15, 13, 11, 11, 10,  9,  9,  8,  7,  6,  6,  5 ],
	[  30, 32, 33, 34, 35, 32, 30, 29, 27, 26, 24, 22, 21, 20, 19, 17, 16, 15, 13, 12 ],
	[  12, 16, 19, 24, 25, 27, 28, 29, 31, 31, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22 ],
	[   3,  5,  6,  7,  9, 12, 15, 17, 20, 22, 24, 25, 26, 27, 27, 29, 30, 31, 32, 33 ],
	[   0,  1,  1,  2,  2,  4,  5,  6,  7,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28 ],
]

const BOSS_XP_VALUES: Array = [3.0, 4.0, 5.0, 6.5, 8.0]
const BOSS_XP_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  55, 46, 41, 33, 29, 25, 22, 19, 15, 13, 11, 11, 10,  9,  9,  8,  7,  6,  6,  5 ],
	[  30, 32, 33, 34, 35, 32, 30, 29, 27, 26, 24, 22, 21, 20, 19, 17, 16, 15, 13, 12 ],
	[  12, 16, 19, 24, 25, 27, 28, 29, 31, 31, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22 ],
	[   3,  5,  6,  7,  9, 12, 15, 17, 20, 22, 24, 25, 26, 27, 27, 29, 30, 31, 32, 33 ],
	[   0,  1,  1,  2,  2,  4,  5,  6,  7,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28 ],
]

const BOSS_DETECTION_VALUES: Array = [7, 9, 10, 12, 14]
const BOSS_DETECTION_WEIGHTS: Array = [
	#   1   4   6   9  11  14  17  19  22  24  27  30  32  35  37  40  43  45  48  50
	[  55, 46, 41, 33, 29, 25, 22, 19, 15, 13, 11, 11, 10,  9,  9,  8,  7,  6,  6,  5 ],
	[  30, 32, 33, 34, 35, 32, 30, 29, 27, 26, 24, 22, 21, 20, 19, 17, 16, 15, 13, 12 ],
	[  12, 16, 19, 24, 25, 27, 28, 29, 31, 31, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22 ],
	[   3,  5,  6,  7,  9, 12, 15, 17, 20, 22, 24, 25, 26, 27, 27, 29, 30, 31, 32, 33 ],
	[   0,  1,  1,  2,  2,  4,  5,  6,  7,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28 ],
]

# ─── Roll ─────────────────────────────────────────────────────────────────────
## Rolls all enemy-balance parameters for a dungeon in one pass.
## Call once per dungeon (not per floor) so difficulty is consistent across floors.
## Returns: { pressure_base, pressure_per_floor, max_per_room,
##             boss_hp_mult, boss_atk_mult, boss_def_mult, boss_xp_mult, boss_detection }
static func roll_balance(rng: RandomNumberGenerator, player_level: int) -> Dictionary:
	var lv: Array = BALANCE_LEVELS
	return {
		"pressure_base":      int(PRESSURE_BASE_VALUES[     _Math.weighted_roll(rng, player_level, lv, PRESSURE_BASE_WEIGHTS)]),
		"pressure_per_floor": int(PRESSURE_PER_FLOOR_VALUES[_Math.weighted_roll(rng, player_level, lv, PRESSURE_PER_FLOOR_WEIGHTS)]),
		"max_per_room":       int(MAX_PER_ROOM_VALUES[      _Math.weighted_roll(rng, player_level, lv, MAX_PER_ROOM_WEIGHTS)]),
		"boss_hp_mult":     float(BOSS_HP_VALUES[       _Math.weighted_roll(rng, player_level, lv, BOSS_HP_WEIGHTS)]),
		"boss_atk_mult":    float(BOSS_ATK_VALUES[      _Math.weighted_roll(rng, player_level, lv, BOSS_ATK_WEIGHTS)]),
		"boss_def_mult":    float(BOSS_DEF_VALUES[      _Math.weighted_roll(rng, player_level, lv, BOSS_DEF_WEIGHTS)]),
		"boss_xp_mult":     float(BOSS_XP_VALUES[       _Math.weighted_roll(rng, player_level, lv, BOSS_XP_WEIGHTS)]),
		"boss_detection":     int(BOSS_DETECTION_VALUES[_Math.weighted_roll(rng, player_level, lv, BOSS_DETECTION_WEIGHTS)]),
		"danger_rating":      int(DANGER_RATING_VALUES[ _Math.weighted_roll(rng, player_level, lv, DANGER_RATING_WEIGHTS)]),
		"budget_curve":    str(BUDGET_CURVE_VALUES[     _Math.weighted_roll(rng, player_level, lv, BUDGET_CURVE_WEIGHTS)]),
	}
