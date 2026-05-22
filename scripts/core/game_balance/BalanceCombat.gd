class_name BalanceCombat

## Normalization constant for the damage formula.
## Lower = more damage overall. Suggested starting range: 2.0–10.0
const DAMAGE_K: float = 5.0

## Minimum guaranteed damage per hit.
const DAMAGE_MIN: int = 1

## Level-based output amplifier applied to all damage (player and enemies).
## 0.0 = no effect at any level.
## 1.0 = ×100 multiplier at level 100, exponentially scaled.
## Formula: pow(100, DAMAGE_SCALE × attacker_level / 100)
const DAMAGE_SCALE: float = 0.0

## Base hit chance when attacker and defender have identical relevant stats.
const BASE_HIT_CHANCE: float = 0.75

## Hit chance delta per point of stat advantage/disadvantage.
## e.g. 0.02 means +1 stat point = +2% hit chance.
const ACCURACY_K: float = 0.02

## Absolute floor and ceiling for hit chance (regardless of stat gap).
const MIN_HIT_CHANCE: float = 0.10
const MAX_HIT_CHANCE: float = 0.95

## Reference DEX for accuracy/evasion equipment scaling.
## At this DEX value, 1 accuracy/evasion point = 1 virtual stat point in the hit formula.
## Higher DEX → better returns from accuracy/evasion gear (sqrt scaling).
const DEX_BASE: float = 10.0


static func level_factor(level: int) -> float:
	return 2.0 * float(level) / 5.0 + 2.0


static func output_multiplier(level: int) -> float:
	if DAMAGE_SCALE <= 0.0:
		return 1.0
	return pow(100.0, DAMAGE_SCALE * float(level) / 100.0)


## Scaling multiplier for accuracy/evasion equipment stats.
## Returns sqrt(dex / DEX_BASE) — agile characters get more out of precision gear.
static func accuracy_multiplier(dex: int) -> float:
	return sqrt(float(maxi(1, dex)) / DEX_BASE)
