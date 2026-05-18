class_name DungeonGenerator


static func generate(params: Dictionary) -> MapData:
	var data := MapData.new()
	data.id   = params.get("id",     "dungeon_01")
	data.type = "dungeon"
	data.width  = params.get("width",  24)
	data.height = params.get("height", 24)
	data.metadata["seed"] = params.get("seed", 0)

	data.add_border_walls()
	data.add_blocked_rect(Vector2i( 5,  5), Vector2i(6, 1))
	data.add_blocked_rect(Vector2i( 5, 10), Vector2i(1, 6))
	data.add_blocked_rect(Vector2i(12,  5), Vector2i(1, 8))
	data.add_blocked_rect(Vector2i(15, 12), Vector2i(6, 1))
	data.add_blocked_rect(Vector2i( 8, 15), Vector2i(5, 1))

	var overworld_id: String = params.get("transition_overworld", "overworld")
	data.add_transition(
		Vector2i(2, 1), overworld_id, "overworld", Vector2i(18, 15)
	)

	# Campo base — punto di salvataggio della miniera
	data.add_entity("save_point", "save_point_dungeon", Vector2i(3, 3), {
		"label": "Campo base"
	})

	data.add_entity("enemy", "enemy_7_6",  Vector2i(7,  6), {
		"id": "goblin", "name": "Goblin", "hp": 8, "attack": 3, "defense": 0, "xp_reward": 15
	})
	data.add_entity("enemy", "enemy_14_7", Vector2i(14, 7), {
		"id": "goblin", "name": "Goblin", "hp": 8, "attack": 3, "defense": 0, "xp_reward": 15
	})
	data.add_entity("enemy", "enemy_6_14", Vector2i(6, 14), {
		"id": "skeleton", "name": "Scheletro", "hp": 10, "attack": 4, "defense": 1, "xp_reward": 25
	})
	data.add_entity("enemy", "enemy_18_18", Vector2i(18, 18), {
		"id": "mine_boss", "name": "Capo della miniera",
		"hp": 25, "attack": 6, "defense": 2, "xp_reward": 120,
		"detection_range": 8, "boss": true
	})

	return data
