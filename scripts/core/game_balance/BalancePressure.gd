class_name BalancePressure

## Pressure budget system.
## Translates danger_rating + floor_count into a per-floor budget array
## using one of five distribution curves.
##
## danger_rating (1-6): rolling difficulty tier for the dungeon.
## Each tier maps to a base pressure-per-floor and a per-floor increment,
## calibrated to match the existing PRESSURE_BASE / PRESSURE_PER_FLOOR tables.

# ─── Calibration (matches BalanceEnemy weighted tables at each danger level) ───
const PRESSURE_BASE_BY_DANGER:      Array = [18, 26, 35, 46, 60, 78]
const PRESSURE_PER_FLOOR_BY_DANGER: Array = [ 7, 10, 14, 19, 25, 33]

# Boss/elite budget reserved from total (currently 0 — boss is placed outside the
# regular loop; will be non-zero once elite affixes are implemented in Phase 8)
const BOSS_RESERVE_RATIO:  float = 0.0
const ELITE_RESERVE_RATIO: float = 0.0


## Total pressure budget for a dungeon of floor_count floors at danger_rating.
## Formula mirrors the old linear system: sum over floors of (base + i * per_floor).
static func total_budget(danger_rating: int, floor_count: int) -> int:
	var idx: int = clamp(danger_rating - 1, 0, 5)
	var base: int     = PRESSURE_BASE_BY_DANGER[idx]
	var per_fl: int   = PRESSURE_PER_FLOOR_BY_DANGER[idx]
	var total: int    = 0
	for i: int in range(floor_count):
		total += base + i * per_fl
	return total


## Returns an Array[int] of per-floor budgets that sum to `available`.
## `rng` is only consumed by the "spiky" curve; all others are deterministic.
static func floor_budgets(
	available: int,
	floor_count: int,
	curve: String,
	rng: RandomNumberGenerator
) -> Array[int]:
	var weights: Array[float] = _curve_weights(floor_count, curve, rng)
	var budgets: Array[int]   = []
	for w: float in weights:
		budgets.append(maxi(1, roundi(float(available) * w)))
	return budgets


static func _curve_weights(n: int, curve: String, rng: RandomNumberGenerator) -> Array[float]:
	var weights: Array[float] = []
	match curve:
		"rising":
			# Each floor gets weight proportional to its depth (floor 1 lightest)
			for i: int in range(n):
				weights.append(float(i + 1))
		"flat":
			for _i: int in range(n):
				weights.append(1.0)
		"spiky":
			# Random peaks — dungeon feels uneven
			for _i: int in range(n):
				weights.append(0.5 + rng.randf())
		"boss_rush":
			# Light early floors, heavy final floors
			for i: int in range(n):
				var t: float = float(i) / float(maxi(n - 1, 1))
				weights.append(0.3 + t * t * 2.0)
		"exhaustion":
			# Middle floors slightly heavier — grind down resources before the boss
			for i: int in range(n):
				var t: float = float(i) / float(maxi(n - 1, 1))
				weights.append(0.6 + 0.8 * (1.0 - absf(t - 0.5) * 2.0))
		_:
			# Default: rising
			for i: int in range(n):
				weights.append(float(i + 1))

	var total_w: float = 0.0
	for w: float in weights:
		total_w += w
	if total_w > 0.0:
		for i: int in range(weights.size()):
			weights[i] /= total_w
	return weights


## Pressure multiplier for enemies scaled above/below the zone's recommended level.
## Used in: effective_pressure = base_pressure * level_pressure_mult * affix_mult
## Active from Phase 7 onward; safe to call now (returns 1.0 at exact level match).
static func level_pressure_mult(enemy_level: int, zone_recommended_level: int) -> float:
	return clampf(1.0 + float(enemy_level - zone_recommended_level) * 0.08, 0.75, 1.6)
