class_name EnemyTroll

static func get_data() -> Dictionary:
	return {
		"id": "troll", "name": "Troll delle caverne", "char": "T",
		"color": [0.40, 0.70, 0.30, 1.0],
		"hp_base": 22,
		"atk_base": 6,
		"def_base": 2,
		"xp_reward": 55, "pressure_cost": 16,
		"min_floor": 3,  "detection": 4,
	}
