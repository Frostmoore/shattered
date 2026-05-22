class_name ClassCombatProfile

## Representative combat archetypes for enemy balance validation.
## NOT actual class implementations — developer tool only.
##
## Stats scale linearly from *_l1 values using *_growth per level.
## Usage: CombatSimulator.run_validation() prints a full TTK table to the Godot Output panel.

# ─── Profile definitions ──────────────────────────────────────────────────────
## hp_l1 / atk_l1 / def_l1 / dex_l1: stats at level 1.
## *_growth: stat increase per additional level (floored to int for atk/def/dex).
## combat_type: "melee" | "ranged" | "magic" — determines hit_stat formula.

const PROFILES: Dictionary = {
	"melee_bruiser": {
		"label":        "Guerriero / Barbaro",
		"combat_type":  "melee",
		"hp_l1": 25,    "hp_growth":  3.0,
		"atk_l1": 6,    "atk_growth": 0.45,
		"def_l1": 1,    "def_growth": 0.12,
		"dex_l1": 5,    "dex_growth": 0.04,
	},
	"melee_tank": {
		"label":        "Paladino / Cavaliere",
		"combat_type":  "melee",
		"hp_l1": 40,    "hp_growth":  5.0,
		"atk_l1": 4,    "atk_growth": 0.30,
		"def_l1": 3,    "def_growth": 0.20,
		"dex_l1": 3,    "dex_growth": 0.02,
	},
	"melee_glass_cannon": {
		"label":        "Assassino / Spettro",
		"combat_type":  "melee",
		"hp_l1": 18,    "hp_growth":  2.0,
		"atk_l1": 8,    "atk_growth": 0.55,
		"def_l1": 1,    "def_growth": 0.05,
		"dex_l1": 7,    "dex_growth": 0.10,
	},
	"ranged_physical": {
		"label":        "Ranger / Arciere",
		"combat_type":  "ranged",
		"hp_l1": 22,    "hp_growth":  2.5,
		"atk_l1": 5,    "atk_growth": 0.42,
		"def_l1": 1,    "def_growth": 0.06,
		"dex_l1": 8,    "dex_growth": 0.10,
	},
	"caster_burst": {
		"label":        "Mago / Piromante",
		"combat_type":  "magic",
		"hp_l1": 16,    "hp_growth":  1.8,
		"atk_l1": 7,    "atk_growth": 0.50,
		"def_l1": 0,    "def_growth": 0.03,
		"dex_l1": 4,    "dex_growth": 0.04,
	},
	"evasion_based": {
		"label":        "Ladro / Monaco",
		"combat_type":  "melee",
		"hp_l1": 20,    "hp_growth":  2.5,
		"atk_l1": 5,    "atk_growth": 0.42,
		"def_l1": 1,    "def_growth": 0.05,
		"dex_l1": 9,    "dex_growth": 0.14,
	},
	"sustain_based": {
		"label":        "Sacerdote / Biomante",
		"combat_type":  "magic",
		"hp_l1": 35,    "hp_growth":  4.0,
		"atk_l1": 3,    "atk_growth": 0.25,
		"def_l1": 2,    "def_growth": 0.15,
		"dex_l1": 4,    "dex_growth": 0.04,
	},
	"hybrid": {
		"label":        "Spellblade / Bardo",
		"combat_type":  "melee",
		"hp_l1": 24,    "hp_growth":  3.0,
		"atk_l1": 5,    "atk_growth": 0.40,
		"def_l1": 2,    "def_growth": 0.12,
		"dex_l1": 6,    "dex_growth": 0.06,
	},
}


# ─── TTK target ranges by enemy role [min_hits, max_hits] ─────────────────────
## Tested at zone_min_level. Values outside range flag the enemy for review.
const TTK_TARGETS: Dictionary = {
	"swarm":        [1,  3],
	"skirmisher":   [2,  5],
	"soldier":      [3,  7],
	"glass_cannon": [2,  5],
	"brute":        [4, 10],
	"tank":         [5, 12],
	"controller":   [3,  8],
	"assassin":     [2,  5],
	"elite":        [6, 12],
	"boss":         [8, 20],
}


## Returns stats for a profile at a given level (linear interpolation from l1 + growth).
static func stats_at(profile_id: String, level: int) -> Dictionary:
	var p: Dictionary = PROFILES.get(profile_id, {}) as Dictionary
	if p.is_empty():
		return {}
	var lv: int = maxi(1, level)
	return {
		"hp":          maxi(1, roundi(float(int(p["hp_l1"]))  + float(lv - 1) * float(p["hp_growth"]))),
		"attack":      maxi(1, int(p["atk_l1"]) + floori(float(lv - 1) * float(p["atk_growth"]))),
		"defense":     maxi(0, int(p["def_l1"]) + floori(float(lv - 1) * float(p["def_growth"]))),
		"dex":         maxi(1, int(p["dex_l1"]) + floori(float(lv - 1) * float(p["dex_growth"]))),
		"combat_type": str(p["combat_type"]),
		"label":       str(p["label"]),
	}
