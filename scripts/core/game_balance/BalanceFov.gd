class_name BalanceFov

## Player vision radius in tiles.  Range 4–12.  Higher = easier.
const FOV_RADIUS: int = 8

## Alpha of memory tiles (seen but not currently visible).
## 0.0 = pitch black,  1.0 = full brightness.  Typical: 0.25–0.45.
const FOV_MEMORY_ALPHA: float = 0.35

## Whether closed doors block line-of-sight.
const FOV_DOORS_BLOCK_SIGHT: bool = true
