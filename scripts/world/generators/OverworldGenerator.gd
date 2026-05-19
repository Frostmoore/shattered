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
	var dungeon_id: String = params.get("transition_dungeon", "dungeon_01_floor_1")

	# Village entrance
	data.add_transition(
		Vector2i(10, 8), village_id, "village", Vector2i(10, 17)
	)

	# Dungeon entrance — target position comes from params so it matches floor 1's generated stair-up
	var dungeon_tile_x: int = params.get("overworld_dungeon_tile_x", 18)
	var dungeon_tile_y: int = params.get("overworld_dungeon_tile_y", 14)
	var target_x: int = params.get("dungeon_target_pos_x", 3)
	var target_y: int = params.get("dungeon_target_pos_y", 2)
	data.add_transition(
		Vector2i(dungeon_tile_x, dungeon_tile_y),
		dungeon_id, "dungeon",
		Vector2i(target_x, target_y)
	)

	return data
