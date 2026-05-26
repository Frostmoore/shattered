class_name HUDState
extends Node

const LOG_CAPACITY := 40

enum LogCategory { COMBAT, EXPLORATION, LOOT, QUEST, DIALOGUE, SYSTEM }

class LogEntry:
	var text:      String
	var category:  int
	var timestamp: float
	func _init(t: String, c: int) -> void:
		text      = t
		category  = c
		timestamp = Time.get_ticks_msec() / 1000.0

var entries: Array[LogEntry] = []


func push(text: String, category: int = LogCategory.SYSTEM) -> void:
	entries.push_back(LogEntry.new(text, category))
	if entries.size() > LOG_CAPACITY:
		entries.pop_front()


func get_latest() -> LogEntry:
	return entries.back() if not entries.is_empty() else null


static func get_color(category: int) -> Color:
	match category:
		LogCategory.COMBAT:      return Color(0.90, 0.25, 0.25)
		LogCategory.EXPLORATION: return Color(0.35, 0.75, 0.40)
		LogCategory.LOOT:        return Color(0.90, 0.75, 0.25)
		LogCategory.QUEST:       return Color(0.70, 0.45, 0.90)
		LogCategory.DIALOGUE:    return Color(0.55, 0.70, 0.95)
		_:                       return Color(0.55, 0.55, 0.55)
