extends Node

# Gestione centralizzata degli stati alterati su qualsiasi entità.
# Gli effetti sono dizionari con i campi:
#   id, source, duration_turns, stacking, data
#
# Regole di stacking:
#   replace  — sostituisce l'effetto esistente
#   refresh  — aggiorna solo la durata
#   stack    — aggiunge una nuova istanza (più istanze dello stesso id)
#   ignore   — non applica se esiste già
#   unique   — alias di ignore

# Chiave: instance_id dell'entità → Array di effect Dictionary
var _effects: Dictionary = {}


func apply(target: Node, effect: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	var tid: int = target.get_instance_id()
	if not _effects.has(tid):
		_effects[tid] = []

	var eid: String     = str(effect.get("id", ""))
	var stacking: String = str(effect.get("stacking", "refresh"))
	var existing: int   = _find(tid, eid)

	if existing >= 0:
		match stacking:
			"replace":
				_effects[tid][existing] = effect.duplicate()
			"refresh":
				_effects[tid][existing]["duration_turns"] = int(effect.get("duration_turns", 1))
			"stack":
				_effects[tid].append(effect.duplicate())
			"ignore", "unique":
				pass
	else:
		_effects[tid].append(effect.duplicate())


func tick(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var tid: int = target.get_instance_id()
	if not _effects.has(tid):
		return
	var arr: Array = _effects[tid]
	var i: int = arr.size() - 1
	while i >= 0:
		var dur: int = int(arr[i].get("duration_turns", 1))
		if dur > 0:
			arr[i]["duration_turns"] = dur - 1
			if dur - 1 <= 0:
				arr.remove_at(i)
		i -= 1
	if arr.is_empty():
		_effects.erase(tid)


func remove(target: Node, effect_id: String) -> void:
	if not is_instance_valid(target):
		return
	var tid: int = target.get_instance_id()
	if not _effects.has(tid):
		return
	var arr: Array = _effects[tid]
	var i: int = arr.size() - 1
	while i >= 0:
		if str(arr[i].get("id", "")) == effect_id:
			arr.remove_at(i)
		i -= 1
	if arr.is_empty():
		_effects.erase(tid)


func clear_all(target: Node) -> void:
	if is_instance_valid(target):
		_effects.erase(target.get_instance_id())


func has_effect(target: Node, effect_id: String) -> bool:
	if not is_instance_valid(target):
		return false
	return _find(target.get_instance_id(), effect_id) >= 0


func get_effects(target: Node) -> Array:
	if not is_instance_valid(target):
		return []
	return _effects.get(target.get_instance_id(), [])


func get_effect(target: Node, effect_id: String) -> Dictionary:
	if not is_instance_valid(target):
		return {}
	var tid: int = target.get_instance_id()
	var idx: int = _find(tid, effect_id)
	return _effects[tid][idx] if idx >= 0 else {}


func _find(tid: int, effect_id: String) -> int:
	if not _effects.has(tid):
		return -1
	var arr: Array = _effects[tid]
	for i: int in range(arr.size()):
		if str(arr[i].get("id", "")) == effect_id:
			return i
	return -1
