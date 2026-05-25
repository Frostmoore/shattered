class_name CityGenerator


static func generate(params: Dictionary) -> MapData:
	var id: String = str(params.get("id", "city"))
	var floor_idx: int = int(params.get("floor", 0))
	var path: String = "res://data/cities/%s.json" % id
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CityGenerator: file not found: " + path)
		return MapData.new()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		push_error("CityGenerator: invalid JSON in: " + path)
		return MapData.new()
	return _from_json(parsed as Dictionary, floor_idx)


const BLOCKED_CATS: Array = [1, 2, 3, 4, 7]  # wall_st, wall_wd, fence, barricade, buca
const EDITOR_ONLY_KINDS: Array = ["spawn_point", "event_trigger"]


static func _from_json(d: Dictionary, floor_idx: int = 0) -> MapData:
	var data := MapData.new()
	data.id   = str(d.get("id",   "city"))
	data.type = str(d.get("type", "village"))
	data.metadata["name"] = str(d.get("name", ""))

	var signoria_raw: Variant = d.get("signoria", "")
	if signoria_raw is String:
		data.metadata["signoria"] = str(signoria_raw)
	var corp_raw: Variant = d.get("corporazioni_presenti", [])
	if corp_raw is Array:
		data.metadata["corporazioni_presenti"] = (corp_raw as Array).duplicate()

	# Resolve floor source — new format has a "floors" array; legacy is flat.
	var floor_d: Dictionary = d
	var floors_raw: Variant = d.get("floors", null)
	if floors_raw is Array and (floors_raw as Array).size() > 0:
		var arr: Array = floors_raw as Array
		var fi: int = clampi(floor_idx, 0, arr.size() - 1)
		floor_d = arr[fi] as Dictionary

	data.width  = int(floor_d.get("width",  40))
	data.height = int(floor_d.get("height", 30))
	data.metadata["floor"] = floor_idx

	var raw_tiles: Variant = floor_d.get("tiles", [])
	if raw_tiles is Array:
		var y: int = 0
		for row_v: Variant in (raw_tiles as Array):
			if row_v is Array:
				var x: int = 0
				for cell_v: Variant in (row_v as Array):
					var cat: int = int(cell_v) >> 4
					if cat in BLOCKED_CATS:
						data.walls.append(Vector2i(x, y))
					x += 1
			y += 1

	var raw_ents: Variant = d.get("entities", [])
	if raw_ents is Array:
		for e_v: Variant in (raw_ents as Array):
			if not e_v is Dictionary:
				continue
			var e: Dictionary   = e_v as Dictionary
			var kind: String    = str(e.get("kind",   "npc"))
			var uid: String     = str(e.get("uid",    ""))
			var ex: int         = int(e.get("x",      0))
			var ey: int         = int(e.get("y",      0))
			var ep: Dictionary  = (e.get("params", {}) as Dictionary).duplicate(true)
			var pos := Vector2i(ex, ey)
			match kind:
				"transition", "exit":
					data.add_transition(
						pos,
						str(ep.get("target_map",  "overworld")),
						str(ep.get("target_type", "overworld")),
						Vector2i(int(ep.get("target_x", 0)), int(ep.get("target_y", 0)))
					)
				"spawn_point":
					data.player_start = pos
				"event_trigger":
					pass  # editor-only, no runtime entity
				_:
					data.add_entity(kind, uid, pos, ep)

	return data
