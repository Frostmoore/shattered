class_name BuildingGenerator


static func generate(params: Dictionary) -> MapData:
	var data := MapData.new()
	data.id   = params.get("id",     "building_01")
	data.type = "building"
	data.width  = params.get("width",  10)
	data.height = params.get("height", 10)
	data.add_border_walls()
	return data
