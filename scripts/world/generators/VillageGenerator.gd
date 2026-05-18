class_name VillageGenerator


static func generate(params: Dictionary) -> MapData:
	var data := MapData.new()
	data.id   = params.get("id",     "village_01")
	data.type = "village"
	data.width  = params.get("width",  20)
	data.height = params.get("height", 20)

	data.add_border_walls()
	data.add_blocked_rect(Vector2i( 3,  3), Vector2i(4, 4))
	data.add_blocked_rect(Vector2i(12,  3), Vector2i(4, 4))
	data.add_blocked_rect(Vector2i( 3, 12), Vector2i(4, 4))

	var overworld_id: String = params.get("transition_overworld", "overworld")
	data.add_transition(
		Vector2i(10, 18), overworld_id, "overworld", Vector2i(10, 9)
	)

	# Fontana centrale — punto di salvataggio del villaggio
	data.add_entity("save_point", "save_point_village", Vector2i(10, 10), {
		"label": "Fontana"
	})

	data.add_entity("npc", "npc_8_8", Vector2i(8, 8), {
		"id":                      "village_elder",
		"name":                    "Vecchio del villaggio",
		"dialogue_id":             "village_npc_01",
		"dialogue_id_quest_active": "village_npc_quest_active",
		"dialogue_id_quest_done":   "village_npc_quest_done",
		"linked_quest_id":          "quest_clear_dungeon",
		"idle_dialogue_ids":        ["village_npc_idle_01", "village_npc_idle_02"]
	})

	return data
