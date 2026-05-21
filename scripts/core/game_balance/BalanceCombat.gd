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


static func level_factor(level: int) -> float:
	return 2.0 * float(level) / 5.0 + 2.0


static func output_multiplier(level: int) -> float:
	if DAMAGE_SCALE <= 0.0:
		return 1.0
	return pow(100.0, DAMAGE_SCALE * float(level) / 100.0)
