extends Enemy

var is_guard: bool = true


func setup_guard(player_level: int) -> void:
	max_hp          = 12 + player_level * 6
	hp              = max_hp
	attack          = 4 + player_level * 2
	defense         = 3 + player_level
	dex             = 5 + player_level
	detection_range = 8
	faction         = "enemy"
	display_name    = "Guardia"
	_setup_visual("G", Color(0.4, 0.6, 1.0))


func die() -> void:
	if is_dead:
		return
	is_dead = true
	TurnManager.unregister_enemy(self)
	queue_free()
