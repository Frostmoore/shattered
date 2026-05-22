class_name EnemyGoblin

static func get_data() -> Dictionary:
	return {
		"id": "goblin", "name": "Goblin", "char": "g",
		"color": [0.28, 0.88, 0.28, 1.0],
		"hp_base": 8,
		"atk_base": 3,
		"def_base": 0,
		"dex_base": 5,
		"xp_reward": 15, "pressure_cost": 6,
		"min_floor": 1,  "detection": 5,
	}
