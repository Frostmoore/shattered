class_name OverworldGenerator


static func generate(params: Dictionary) -> MapData:
	var data := MapData.new()
	data.id   = params.get("id",     "overworld")
	data.type = "overworld"
	data.width  = params.get("width",  32)
	data.height = params.get("height", 32)

	data.add_border_walls()
	data.add_blocked_rect(Vector2i(14,  6), Vector2i(4, 8))
	data.add_blocked_rect(Vector2i(20, 10), Vector2i(3, 5))

	var village_id: String = params.get("transition_village", "village_01")
	var dungeon_id: String = params.get("transition_dungeon", "dungeon_01")

	data.add_transition(
		Vector2i(10, 8), village_id, "village", Vector2i(10, 17)
	)
	data.add_transition(
		Vector2i(18, 14), dungeon_id, "dungeon", Vector2i(3, 2)
	)

	return data
