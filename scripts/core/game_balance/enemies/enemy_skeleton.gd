class_name EnemySkeleton

static func get_data() -> Dictionary:
	return {
		"id": "skeleton", "name": "Scheletro", "char": "s",
		"color": [0.80, 0.78, 0.70, 1.0],
		"hp_base": 12, "hp_per_floor": 2,
		"atk_base": 4, "atk_per_floor": 1,
		"def_base": 1, "def_per_floor": 0,
		"xp_reward": 25, "pressure_cost": 9,
		"min_floor": 2,  "detection": 5,
	}
