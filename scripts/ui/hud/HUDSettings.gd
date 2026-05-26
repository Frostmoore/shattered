class_name HUDSettings
extends Node


func get_ui_mode() -> String:
	return SettingsManager.hud_ui_mode


func is_info_mode() -> bool:
	return SettingsManager.hud_ui_mode == "info"


func show_status() -> bool:
	return SettingsManager.hud_show_status


func show_quest() -> bool:
	return SettingsManager.hud_show_quest


func show_minimap() -> bool:
	return SettingsManager.hud_show_minimap


func show_worldinfo() -> bool:
	return SettingsManager.hud_show_worldinfo


func show_needs() -> bool:
	return SettingsManager.hud_show_needs


func get_minimap_pos() -> Vector2:
	return Vector2(SettingsManager.hud_minimap_pos_x, SettingsManager.hud_minimap_pos_y)


func set_ui_mode(mode: String) -> void:
	SettingsManager.hud_ui_mode = mode
	SettingsManager.save_settings()


func toggle_status() -> void:
	_toggle("hud_show_status")


func toggle_quest() -> void:
	_toggle("hud_show_quest")


func toggle_minimap() -> void:
	_toggle("hud_show_minimap")


func toggle_worldinfo() -> void:
	_toggle("hud_show_worldinfo")


func toggle_needs() -> void:
	_toggle("hud_show_needs")


func save_minimap_pos(pos: Vector2) -> void:
	SettingsManager.hud_minimap_pos_x = pos.x
	SettingsManager.hud_minimap_pos_y = pos.y
	SettingsManager.save_settings()


func _toggle(field: String) -> void:
	SettingsManager.set(field, not bool(SettingsManager.get(field)))
	SettingsManager.save_settings()
