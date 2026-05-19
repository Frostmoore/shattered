class_name BalanceMath

## Shared weighted-random helper for all level-scaled balance rolls.

## Weighted random pick with level-based interpolation.
## levels: ascending breakpoint levels used as the table's columns.
## table:  one row per outcome; each row holds the weight at each breakpoint level.
## Weights are linearly interpolated between the two breakpoints surrounding
## player_level; any level beyond the last breakpoint uses the last column.
## Returns the index of the chosen row.
static func weighted_roll(rng: RandomNumberGenerator, player_level: int,
		levels: Array, table: Array) -> int:
	var col_a: int = levels.size() - 1
	var col_b: int = levels.size() - 1
	var t: float   = 0.0
	if player_level < int(levels[levels.size() - 1]):
		for i: int in range(levels.size() - 1):
			if player_level <= int(levels[i + 1]):
				col_a = i
				col_b = i + 1
				t = float(player_level - int(levels[i])) / float(int(levels[i + 1]) - int(levels[i]))
				break
	var weights: Array[float] = []
	for row: Variant in table:
		var r: Array = row as Array
		weights.append(maxf(0.0, lerpf(float(int(r[col_a])), float(int(r[col_b])), t)))
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = rng.randf() * total
	var cumulative: float = 0.0
	for i: int in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return 0
