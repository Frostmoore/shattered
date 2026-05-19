class_name EnemySpider

static func get_data() -> Dictionary:
	return {
		"id": "spider", "name": "Ragno", "char": "r",
		"color": [0.70, 0.50, 0.20, 1.0],
		"hp_base": 5,  "hp_per_floor": 1,
		"atk_base": 2, "atk_per_floor": 0,
		"def_base": 0, "def_per_floor": 0,
		"xp_reward": 8,  "pressure_cost": 4,
		"min_floor": 1,  "detection": 6,
	}
