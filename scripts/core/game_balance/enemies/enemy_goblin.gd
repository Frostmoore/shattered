class_name EnemyGoblin

static func get_data() -> Dictionary:
	return {
		"id": "goblin", "name": "Goblin", "char": "g",
		"color": [0.28, 0.88, 0.28, 1.0],
		"hp_base": 8,  "hp_per_floor": 2,
		"atk_base": 3, "atk_per_floor": 1,
		"def_base": 0, "def_per_floor": 0,
		"xp_reward": 15, "pressure_cost": 6,
		"min_floor": 1,  "detection": 5,
	}
