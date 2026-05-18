extends Node

var _items: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var path: String = "res://data/items/items.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ItemDB: cannot open " + path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		push_error("ItemDB: expected JSON array")
		return
	for item: Variant in (parsed as Array):
		if item is Dictionary:
			var d: Dictionary = item as Dictionary
			_items[d["id"]] = d


func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {})
